module Tilia
  module CardDav
    # CardDAV plugin
    #
    # The CardDAV plugin adds CardDAV functionality to the WebDAV server
    class Plugin < Dav::ServerPlugin
      # Url to the addressbooks
      ADDRESSBOOK_ROOT = 'addressbooks'

      # xml namespace for CardDAV elements
      NS_CARDDAV = 'urn:ietf:params:xml:ns:carddav'

      # Add urls to this property to have them automatically exposed as
      # 'directories' to the user.
      #
      # @var array
      attr_accessor :directories

      protected

      # Server class
      #
      # @var Sabre\DAV\Server
      attr_accessor :server

      # The default PDO storage uses a MySQL MEDIUMBLOB for iCalendar data,
      # which can hold up to 2^24 = 16777216 bytes. This is plenty. We're
      # capping it to 10M here.
      attr_accessor :max_resource_size

      public

      # Initializes the plugin
      #
      # @param DAV\Server server
      # @return void
      def setup(server)
        # Events
        @server = server
        @server.on('propFind',            method(:prop_find_early))
        @server.on('propFind',            method(:prop_find_late), 150)
        @server.on('report',              method(:report))
        @server.on('onHTMLActionsPanel',  method(:html_actions_panel))
        @server.on('beforeWriteContent',  method(:before_write_content))
        @server.on('beforeCreateFile',    method(:before_create_file))
        @server.on('afterMethod:GET',     method(:http_after_get))

        @server.xml.namespace_map[NS_CARDDAV] = 'card'

        @server.xml.element_map["{#{NS_CARDDAV}}addressbook-query"] = Xml::Request::AddressBookQueryReport
        @server.xml.element_map["{#{NS_CARDDAV}}addressbook-multiget"] = Xml::Request::AddressBookMultiGetReport

        # Mapping Interfaces to {DAV:}resourcetype values
        @server.resource_type_mapping[IAddressBook] = "{#{NS_CARDDAV}}addressbook"
        @server.resource_type_mapping[IDirectory] = "{#{NS_CARDDAV}}directory"

        # Adding properties that may never be changed
        @server.protected_properties << "{#{NS_CARDDAV}}supported-address-data"
        @server.protected_properties << "{#{NS_CARDDAV}}max-resource-size"
        @server.protected_properties << "{#{NS_CARDDAV}}addressbook-home-set"
        @server.protected_properties << "{#{NS_CARDDAV}}supported-collation-set"

        @server.xml.element_map['{http://calendarserver.org/ns/}me-card'] = Dav::Xml::Property::Href
      end

      # Returns a list of supported features.
      #
      # This is used in the DAV: header in the OPTIONS and PROPFIND requests.
      #
      # @return array
      def features
        ['addressbook']
      end

      # Returns a list of reports this plugin supports.
      #
      # This will be used in the {DAV:}supported-report-set property.
      # Note that you still need to subscribe to the 'report' event to actually
      # implement them
      #
      # @param string uri
      # @return array
      def supported_report_set(uri)
        node = @server.tree.node_for_path(uri)
        if node.is_a?(IAddressBook) || node.is_a?(ICard)
          return [
            "{#{NS_CARDDAV}}addressbook-multiget",
            "{#{NS_CARDDAV}}addressbook-query"
          ]
        end
        []
      end

      # Adds all CardDAV-specific properties
      #
      # @param DAV\PropFind prop_find
      # @param DAV\INode node
      # @return void
      def prop_find_early(prop_find, node)
        ns = "{#{NS_CARDDAV}}"

        if node.is_a?(IAddressBook)
          prop_find.handle("#{ns}max-resource-size", @max_resource_size)
          prop_find.handle(
            "#{ns}supported-address-data",
            lambda do
              Xml::Property::SupportedAddressData.new
            end
          )
          prop_find.handle(
            "#{ns}supported-collation-set",
            lambda do
              Xml::Property::SupportedCollationSet.new
            end
          )
        end

        if node.is_a?(DavAcl::IPrincipal)
          path = prop_find.path

          prop_find.handle(
            "{#{NS_CARDDAV}}addressbook-home-set",
            lambda do
              Dav::Xml::Property::Href.new(addressbook_home_for_principal(path) + '/')
            end
          )

          if @directories.any?
            prop_find.handle(
              "{#{NS_CARDDAV}}directory-gateway",
              lambda do
                return Dav::Xml::Property::Href.new(@directories)
              end
            )
          end
        end

        if node.is_a?(ICard)
          # The address-data property is not supposed to be a 'real'
          # property, but in large chunks of the spec it does act as such.
          # Therefore we simply expose it as a property.
          prop_find.handle(
            "{#{NS_CARDDAV}}address-data",
            lambda do
              val = node.get
              val = val.read unless val.is_a?(String)

              return val
            end
          )
        end
      end

      # This functions handles REPORT requests specific to CardDAV
      #
      # @param string report_name
      # @param \DOMNode dom
      # @param mixed path
      # @return bool
      def report(report_name, dom, _path)
        case report_name
        when "{#{NS_CARDDAV}}addressbook-multiget"
          @server.transaction_type = 'report-addressbook-multiget'
          addressbook_multi_get_report(dom)
          return false
        when "{#{NS_CARDDAV}}addressbook-query"
          @server.transaction_type = 'report-addressbook-query'
          addressbook_query_report(dom)
          return false
        else
          return true
        end
      end

      protected

      # Returns the addressbook home for a given principal
      #
      # @param string principal
      # @return string
      def addressbook_home_for_principal(principal)
        principal_id = Http::UrlUtil.split_path(principal)[1]
        ADDRESSBOOK_ROOT + '/' + principal_id
      end

      public

      # This function handles the addressbook-multiget REPORT.
      #
      # This report is used by the client to fetch the content of a series
      # of urls. Effectively avoiding a lot of redundant requests.
      #
      # @param Xml\Request\AddressBookMultiGetReport report
      # @return void
      def addressbook_multi_get_report(report)
        content_type = report.content_type || ''
        version = report.version

        content_type << "; version=#{version}" if version

        vcard_type = negotiate_v_card(content_type)

        property_list = []
        paths = report.hrefs.map do |href|
          @server.calculate_uri(href)
        end

        @server.properties_for_multiple_paths(paths, report.properties).each do |_path, props|
          if props[200].key?("{#{NS_CARDDAV}}address-data")
            props[200]["{#{NS_CARDDAV}}address-data"] = convert_v_card(
              props[200]["{#{NS_CARDDAV}}address-data"],
              vcard_type
            )
          end

          property_list << props
        end

        prefer = @server.http_prefer

        @server.http_response.status = 207
        @server.http_response.update_header('Content-Type', 'application/xml; charset=utf-8')
        @server.http_response.update_header('Vary', 'Brief,Prefer')
        @server.http_response.body = @server.generate_multi_status(property_list, prefer['return'] == 'minimal')
      end

      # This method is triggered before a file gets updated with new content.
      #
      # This plugin uses this method to ensure that Card nodes receive valid
      # vcard data.
      #
      # @param string path
      # @param DAV\IFile node
      # @param [Box<String, IO>] data
      # @param [Box<Boolean> modified Should be set to true, if this event handler
      #                       changed &data.
      # @return void
      def before_write_content(_path, node, data, modified)
        return true unless node.is_a?(ICard)

        validate_v_card(data, modified)
        true # Do not break chain
      end

      # This method is triggered before a new file is created.
      #
      # This plugin uses this method to ensure that Card nodes receive valid
      # vcard data.
      #
      # @param string path
      # @param [Box<String, IO> data
      # @param DAV\ICollection parent_node
      # @param Box<Boolean> modified Should be set to true, if this event handler
      #                       changed &data.
      # @return void
      def before_create_file(_path, data, parent_node, modified)
        return true unless parent_node.is_a?(IAddressBook)

        validate_v_card(data, modified)
        true
      end

      protected

      # Checks if the submitted iCalendar data is in fact, valid.
      #
      # An exception is thrown if it's not.
      #
      # @param [Box<String, IO>] data
      # @param [Box<Boolean>] modified Should be set to true, if this event handler
      #                       changed &data.
      # @return void
      def validate_v_card(data_box, modified_box)
        # If it's a stream, we convert it to a string first.
        data = data_box.value

        data = data.read unless data.is_a?(String)

        before = Digest::MD5.hexdigest(data)

        # Converting the data to unicode, if needed.
        data = Dav::StringUtil.ensure_utf8(data)

        modified_box.value = true unless Digest::MD5.hexdigest(data) == before

        begin
          # If the data starts with a [, we can reasonably assume we're dealing
          # with a jCal object.
          if data[0] == '['
            vobj = VObject::Reader.read_json(data)
            # Converting data back to iCalendar, as that's what we
            # technically support everywhere.
            data = vobj.serialize
            modified_box.value = true
          else
            vobj = VObject::Reader.read(data)
          end
        rescue VObject::ParseException => e
          raise Dav::Exception::UnsupportedMediaType, "This resource only supports valid vCard or jCard data. Parse error: #{e}"
        end

        fail Dav::Exception::UnsupportedMediaType, 'This collection can only support vcard objects.' unless vobj.name == 'VCARD'

        unless vobj.key?('UID')
          # No UID in vcards is invalid, but we'll just add it in anyway.
          vobj.add('UID', Dav::UuidUtil.uuid)
          data = vobj.serialize
          modified_box.value = true
        end

        data_box.value = data

        # Destroy circular references to PHP will GC the object.
        vobj.destroy
      end

      # This function handles the addressbook-query REPORT
      #
      # This report is used by the client to filter an addressbook based on a
      # complex query.
      #
      # @param Xml\Request\AddressBookQueryReport report
      # @return void
      def addressbook_query_report(report)
        depth = @server.http_depth(0)

        if depth == 0
          candidate_nodes = [@server.tree.node_for_path(@server.request_uri)]

          fail Dav::Exception::ReportNotSupported, 'The addressbook-query report is not supported on this url with Depth: 0' unless candidate_nodes[0].is_a?(ICard)
        else
          candidate_nodes = @server.tree.children(@server.request_uri)
        end

        content_type = report.content_type
        content_type << "; version=#{report.version}" if report.version

        vcard_type = negotiate_v_card(content_type)

        valid_nodes = []
        candidate_nodes.each do |node|
          next unless node.is_a?(ICard)

          blob = node.get
          blob = blob.read unless blob.is_a?(String)

          next unless validate_filters(blob, report.filters, report.test)

          valid_nodes << node

          if report.limit && report.limit <= valid_nodes.size
            # We hit the maximum number of items, we can stop now.
            break
          end
        end

        result = []
        valid_nodes.each do |valid_node|
          if depth == 0
            href = @server.request_uri
          else
            href = "#{@server.request_uri}/#{valid_node.name}"
          end

          props = @server.properties_for_path(href, report.properties, 0).first

          if props[200].key?("{#{NS_CARDDAV}}address-data")
            props[200]["{#{NS_CARDDAV}}address-data"] = convert_v_card(
              props[200]["{#{NS_CARDDAV}}address-data"],
              vcard_type
            )
          end

          result << props
        end

        prefer = @server.http_prefer

        @server.http_response.status = 207
        @server.http_response.update_header('Content-Type', 'application/xml; charset=utf-8')
        @server.http_response.update_header('Vary', 'Brief,Prefer')
        @server.http_response.body = @server.generate_multi_status(result, prefer['return'] == 'minimal')
      end

      public

      # Validates if a vcard makes it throught a list of filters.
      #
      # @param string vcard_data
      # @param array filters
      # @param string test anyof or allof (which means OR or AND)
      # @return bool
      def validate_filters(vcard_data, filters, test)
        return true if filters.empty?

        vcard = VObject::Reader.read(vcard_data)

        filters.each do |filter|
          is_defined = vcard.key?(filter['name'])

          if filter['is-not-defined']
            if is_defined
              success = false
            else
              success = true
            end
          elsif (filter['param-filters'].empty? && filter['text-matches'].empty?) || !is_defined
            # We only need to check for existence
            success = is_defined
          else
            v_properties = vcard.select(filter['name'])

            results = []
            results << validate_param_filters(v_properties, filter['param-filters'], filter['test']) if filter['param-filters']

            if filter['text-matches']
              texts = []
              v_properties.each do |v_property|
                texts << v_property.value
              end

              results << validate_text_matches(texts, filter['text-matches'], filter['test'])
            end

            if results.size == 1
              success = results[0]
            else
              if filter['test'] == 'anyof'
                success = results[0] || results[1]
              else
                success = results[0] && results[1]
              end
            end
          end

          # There are two conditions where we can already determine whether
          # or not this filter succeeds.
          if test == 'anyof' && success
            # Destroy circular references to PHP will GC the object.
            vcard.destroy

            return true
          end

          next unless test == 'allof' && !success
          vcard.destroy

          return false
        end

        # Destroy circular references to PHP will GC the object.
        vcard.destroy

        # If we got all the way here, it means we haven't been able to
        # determine early if the test failed or not.
        #
        # This implies for 'anyof' that the test failed, and for 'allof' that
        # we succeeded. Sounds weird, but makes sense.
        test == 'allof'
      end

      protected

      # Validates if a param-filter can be applied to a specific property.
      #
      # @todo currently we're only validating the first parameter of the passed
      #       property. Any subsequence parameters with the same name are
      #       ignored.
      # @param array v_properties
      # @param array filters
      # @param string test
      # @return bool
      def validate_param_filters(v_properties, filters, test)
        filters.each do |filter|
          is_defined = false
          v_properties.each do |v_property|
            is_defined = v_property.key?(filter['name'])
            break if is_defined
          end

          if filter['is-not-defined']
            if is_defined
              success = false
            else
              success = true
            end
          # If there's no text-match, we can just check for existence
          elsif !filter['text-match'] || !is_defined
            success = is_defined
          else
            success = false
            v_properties.each do |v_property|
              # If we got all the way here, we'll need to validate the
              # text-match filter.
              success = Dav::StringUtil.text_match(v_property[filter['name']].value, filter['text-match']['value'], filter['text-match']['collation'], filter['text-match']['match-type'])
              break if success
            end

            success = !success if filter['text-match']['negate-condition']
          end

          # There are two conditions where we can already determine whether
          # or not this filter succeeds.
          return true if test == 'anyof' && success
          return false if test == 'allof' && !success
        end

        # If we got all the way here, it means we haven't been able to
        # determine early if the test failed or not.
        #
        # This implies for 'anyof' that the test failed, and for 'allof' that
        # we succeeded. Sounds weird, but makes sense.
        test == 'allof'
      end

      # Validates if a text-filter can be applied to a specific property.
      #
      # @param array texts
      # @param array filters
      # @param string test
      # @return bool
      def validate_text_matches(texts, filters, test)
        filters.each do |filter|
          success = false
          texts.each do |haystack|
            success = Dav::StringUtil.text_match(haystack, filter['value'], filter['collation'], filter['match-type'])

            # Breaking on the first match
            break if success
          end
          success = !success if filter['negate-condition']

          return true if success && test == 'anyof'

          return false if !success && test == 'allof'
        end

        # If we got all the way here, it means we haven't been able to
        # determine early if the test failed or not.
        #
        # This implies for 'anyof' that the test failed, and for 'allof' that
        # we succeeded. Sounds weird, but makes sense.
        test == 'allof'
      end

      public

      # This event is triggered when fetching properties.
      #
      # This event is scheduled late in the process, after most work for
      # propfind has been done.
      #
      # @param DAV\PropFind prop_find
      # @param DAV\INode node
      # @return void
      def prop_find_late(prop_find, _node)
        # If the request was made using the SOGO connector, we must rewrite
        # the content-type property. By default SabreDAV will send back
        # text/x-vcard; charset=utf-8, but for SOGO we must strip that last
        # part.
        return unless (@server.http_request.header('User-Agent') || '').index('Thunderbird')

        content_type = prop_find.get('{DAV:}getcontenttype')
        part = content_type.split(';').first
        if part == 'text/x-vcard' || part == 'text/vcard'
          prop_find.set('{DAV:}getcontenttype', 'text/x-vcard')
        end
      end

      # This method is used to generate HTML output for the
      # Sabre\DAV\Browser\Plugin. This allows us to generate an interface users
      # can use to create new addressbooks.
      #
      # @param DAV\INode node
      # @param [Box] output
      # @return bool
      def html_actions_panel(node, output)
        return false unless node.is_a?(AddressBookHome)

        output.value << <<HTML
<tr><td colspan="2"><form method="post" action="">
<h3>Create new address book</h3>
<input type="hidden" name="sabreAction" value="mkcol" />
<input type="hidden" name="resourceType" value="{DAV:}collection,{#{NS_CARDDAV}}addressbook" />
<label>Name (uri):</label> <input type="text" name="name" /><br />
<label>Display name:</label> <input type="text" name="{DAV:}displayname" /><br />
<input type="submit" value="create" />
</form>
</td></tr>
HTML

        false
      end

      # This event is triggered after GET requests.
      #
      # This is used to transform data into jCal, if this was requested.
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return void
      def http_after_get(request, response)
        return unless (response.header('Content-Type') || '').index('text/vcard')

        mime_type = Box.new('')
        target = negotiate_v_card(request.header('Accept'), mime_type)
        mime_type = mime_type.value

        new_body = convert_v_card(
          response.body,
          target
        )

        response.body = new_body
        response.update_header('Content-Type', "#{mime_type}; charset=utf-8")
        response.update_header('Content-Length', new_body.bytesize)
      end

      protected

      # This helper function performs the content-type negotiation for vcards.
      #
      # It will return one of the following strings:
      # 1. vcard3
      # 2. vcard4
      # 3. jcard
      #
      # It defaults to vcard3.
      #
      # @param string input
      # @param string mime_type
      # @return string
      def negotiate_v_card(input, mime_type = Box.new(''))
        result = Http::Util.negotiate(
          input,
          [
            # Most often used mime-type. Version 3
            'text/x-vcard',
            # The correct standard mime-type. Defaults to version 3 as
            # well.
            'text/vcard',
            # vCard 4
            'text/vcard; version=4.0',
            # vCard 3
            'text/vcard; version=3.0',
            # jCard
            'application/vcard+json'
          ]
        )

        mime_type.value = result
        case result
        when 'text/vcard; version=4.0'
          return 'vcard4'
        when 'application/vcard+json'
          return 'jcard'
        else
          mime_type.value = 'text/vcard'
          return 'vcard3'
        end
      end

      # Converts a vcard blob to a different version, or jcard.
      #
      # @param string data
      # @param string target
      # @return string
      def convert_v_card(data, target)
        data = VObject::Reader.read(data)
        case target
        when 'vcard4'
          data = data.convert(VObject::Document::VCARD40)
          new_result = data.serialize
        when 'jcard'
          data = data.convert(VObject::Document::VCARD40)
          new_result = data.json_serialize.to_json
        else
          data = data.convert(VObject::Document::VCARD30)
          new_result = data.serialize
        end

        # Destroy circular references to PHP will GC the object.
        data.destroy

        new_result
      end

      public

      # Returns a plugin name.
      #
      # Using this name other plugins will be able to access other plugins
      # using DAV\Server::getPlugin
      #
      # @return string
      def plugin_name
        'carddav'
      end

      # Returns a bunch of meta-data about the plugin.
      #
      # Providing this information is optional, and is mainly displayed by the
      # Browser plugin.
      #
      # The description key in the returned array may contain html and will not
      # be sanitized.
      #
      # @return array
      def plugin_info
        {
          'name'        => plugin_name,
          'description' => 'Adds support for CardDAV (rfc6352)',
          'link'        => 'http://sabre.io/dav/carddav/'
        }
      end

      # TODO: document
      def initialize
        @directories = []
        @max_resource_size = 10_000_000
      end
    end
  end
end
