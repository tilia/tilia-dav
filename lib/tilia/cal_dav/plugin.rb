module Tilia
  module CalDav
    # CalDAV plugin
    #
    # This plugin provides functionality added by CalDAV (RFC 4791)
    # It implements new reports, and the MKCALENDAR method.
    class Plugin < Dav::ServerPlugin
      # This is the official CalDAV namespace
      NS_CALDAV = 'urn:ietf:params:xml:ns:caldav'

      # This is the namespace for the proprietary calendarserver extensions
      NS_CALENDARSERVER = 'http://calendarserver.org/ns/'

      # The hardcoded root for calendar objects. It is unfortunate
      # that we're stuck with it, but it will have to do for now
      CALENDAR_ROOT = 'calendars'

      # @!attribute [r] server
      #   @!visibility private
      #   Reference to server object
      #
      #   @var DAV\Server

      # @!attribute [r] max_resource_size
      #   @!visibility private
      #   The default PDO storage uses a MySQL MEDIUMBLOB for iCalendar data,
      #   which can hold up to 2^24 = 16777216 bytes. This is plenty. We're
      #   capping it to 10M here.

      # Use this method to tell the server this plugin defines additional
      # HTTP methods.
      #
      # This method is passed a uri. It should only return HTTP methods that are
      # available for the specified uri.
      #
      # @param string uri
      # @return array
      def http_methods(uri)
        # The MKCALENDAR is only available on unmapped uri's, whose
        # parents extend IExtendedCollection
        (parent, name) = Uri.split(uri)

        node = @server.tree.node_for_path(parent)

        if node.is_a?(Dav::IExtendedCollection)
          begin
            node.child(name)
          rescue Dav::Exception::NotFound
            return ['MKCALENDAR']
          end
        end

        []
      end

      # Returns the path to a principal's calendar home.
      #
      # The return url must not end with a slash.
      # This function should return null in case a principal did not have
      # a calendar home.
      #
      # @param string principal_url
      # @return [String, nil]
      def calendar_home_for_principal(principal_url)
        # The default behavior for most sabre/dav servers is that there is a
        # principals root node, which contains users directly under it.
        #
        # This function assumes that there are two components in a principal
        # path. If there's more, we don't return a calendar home. This
        # excludes things like the calendar-proxy-read principal (which it
        # should).
        parts = principal_url.gsub(%r{^/+|/+$}, '').split('/')

        return nil unless parts.size == 2
        return nil unless parts[0] == 'principals'

        return CALENDAR_ROOT + '/' + parts[1]
      end

      # Returns a list of features for the DAV: HTTP header.
      #
      # @return array
      def features
        ['calendar-access', 'calendar-proxy']
      end

      # Returns a plugin name.
      #
      # Using this name other plugins will be able to access other plugins
      # using DAV\Server::getPlugin
      #
      # @return string
      def plugin_name
        'caldav'
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

        reports = []
        if node.is_a?(ICalendarObjectContainer) || node.is_a?(ICalendarObject)
          reports << "{#{NS_CALDAV}}calendar-multiget"
          reports << "{#{NS_CALDAV}}calendar-query"
        end

        reports << "{#{NS_CALDAV}}free-busy-query" if node.is_a?(ICalendar)

        # iCal has a bug where it assumes that sync support is enabled, only
        # if we say we support it on the calendar-home, even though this is
        # not actually the case.
        if node.is_a?(CalendarHome) && @server.plugin('sync')
          reports << '{DAV:}sync-collection'
        end

        reports
      end

      # Initializes the plugin
      #
      # @param DAV\Server server
      # @return void
      def setup(server)
        @server = server

        @server.on('method:MKCALENDAR',   method(:http_mk_calendar))
        @server.on('report',              method(:report))
        @server.on('propFind',            method(:prop_find))
        @server.on('onHTMLActionsPanel',  method(:html_actions_panel))
        @server.on('beforeCreateFile',    method(:before_create_file))
        @server.on('beforeWriteContent',  method(:before_write_content))
        @server.on('afterMethod:GET',     method(:http_after_get))

        @server.xml.namespace_map[NS_CALDAV] = 'cal'
        @server.xml.namespace_map[NS_CALENDARSERVER] = 'cs'

        @server.xml.element_map["{#{NS_CALDAV}}supported-calendar-component-set"] = Xml::Property::SupportedCalendarComponentSet
        @server.xml.element_map["{#{NS_CALDAV}}calendar-query"] = Xml::Request::CalendarQueryReport
        @server.xml.element_map["{#{NS_CALDAV}}calendar-multiget"] = Xml::Request::CalendarMultiGetReport
        @server.xml.element_map["{#{NS_CALDAV}}free-busy-query"] = Xml::Request::FreeBusyQueryReport
        @server.xml.element_map["{#{NS_CALDAV}}mkcalendar"] = Xml::Request::MkCalendar
        @server.xml.element_map["{#{NS_CALDAV}}schedule-calendar-transp"] = Xml::Property::ScheduleCalendarTransp
        @server.xml.element_map["{#{NS_CALDAV}}supported-calendar-component-set"] = Xml::Property::SupportedCalendarComponentSet

        @server.resource_type_mapping[ICalendar] = '{urn:ietf:params:xml:ns:caldav}calendar'

        @server.resource_type_mapping[Principal::IProxyRead] = '{http://calendarserver.org/ns/}calendar-proxy-read'
        @server.resource_type_mapping[Principal::IProxyWrite] = '{http://calendarserver.org/ns/}calendar-proxy-write'

        @server.protected_properties += [
          "{#{NS_CALDAV}}supported-calendar-component-set",
          "{#{NS_CALDAV}}supported-calendar-data",
          "{#{NS_CALDAV}}max-resource-size",
          "{#{NS_CALDAV}}min-date-time",
          "{#{NS_CALDAV}}max-date-time",
          "{#{NS_CALDAV}}max-instances",
          "{#{NS_CALDAV}}max-attendees-per-instance",
          "{#{NS_CALDAV}}calendar-home-set",
          "{#{NS_CALDAV}}supported-collation-set",
          "{#{NS_CALDAV}}calendar-data",

          # CalendarServer extensions
          "{#{NS_CALENDARSERVER}}getctag",
          "{#{NS_CALENDARSERVER}}calendar-proxy-read-for",
          "{#{NS_CALENDARSERVER}}calendar-proxy-write-for"
        ]

        acl_plugin = @server.plugin('acl')
        if acl_plugin
          acl_plugin.principal_search_property_set["{#{NS_CALDAV}}calendar-user-address-set"] = 'Calendar address'
        end
      end

      # This functions handles REPORT requests specific to CalDAV
      #
      # @param string report_name
      # @param mixed report
      # @param mixed _path
      # @return bool
      def report(report_name, report, _path)
        case report_name
        when "{#{NS_CALDAV}}calendar-multiget"
          @server.transaction_type = 'report-calendar-multiget'
          calendar_multi_get_report(report)
          return false
        when "{#{NS_CALDAV}}calendar-query"
          @server.transaction_type = 'report-calendar-query'
          calendar_query_report(report)
          return false
        when "{#{NS_CALDAV}}free-busy-query"
          @server.transaction_type = 'report-free-busy-query'
          free_busy_query_report(report)
          return false
        end
      end

      # This function handles the MKCALENDAR HTTP method, which creates
      # a new calendar.
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_mk_calendar(request, _response)
        body = request.body_as_string
        path = request.path

        properties = {}

        unless body.blank?
          begin
            mkcalendar = @server.xml.expect(
              '{urn:ietf:params:xml:ns:caldav}mkcalendar',
              body
            )
          rescue Tilia::Xml::ParseException => e
            raise Dav::Exception::BadRequest, e.message
          end

          properties = mkcalendar.properties
        end

        # iCal abuses MKCALENDAR since iCal 10.9.2 to create server-stored
        # subscriptions. Before that it used MKCOL which was the correct way
        # to do this.
        #
        # If the body had a {DAV:}resourcetype, it means we stumbled upon this
        # request, and we simply use it instead of the pre-defined list.
        if properties.key?('{DAV:}resourcetype')
          resource_type = properties['{DAV:}resourcetype'].value
        else
          resource_type = ['{DAV:}collection', '{urn:ietf:params:xml:ns:caldav}calendar']
        end

        @server.create_collection(path, Dav::MkCol.new(resource_type, properties))

        @server.http_response.status = 201
        @server.http_response.update_header('Content-Length', 0)

        # This breaks the method chain.
        false
      end

      # PropFind
      #
      # This method handler is invoked before any after properties for a
      # resource are fetched. This allows us to add in any CalDAV specific
      # properties.
      #
      # @param DAV\PropFind prop_find
      # @param DAV\INode node
      # @return void
      def prop_find(prop_find, node)
        ns = "{#{NS_CALDAV}}"

        if node.is_a?(ICalendarObjectContainer)
          prop_find.handle(ns + 'max-resource-size', @max_resource_size)
          prop_find.handle(
            ns + 'supported-calendar-data',
            -> { Xml::Property::SupportedCalendarData.new }
          )
          prop_find.handle(
            ns + 'supported-collation-set',
            -> { Xml::Property::SupportedCollationSet.new }
          )
        end

        if node.is_a?(DavAcl::IPrincipal)
          principal_url = node.principal_url

          prop_find.handle(
            "{#{NS_CALDAV}}calendar-home-set",
            lambda do
              calendar_home_path = calendar_home_for_principal(principal_url)
              return nil unless calendar_home_path
              return Dav::Xml::Property::Href.new(calendar_home_path + '/')
            end
          )

          # The calendar-user-address-set property is basically mapped to
          # the {DAV:}alternate-URI-set property.
          prop_find.handle(
            "{#{NS_CALDAV}}calendar-user-address-set",
            lambda do
              addresses = node.alternate_uri_set
              addresses << @server.base_uri + node.principal_url + '/'
              return Dav::Xml::Property::Href.new(addresses, false)
            end
          )
          # For some reason somebody thought it was a good idea to add
          # another one of these properties. We're supporting it too.
          prop_find.handle(
            "{#{NS_CALENDARSERVER}}email-address-set",
            lambda do
              addresses = node.alternate_uri_set
              emails = []
              addresses.each do |address|
                emails << address[7..-1] if address[0, 7] == 'mailto:'
              end

              return Xml::Property::EmailAddressSet.new(emails)
            end
          )

          # These two properties are shortcuts for ical to easily find
          # other principals this principal has access to.
          prop_read = "{#{NS_CALENDARSERVER}}calendar-proxy-read-for"
          prop_write = "{#{NS_CALENDARSERVER}}calendar-proxy-write-for"

          if prop_find.status(prop_read) == 404 || prop_find.status(prop_write) == 404
            acl_plugin = @server.plugin('acl')
            membership = acl_plugin.principal_membership(prop_find.path)

            read_list = []
            write_list = []
            membership.each do |group|
              group_node = @server.tree.node_for_path(group)

              list_item = Uri.split(group)[0] + '/'

              # If the node is either ap proxy-read or proxy-write
              # group, we grab the parent principal and add it to the
              # list.
              read_list << list_item if group_node.is_a?(Principal::IProxyRead)
              if group_node.is_a?(Principal::IProxyWrite)
                write_list << list_item
              end
            end

            prop_find.set(prop_read, Dav::Xml::Property::Href.new(read_list))
            prop_find.set(prop_write, Dav::Xml::Property::Href.new(write_list))
          end
        end # instanceof IPrincipal

        if node.is_a?(ICalendarObject)
          # The calendar-data property is not supposed to be a 'real'
          # property, but in large chunks of the spec it does act as such.
          # Therefore we simply expose it as a property.
          prop_find.handle(
            "{#{NS_CALDAV}}calendar-data",
            lambda do
              val = node.get
              val = val.read unless val.is_a?(String)

              # Taking out \r to not screw up the xml output
              return val.delete("\r")
            end
          )
        end
      end

      # This function handles the calendar-multiget REPORT.
      #
      # This report is used by the client to fetch the content of a series
      # of urls. Effectively avoiding a lot of redundant requests.
      #
      # @param CalendarMultiGetReport report
      # @return void
      def calendar_multi_get_report(report)
        needs_json = report.content_type == 'application/calendar+json'

        time_zones = {}
        property_list = []

        paths = report.hrefs.map { |h| @server.calculate_uri(h) }

        @server.properties_for_multiple_paths(paths, report.properties).each do |uri, obj_props|
          if (needs_json || report.expand) && obj_props[200].key?("{#{NS_CALDAV}}calendar-data")
            v_object = VObject::Reader.read(obj_props[200]["{#{NS_CALDAV}}calendar-data"])

            if report.expand
              # We're expanding, and for that we need to figure out the
              # calendar's timezone.
              calendar_path = Uri.split(uri).first

              unless time_zones.key?(calendar_path)
                # Checking the calendar-timezone property.
                tz_prop = "{#{NS_CALDAV}}calendar-timezone"
                tz_result = @server.properties(calendar_path, [tz_prop])

                if tz_result.key?(tz_prop)
                  # This property contains a VCALENDAR with a single
                  # VTIMEZONE.
                  vtimezone_obj = VObject::Reader.read(tz_result[tz_prop])
                  time_zone = vtimezone_obj['VTIMEZONE'].time_zone
                else
                  # Defaulting to UTC.
                  time_zone = ActiveSupport::TimeZone.new('UTC')
                end

                time_zones[calendar_path] = time_zone
              end

              v_object = v_object.expand(report.expand['start'], report.expand['end'], time_zones[calendar_path])
            end

            if needs_json
              obj_props[200]["{#{NS_CALDAV}}calendar-data"] = v_object.json_serialize.to_json
            else
              obj_props[200]["{#{NS_CALDAV}}calendar-data"] = v_object.serialize
            end

            # Destroy circular references so PHP will garbage collect the
            # object.
            v_object.destroy
          end

          property_list << obj_props
        end

        prefer = @server.http_prefer

        @server.http_response.status = 207
        @server.http_response.update_header('Content-Type', 'application/xml; charset=utf-8')
        @server.http_response.update_header('Vary', 'Brief,Prefer')
        @server.http_response.body = @server.generate_multi_status(property_list, prefer['return'] == 'minimal')
      end

      # This function handles the calendar-query REPORT
      #
      # This report is used by clients to request calendar objects based on
      # complex conditions.
      #
      # @param Xml\Request\CalendarQueryReport report
      # @return void
      def calendar_query_report(report)
        path = @server.request_uri

        needs_json = report.content_type == 'application/calendar+json'

        node = @server.tree.node_for_path(@server.request_uri)
        depth = @server.http_depth(0)

        # The default result is an empty array
        result = []

        calendar_time_zone = nil
        if report.expand
          # We're expanding, and for that we need to figure out the
          # calendar's timezone.
          tz_prop = "{#{NS_CALDAV}}calendar-timezone"
          tz_result = @server.properties(path, [tz_prop])

          if tz_result.key?(tz_prop)
            # This property contains a VCALENDAR with a single
            # VTIMEZONE.
            vtimezone_obj = VObject::Reader.read(tz_result[tz_prop])
            calendar_time_zone = vtimezone_obj['VTIMEZONE'].time_zone

            # Destroy circular references so PHP will garbage collect the
            # object.
            vtimezone_obj.destroy
          else
            # Defaulting to UTC.
            calendar_time_zone = ActiveSupport::TimeZone.new('UTC')
          end
        end

        # The calendarobject was requested directly. In this case we handle
        # this locally.
        if depth == 0 && node.is_a?(ICalendarObject)
          requested_calendar_data = true
          requested_properties = report.properties

          unless requested_properties.include?('{urn:ietf:params:xml:ns:caldav}calendar-data')
            # We always retrieve calendar-data, as we need it for filtering.
            requested_properties << '{urn:ietf:params:xml:ns:caldav}calendar-data'

            # If calendar-data wasn't explicitly requested, we need to remove
            # it after processing.
            requested_calendar_data = false
          end

          properties = @server.properties_for_path(
            path,
            requested_properties,
            0
          )

          # This array should have only 1 element, the first calendar
          # object.
          properties = properties.first

          # If there wasn't any calendar-data returned somehow, we ignore
          # this.
          if properties[200].key?('{urn:ietf:params:xml:ns:caldav}calendar-data')
            validator = CalendarQueryValidator.new

            v_object = VObject::Reader.read(properties[200]['{urn:ietf:params:xml:ns:caldav}calendar-data'])
            if validator.validate(v_object, report.filters)
              # If the client didn't require the calendar-data property,
              # we won't give it back.
              if !requested_calendar_data
                properties[200].delete('{urn:ietf:params:xml:ns:caldav}calendar-data')
              else
                v_object = v_object.expand(report.expand['start'], report.expand['end'], calendar_time_zone) if report.expand

                if needs_json
                  properties[200]["{#{NS_CALDAV}}calendar-data"] = v_object.json_serialize.to_json
                elsif report.expand
                  properties[200]["{#{NS_CALDAV}}calendar-data"] = v_object.serialize
                end
              end

              result = [properties]
            end

            # Destroy circular references so PHP will garbage collect the
            # object.
            v_object.destroy
          end
        end

        if node.is_a?(ICalendarObjectContainer) && depth == 0
          if @server.http_request.header('User-Agent').to_s.index('MSFT-') == 0
            # Microsoft clients incorrectly supplied depth as 0, when it actually
            # should have set depth to 1. We're implementing a workaround here
            # to deal with this.
            #
            # This targets at least the following clients:
            #   Windows 10
            #   Windows Phone 8, 10
            depth = 1
          else
            fail Dav::Exception::BadRequest, 'A calendar-query REPORT on a calendar with a Depth: 0 is undefined. Set Depth to 1'
          end
        end

        # If we're dealing with a calendar, the calendar itself is responsible
        # for the calendar-query.
        if node.is_a?(ICalendarObjectContainer) && depth == 1
          node_paths = node.calendar_query(report.filters)

          node_paths.each do |path|
            properties = @server.properties_for_path(@server.request_uri + '/' + path, report.properties).first

            if needs_json || report.expand
              v_object = VObject::Reader.read(properties[200]["{#{NS_CALDAV}}calendar-data"])

              v_object = v_object.expand(report.expand['start'], report.expand['end'], calendar_time_zone) if report.expand

              if needs_json
                properties[200]["{#{NS_CALDAV}}calendar-data"] = v_object.json_serialize.to_json
              else
                properties[200]["{#{NS_CALDAV}}calendar-data"] = v_object.serialize
              end

              # Destroy circular references so PHP will garbage collect the
              # object.
              v_object.destroy
            end

            result << properties
          end
        end

        prefer = @server.http_prefer

        @server.http_response.status = 207
        @server.http_response.update_header('Content-Type', 'application/xml; charset=utf-8')
        @server.http_response.update_header('Vary', 'Brief,Prefer')
        @server.http_response.body = @server.generate_multi_status(result, prefer['return'] == 'minimal')
      end

      protected

      # This method is responsible for parsing the request and generating the
      # response for the CALDAV:free-busy-query REPORT.
      #
      # @param Xml\Request\FreeBusyQueryReport report
      # @return void
      def free_busy_query_report(report)
        uri = @server.request_uri

        acl = @server.plugin('acl')
        acl.check_privileges(uri, "{#{NS_CALDAV}}read-free-busy") if acl

        calendar = @server.tree.node_for_path(uri)
        fail Dav::Exception::NotImplemented, 'The free-busy-query REPORT is only implemented on calendars' unless calendar.is_a?(ICalendar)

        tz_prop = "{#{NS_CALDAV}}calendar-timezone"

        # Figuring out the default timezone for the calendar, for floating
        # times.
        calendar_props = @server.properties(uri, [tz_prop])

        if calendar_props.key?(tz_prop)
          vtimezone_obj = VObject::Reader.read(calendar_props[tz_prop])
          calendar_time_zone = vtimezone_obj['VTIMEZONE'].time_zone
          # Destroy circular references so PHP will garbage collect the object.
          vtimezone_obj.destroy
        else
          calendar_time_zone = ActiveSupport::TimeZone.new('UTC')
        end

        # Doing a calendar-query first, to make sure we get the most
        # performance.
        urls = calendar.calendar_query(
          'name'         => 'VCALENDAR',
          'comp-filters' => [
            {
              'name'           => 'VEVENT',
              'comp-filters'   => [],
              'prop-filters'   => [],
              'is-not-defined' => false,
              'time-range'     => {
                'start' => report.start,
                'end'   => report.end
              }
            }
          ],
          'prop-filters'   => [],
          'is-not-defined' => false,
          'time-range'     => nil
        )

        objects = urls.map { |url| calendar.child(url).get }

        generator = VObject::FreeBusyGenerator.new
        generator.objects = objects
        generator.time_range = report.start..report.end
        generator.time_zone = calendar_time_zone

        result = generator.result
        result = result.serialize

        @server.http_response.status = 200
        @server.http_response.update_header('Content-Type', 'text/calendar')
        @server.http_response.update_header('Content-Length', result.bytesize)
        @server.http_response.body = result
      end

      public

      # This method is triggered before a file gets updated with new content.
      #
      # This plugin uses this method to ensure that CalDAV objects receive
      # valid calendar data.
      #
      # @param string path
      # @param DAV\IFile node
      # @param [Box] data
      # @param [Box<bool>] modified Should be set to true, if this event handler
      #                       changed &data.
      # @return void
      def before_write_content(path, node, data, modified)
        return true unless node.is_a?(ICalendarObject)

        # We're onyl interested in ICalendarObject nodes that are inside of a
        # real calendar. This is to avoid triggering validation and scheduling
        # for non-calendars (such as an inbox).
        parent = Uri.split(path).first
        parent_node = @server.tree.node_for_path(parent)

        return true unless parent_node.is_a?(ICalendar)

        validate_i_calendar(
          data,
          path,
          modified,
          @server.http_request,
          @server.http_response,
          false
        )
        true
      end

      # This method is triggered before a new file is created.
      #
      # This plugin uses this method to ensure that newly created calendar
      # objects contain valid calendar data.
      #
      # @param string path
      # @param [Box] data
      # @param DAV\ICollection parent_node
      # @param [Box<bool>] modified Should be set to true, if this event handler
      #                       changed &data.
      # @return void
      def before_create_file(path, data, parent_node, modified)
        return true unless parent_node.is_a?(ICalendar)

        validate_i_calendar(
          data,
          path,
          modified,
          @server.http_request,
          @server.http_response,
          true
        )
        true
      end

      protected

      # Checks if the submitted iCalendar data is in fact, valid.
      #
      # An exception is thrown if it's not.
      #
      # @param [Box] data
      # @param string path
      # @param [Box<bool>] modified Should be set to true, if this event handler
      #                       changed &data.
      # @param RequestInterface request The http request.
      # @param ResponseInterface response The http response.
      # @param bool is_new Is the item a new one, or an update.
      # @return void
      def validate_i_calendar(data_box, path, modified_box, request, response, is_new)
        data = data_box.value
        modified = modified_box.value

        # If it's a stream, we convert it to a string first.
        data = data.read unless data.is_a?(String)

        before = Digest::MD5.hexdigest(data)

        # Converting the data to unicode, if needed.
        data = Dav::StringUtil.ensure_utf8(data)

        modified = true unless before == Digest::MD5.hexdigest(data)

        begin
          # If the data starts with a [, we can reasonably assume we're dealing
          # with a jCal object.
          if data[0] == '['
            vobj = VObject::Reader.read_json(data)

            # Converting data back to iCalendar, as that's what we
            # technically support everywhere.
            data = vobj.serialize
            modified = true
          else
            vobj = VObject::Reader.read(data)
          end
        rescue VObject::ParseException => e
          raise Dav::Exception::UnsupportedMediaType, "This resource only supports valid iCalendar 2.0 data. Parse error: #{e.message}"
        end

        fail Dav::Exception::UnsupportedMediaType, 'This collection can only support iCalendar objects.' if vobj.name != 'VCALENDAR'

        s_ccs = '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set'

        # Get the Supported Components for the target calendar
        parent_path = Uri.split(path).first
        calendar_properties = @server.properties(parent_path, [s_ccs])

        if calendar_properties.key?(s_ccs)
          supported_components = calendar_properties[s_ccs].value
        else
          supported_components = ['VJOURNAL', 'VTODO', 'VEVENT']
        end

        found_type = nil
        found_uid = nil
        vobj.components.each do |component|
          case component.name
          when 'VTIMEZONE'
            next
          when 'VEVENT', 'VTODO', 'VJOURNAL'
            if found_type.nil?
              found_type = component.name
              unless supported_components.include?(found_type)
                fail Exception::InvalidComponentType, "This calendar only supports #{supported_components.join(', ')}. We found a #{found_type}"
              end
              unless component.key?('UID')
                fail Dav::Exception::BadRequest, "Every #{component.name} component must have an UID"
              end

              found_uid = component['UID'].to_s
            else
              unless found_type == component.name
                fail Dav::Exception::BadRequest, "A calendar object must only contain 1 component. We found a #{component.name} as well as a #{found_type}"
              end
              unless found_uid == component['UID'].to_s
                fail Dav::Exception::BadRequest, "Every #{component.name} in this object must have identical UIDs"
              end
            end
          else
            fail Dav::Exception::BadRequest, "You are not allowed to create components of type: #{component.name} here"
          end
        end

        fail Dav::Exception::BadRequest, 'iCalendar object must contain at least 1 of VEVENT, VTODO or VJOURNAL' unless found_type

        # We use an extra variable to allow event handles to tell us wether
        # the object was modified or not.
        #
        # This helps us determine if we need to re-serialize the object.
        sub_modified = Box.new(false)

        @server.emit(
          'calendarObjectChange',
          [
            request,
            response,
            vobj,
            parent_path,
            sub_modified,
            is_new
          ]
        )

        if sub_modified.value
          # An event handler told us that it modified the object.
          data = vobj.serialize

          # Using md5 to figure out if there was an *actual* change.
          modified = true if !modified && before != Digest::MD5.hexdigest(data)
        end

        # Destroy circular references so PHP will garbage collect the object.
        vobj.destroy

        # Update boxes
        modified_box.value = modified
        data_box.value = data
      end

      public

      # This method is used to generate HTML output for the
      # DAV\Browser\Plugin. This allows us to generate an interface users
      # can use to create new calendars.
      #
      # @param DAV\INode node
      # @param string output
      # @return bool
      def html_actions_panel(node, output)
        return true unless node.is_a?(CalendarHome)

        output.value = <<HTML
<tr><td colspan="2"><form method="post" action="">
<h3>Create new calendar</h3>
<input type="hidden" name="sabreAction" value="mkcol" />
<input type="hidden" name="resourceType" value="{DAV:}collection,{#{NS_CALDAV}}calendar" />
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
        return unless response.header('Content-Type').index('text/calendar')

        result = Http::Util.negotiate(
          request.header('Accept'),
          ['text/calendar', 'application/calendar+json']
        )

        unless result == 'application/calendar+json'
          # Do nothing
          return
        end

        # Transforming.
        vobj = VObject::Reader.read(response.body)

        json_body = vobj.json_serialize.to_json
        response.body = json_body

        # Destroy circular references so PHP will garbage collect the object.
        vobj.destroy

        response.update_header('Content-Type', 'application/calendar+json')
        response.update_header('Content-Length', json_body.bytesize)
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
          'description' => 'Adds support for CalDAV (rfc4791)',
          'link'        => 'http://sabre.io/dav/caldav/'
        }
      end

      # Sets the instance variables
      def initialize
        @max_resource_size = 10_000_000
      end
    end
  end
end
