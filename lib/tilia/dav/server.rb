require 'uri'

module Tilia
  module Dav
    # Main DAV server class
    class Server < Event::EventEmitter
      # Infinity is used for some request supporting the HTTP Depth header and indicates that the operation should traverse the entire tree
      DEPTH_INFINITY = -1

      # XML namespace for all SabreDAV related elements
      NS_SABREDAV = 'http://sabredav.org/ns'

      # The tree object
      #
      # @var Sabre\DAV\Tree
      attr_accessor :tree

      # The base uri
      #
      # @var string
      # RUBY: attr_accessor :base_uri

      # httpResponse
      #
      # @var Sabre\HTTP\Response
      attr_accessor :http_response

      # httpRequest
      #
      # @var Sabre\HTTP\Request
      attr_accessor :http_request

      # PHP HTTP Sapi
      #
      # @var Sabre\HTTP\Sapi
      attr_accessor :sapi

      # The list of plugins
      #
      # @var array
      # RUBY: attr_accessor :plugins

      # This property will be filled with a unique string that describes the
      # transaction. This is useful for performance measuring and logging
      # purposes.
      #
      # By default it will just fill it with a lowercased HTTP method name, but
      # plugins override this. For example, the WebDAV-Sync sync-collection
      # report will set this to 'report-sync-collection'.
      #
      # @var string
      attr_accessor :transaction_type

      # This is a list of properties that are always server-controlled, and
      # must not get modified with PROPPATCH.
      #
      # Plugins may add to this list.
      #
      # @var string[]
      attr_accessor :protected_properties

      # This is a flag that allow or not showing file, line and code
      # of the exception in the returned XML
      #
      # @var bool
      attr_accessor :debug_exceptions

      # This property allows you to automatically add the 'resourcetype' value
      # based on a node's classname or interface.
      #
      # The preset ensures that {DAV:}collection is automatically added for nodes
      # implementing Sabre\DAV\ICollection.
      #
      # @var array
      attr_accessor :resource_type_mapping

      # This property allows the usage of Depth: infinity on PROPFIND requests.
      #
      # By default Depth: infinity is treated as Depth: 1. Allowing Depth:
      # infinity is potentially risky, as it allows a single client to do a full
      # index of the webdav server, which is an easy DoS attack vector.
      #
      # Only turn this on if you know what you're doing.
      #
      # @var bool
      attr_accessor :enable_propfind_depth_infinity

      # Reference to the XML utility object.
      #
      # @var Xml\Service
      attr_accessor :xml

      # If this setting is turned off, SabreDAV's version number will be hidden
      # from various places.
      #
      # Some people feel this is a good security measure.
      #
      # @var bool
      @expose_version = true

      class << self
        attr_accessor :expose_version
      end

      # Sets up the server
      #
      # If a Sabre\DAV\Tree object is passed as an argument, it will
      # use it as the directory tree. If a Sabre\DAV\INode is passed, it
      # will create a Sabre\DAV\Tree and use the node as the root.
      #
      # If nothing is passed, a Sabre\DAV\SimpleCollection is created in
      # a Sabre\DAV\Tree.
      #
      # If an array is passed, we automatically create a root node, and use
      # the nodes in the array as top-level children.
      #
      # @param Tree|INode|array|null tree_or_node The tree object
      def initialize(env, tree_or_node = nil)
        super() # super without parenthesis would call initialize with our args

        @plugins = {}
        @protected_properties = [
          # RFC4918
          '{DAV:}getcontentlength',
          '{DAV:}getetag',
          '{DAV:}getlastmodified',
          '{DAV:}lockdiscovery',
          '{DAV:}supportedlock',

          # RFC4331
          '{DAV:}quota-available-bytes',
          '{DAV:}quota-used-bytes',

          # RFC3744
          '{DAV:}supported-privilege-set',
          '{DAV:}current-user-privilege-set',
          '{DAV:}acl',
          '{DAV:}acl-restrictions',
          '{DAV:}inherited-acl-set',

          # RFC3253
          '{DAV:}supported-method-set',
          '{DAV:}supported-report-set',

          # RFC6578
          '{DAV:}sync-token',

          # calendarserver.org extensions
          '{http://calendarserver.org/ns/}ctag',

          # sabredav extensions
          '{http://sabredav.org/ns}sync-token'
        ]
        @debug_exceptions = false
        @resource_type_mapping = {
          Tilia::Dav::ICollection => '{DAV:}collection'
        }
        @enable_propfind_depth_infinity = false

        if tree_or_node.is_a?(Tree)
          @tree = tree_or_node
        elsif tree_or_node.is_a?(INode)
          @tree = Tree.new(tree_or_node)
        elsif tree_or_node.is_a?(Array)
          # If it's an array, a list of nodes was passed, and we need to
          # create the root node.
          tree_or_node.each do |node|
            unless node.is_a?(INode)
              fail Exception, 'Invalid argument passed to constructor. If you\'re passing an array, all the values must implement Tilia::Dav::INode'
            end
          end

          root = SimpleCollection.new('root', tree_or_node)
          @tree = Tree.new(root)
        elsif tree_or_node.nil?
          root = SimpleCollection.new('root')
          @tree = Tree.new(root)
        else
          fail Exception, 'Invalid argument passed to constructor. Argument must either be an instance of Tilia::Dav::Tree, Tilia::Dav::INode, an array or nil'
        end

        @xml = Xml::Service.new
        @sapi = Http::Sapi.new(env)
        @http_response = Http::Response.new
        @http_request = @sapi.request
        add_plugin(CorePlugin.new)
      end

      # Starts the DAV Server
      #
      # @return void
      def exec
        # If nginx (pre-1.2) is used as a proxy server, and SabreDAV as an
        # origin, we must make sure we send back HTTP/1.0 if this was
        # requested.
        # This is mainly because nginx doesn't support Chunked Transfer
        # Encoding, and this forces the webserver SabreDAV is running on,
        # to buffer entire responses to calculate Content-Length.
        @http_response.http_version = @http_request.http_version

        # Setting the base url
        @http_request.base_url = base_uri
        invoke_method(@http_request, @http_response)
      rescue ::Exception => e # use Exception (without ::) for easier debugging
        begin
          emit('exception', [e])
        rescue
        end

        dom = LibXML::XML::Document.new

        error = LibXML::XML::Node.new('d:error')
        LibXML::XML::Namespace.new(error, 'd', 'DAV:')
        LibXML::XML::Namespace.new(error, 's', NS_SABREDAV)
        dom.root = error

        h = lambda do |v|
          CGI.escapeHTML(v)
        end

        if self.class.expose_version
          error << LibXML::XML::Node.new('s:sabredav-version', h.call(Version::VERSION))
        end

        error << LibXML::XML::Node.new('s:exception', h.call(e.class.to_s))
        error << LibXML::XML::Node.new('s:message', h.call(e.message))

        if @debug_exceptions
          backtrace_node = LibXML::XML::Node.new('s:backtrace')
          e.backtrace.each do |entry|
            backtrace_node << LibXML::XML::Node.new('s:entry', entry)
          end
          error << backtrace_node
        end

        if e.is_a?(Exception)
          http_code = e.http_code
          e.serialize(self, error)
          headers = e.http_headers(self)
        else
          http_code = 500
          headers = {}
        end

        headers['Content-Type'] = 'application/xml; charset=utf-8'
        @http_response.status = http_code
        @http_response.update_headers(headers)
        @http_response.body = dom.to_s
        sapi.send_response(@http_response)
      end

      # Sets the base server uri
      #
      # @param string uri
      # @return void
      def base_uri=(uri)
        # If the baseUri does not end with a slash, we must add it
        uri += '/' unless uri[-1] == '/'
        @base_uri = uri
      end

      # Returns the base responding uri
      #
      # @return string
      def base_uri
        @base_uri ||= guess_base_uri
      end

      # This method attempts to detect the base uri.
      # Only the PATH_INFO variable is considered.
      #
      # If this variable is not set, the root (/) is assumed.
      #
      # @return string
      def guess_base_uri
        "#{@http_request.raw_server_value('SCRIPT_NAME')}/"
      end

      # Adds a plugin to the server
      #
      # For more information, console the documentation of Sabre\DAV\ServerPlugin
      #
      # @param ServerPlugin plugin
      # @return void
      def add_plugin(plugin)
        @plugins[plugin.plugin_name] = plugin
        plugin.setup(self)
      end

      # Returns an initialized plugin by it's name.
      #
      # This function returns null if the plugin was not found.
      #
      # @param string name
      # @return ServerPlugin
      def plugin(name)
        @plugins[name]
      end

      # Returns all plugins
      #
      # @return array
      attr_reader :plugins

      # Handles a http request, and execute a method based on its name
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @param send_response Whether to send the HTTP response to the DAV client.
      # @return void
      def invoke_method(request, response, _send_response = true)
        method = request.method

        return nil unless emit("beforeMethod:#{method}", [request, response])
        return nil unless emit('beforeMethod', [request, response])

        if Server.expose_version
          response.update_header('X-Sabre-Version', Version::VERSION)
        end

        @transaction_type = method.downcase

        unless check_preconditions(request, response)
          @sapi.send_response(response)
          return nil
        end

        if emit("method:#{method}", [request, response])
          if emit('method', [request, response])
            # Unsupported method
            fail Exception::NotImplemented, "'There was no handler found for this \"#{method}\" method"
          end
        end

        return nil unless emit("afterMethod:#{method}", [request, response])
        return nil unless emit('afterMethod', [request, response])

        # No need for checking, send_response just returns an array
        response = sapi.send_response(response)
      end

      # {{{ HTTP/WebDAV protocol helpers

      # Returns an array with all the supported HTTP methods for a specific uri.
      #
      # @param string path
      # @return array
      def allowed_methods(path)
        methods = [
          'OPTIONS',
          'GET',
          'HEAD',
          'DELETE',
          'PROPFIND',
          'PUT',
          'PROPPATCH',
          'COPY',
          'MOVE',
          'REPORT'
        ]

        # The MKCOL is only allowed on an unmapped uri
        begin
          @tree.node_for_path(path)
        rescue Exception::NotFound => e
          methods << 'MKCOL'
        end

        # We're also checking if any of the plugins register any new methods
        @plugins.each do |_, plugin|
          methods += plugin.http_methods(path)
        end

        methods.uniq
      end

      # Gets the uri for the request, keeping the base uri into consideration
      #
      # @return string
      def request_uri
        calculate_uri(@http_request.url)
      end

      # Calculates the uri for a request, making sure that the base uri is stripped out
      #
      # @param string uri
      # @throws Exception\Forbidden A permission denied exception is thrown whenever there was an attempt to supply a uri outside of the base uri
      # @return string
      def calculate_uri(uri)
        if uri[0] != '/' && uri.index('://') && uri.index('://') > 0
          uri = ::URI.split(uri)[5] # path component of uri
        end

        uri = Uri.normalize(uri.gsub('//', '/'))
        base_uri = Uri.normalize(self.base_uri)

        if uri.index(base_uri) == 0
          return Http::UrlUtil.decode_path(uri[base_uri.length..-1]).gsub(%r{^/+}, '').gsub(%r{/+$}, '')

        elsif "#{uri}/" == base_uri
          # A special case, if the baseUri was accessed without a trailing
          # slash, we'll accept it as well.
          return ''
        else
          fail Exception::Forbidden, "Requested uri (#{uri}) is out of base uri (#{self.base_uri})"
        end
      end

      # Returns the HTTP depth header
      #
      # This method returns the contents of the HTTP depth request header. If the depth header was 'infinity' it will return the Sabre\DAV\Server::DEPTH_INFINITY object
      # It is possible to supply a default depth value, which is used when the depth header has invalid content, or is completely non-existent
      #
      # @param mixed default
      # @return int
      def http_depth(default = DEPTH_INFINITY)
        # If its not set, we'll grab the default
        depth = @http_request.header('Depth')

        return default unless depth

        return DEPTH_INFINITY if depth == 'infinity'

        # If its an unknown value. we'll grab the default
        return default unless depth =~ /^[\+\-0-9\.]$/ # TODO: valid replacement for ctype_digit?

        depth.to_i
      end

      # Returns the HTTP range header
      #
      # This method returns null if there is no well-formed HTTP range request
      # header or array(start, end).
      #
      # The first number is the offset of the first byte in the range.
      # The second number is the offset of the last byte in the range.
      #
      # If the second offset is null, it should be treated as the offset of the last byte of the entity
      # If the first offset is null, the second offset should be used to retrieve the last x bytes of the entity
      #
      # @return array|null
      def http_range
        range = @http_request.header('range')
        return nil unless range

        # Matching "Range: bytes=1234-5678: both numbers are optional
        matches = /^bytes=([0-9]*)-([0-9]*)$/i.match(range)
        return nil unless matches

        return nil if matches[1] == '' && matches[2] == ''

        [
          matches[1] != '' ? matches[1].to_i : nil,
          matches[2] != '' ? matches[2].to_i : nil
        ]
      end

      # Returns the HTTP Prefer header information.
      #
      # The prefer header is defined in:
      # http://tools.ietf.org/html/draft-snell-http-prefer-14
      #
      # This method will return an array with options.
      #
      # Currently, the following options may be returned:
      #  [
      #      'return-asynch'         => true,
      #      'return-minimal'        => true,
      #      'return-representation' => true,
      #      'wait'                  => 30,
      #      'strict'                => true,
      #      'lenient'               => true,
      #  ]
      #
      # This method also supports the Brief header, and will also return
      # 'return-minimal' if the brief header was set to 't'.
      #
      # For the boolean options, false will be returned if the headers are not
      # specified. For the integer options it will be 'null'.
      #
      # @return array
      def http_prefer
        result = {
          # can be true or false
          'respond-async' => false,
          # Could be set to 'representation' or 'minimal'.
          'return'        => nil,
          # Used as a timeout, is usually a number.
          'wait'          => nil,
          # can be 'strict' or 'lenient'.
          'handling'      => false
        }

        prefer = @http_request.header('Prefer')
        if prefer
          result = result.merge(Tilia::Http.parse_prefer(prefer))
        elsif @http_request.header('Brief') == 't'
          result['return'] = 'minimal'
        end

        result
      end

      # Returns information about Copy and Move requests
      #
      # This function is created to help getting information about the source and the destination for the
      # WebDAV MOVE and COPY HTTP request. It also validates a lot of information and throws proper exceptions
      #
      # The returned value is an array with the following keys:
      #   * destination - Destination path
      #   * destinationExists - Whether or not the destination is an existing url (and should therefore be overwritten)
      #
      # @param RequestInterface request
      # @throws Exception\BadRequest upon missing or broken request headers
      # @throws Exception\UnsupportedMediaType when trying to copy into a
      #         non-collection.
      # @throws Exception\PreconditionFailed If overwrite is set to false, but
      #         the destination exists.
      # @throws Exception\Forbidden when source and destination paths are
      #         identical.
      # @throws Exception\Conflict When trying to copy a node into its own
      #         subtree.
      # @return array
      def copy_and_move_info(request)
        # Collecting the relevant HTTP headers
        unless request.header('Destination')
          fail Exception::BadRequest, 'The destination header was not supplied'
        end

        destination = calculate_uri(request.header('Destination'))
        overwrite = request.header('Overwrite')

        overwrite = 'T' unless overwrite
        if overwrite.upcase == 'T'
          overwrite = true
        elsif overwrite.upcase == 'F'
          overwrite = false
        else
          # We need to throw a bad request exception, if the header was invalid
          fail Exception::BadRequest, 'The HTTP Overwrite header should be either T or F'
        end

        (destination_dir,) = Http::UrlUtil.split_path(destination)

        begin
          destination_parent = @tree.node_for_path(destination_dir)

          unless destination_parent.is_a?(ICollection)
            fail Exception::UnsupportedMediaType, 'The destination node is not a collection'
          end
        rescue Exception::NotFound => e
          # If the destination parent node is not found, we throw a 409
          raise Exception::Conflict, 'The destination node is not found'
        end

        begin
          destination_node = @tree.node_for_path(destination)

          # If this succeeded, it means the destination already exists
          # we'll need to throw precondition failed in case overwrite is false
          unless overwrite
            fail Exception::PreconditionFailed, 'The destination node already exists, and the overwrite header is set to false', 'Overwrite'
          end
        rescue Exception::NotFound => e
          # Destination didn't exist, we're all good
          destination_node = false
        end

        request_path = request.path
        if destination == request_path
          fail Exception::Forbidden, 'Source and destination uri are identical.'
        end
        if destination[0..request_path.length] == request_path + '/'
          fail Exception::Conflict, 'The destination may not be part of the same subtree as the source path.'
        end

        # These are the three relevant properties we need to return
        {
          'destination'       => destination,
          'destinationExists' => !!destination_node,
          'destinationNode'   => destination_node
        }
      end

      # Returns a list of properties for a path
      #
      # This is a simplified version getPropertiesForPath. If you aren't
      # interested in status codes, but you just want to have a flat list of
      # properties, use this method.
      #
      # Please note though that any problems related to retrieving properties,
      # such as permission issues will just result in an empty array being
      # returned.
      #
      # @param string path
      # @param array property_names
      def properties(path, property_names)
        result = properties_for_path(path, property_names, 0)
        if result[0].key?(200)
          return result[0][200]
        else
          return []
        end
      end

      # A kid-friendly way to fetch properties for a node's children.
      #
      # The returned array will be indexed by the path of the of child node.
      # Only properties that are actually found will be returned.
      #
      # The parent node will not be returned.
      #
      # @param string path
      # @param array property_names
      # @return array
      def properties_for_children(path, property_names)
        result = {}
        properties_for_path(path, property_names, 1).each_with_index do |row, k|
          # Skipping the parent path
          next if k == 0

          result[row['href']] = row[200]
        end

        result
      end

      # Returns a list of HTTP headers for a particular resource
      #
      # The generated http headers are based on properties provided by the
      # resource. The method basically provides a simple mapping between
      # DAV property and HTTP header.
      #
      # The headers are intended to be used for HEAD and GET requests.
      #
      # @param string path
      # @return array
      def http_headers(path)
        property_map = {
          '{DAV:}getcontenttype'   => 'Content-Type',
          '{DAV:}getcontentlength' => 'Content-Length',
          '{DAV:}getlastmodified'  => 'Last-Modified',
          '{DAV:}getetag'          => 'ETag'
        }

        properties = properties(path, property_map.keys)

        headers = {}
        property_map.each do |property, header|
          next unless properties.key?(property)

          if properties[property].scalar?
            headers[header] = properties[property]
          elsif properties[property].is_a?(Xml::Property::GetLastModified)
            # GetLastModified gets special cased
            headers[header] = Http::Util.to_http_date(properties[property].time)
          end
        end

        headers
      end

      private

      # Small helper to support PROPFIND with DEPTH_INFINITY.
      #
      # @param array[] prop_find_requests
      # @param PropFind prop_find
      # @return void
      def add_path_nodes_recursively(prop_find_requests, prop_find)
        new_depth = prop_find.depth
        path = prop_find.path

        new_depth -= 1 unless new_depth == DEPTH_INFINITY

        @tree.children(path).each do |child_node|
          sub_prop_find = prop_find.clone
          sub_prop_find.depth = new_depth

          if path != ''
            sub_path = path + '/' + child_node.name
          else
            sub_path = child_node.name
          end
          sub_prop_find.path = sub_path

          prop_find_requests << [
            sub_prop_find,
            child_node
          ]

          if (new_depth == DEPTH_INFINITY || new_depth >= 1) && child_node.is_a?(ICollection)
            add_path_nodes_recursively(prop_find_requests, sub_prop_find)
          end
        end
      end

      public

      # Returns a list of properties for a given path
      #
      # The path that should be supplied should have the baseUrl stripped out
      # The list of properties should be supplied in Clark notation. If the list is empty
      # 'allprops' is assumed.
      #
      # If a depth of 1 is requested child elements will also be returned.
      #
      # @param string path
      # @param array property_names
      # @param int depth
      # @return array
      def properties_for_path(path, property_names = [], depth = 0)
        property_names = [property_names] unless property_names.is_a?(Array)

        # The only two options for the depth of a propfind is 0 or 1 - as long as depth infinity is not enabled
        depth = 1 unless @enable_propfind_depth_infinity || depth == 0

        path = path.gsub(%r{^/+}, '').gsub(%r{/+$}, '')

        prop_find_type = property_names.any? ? PropFind::NORMAL : PropFind::ALLPROPS
        prop_find = PropFind.new(path, property_names, depth, prop_find_type)

        parent_node = @tree.node_for_path(path)

        prop_find_requests = [
          [
            prop_find,
            parent_node
          ]
        ]

        if (depth > 0 || depth == DEPTH_INFINITY) && parent_node.is_a?(ICollection)
          add_path_nodes_recursively(prop_find_requests, prop_find)
        end

        return_property_list = []

        prop_find_requests.each do |prop_find_request|
          (prop_find, node) = prop_find_request
          r = properties_by_node(prop_find, node)
          next unless r
          result = prop_find.result_for_multi_status
          result['href'] = prop_find.path

          # WebDAV recommends adding a slash to the path, if the path is
          # a collection.
          # Furthermore, iCal also demands this to be the case for
          # principals. This is non-standard, but we support it.
          resource_type = resource_type_for_node(node)
          if resource_type.include?('{DAV:}collection') || resource_type.include?('{DAV:}principal')
            result['href'] += '/'
          end
          return_property_list << result
        end

        return_property_list
      end

      # Returns a list of properties for a list of paths.
      #
      # The path that should be supplied should have the baseUrl stripped out
      # The list of properties should be supplied in Clark notation. If the list is empty
      # 'allprops' is assumed.
      #
      # The result is returned as an array, with paths for it's keys.
      # The result may be returned out of order.
      #
      # @param array paths
      # @param array property_names
      # @return array
      def properties_for_multiple_paths(paths, property_names = [])
        result = {}

        nodes = @tree.multiple_nodes(paths)

        nodes.each do |path, node|
          prop_find = PropFind.new(path, property_names)
          r = properties_by_node(prop_find, node)
          next unless r
          result[path] = prop_find.result_for_multi_status
          result[path]['href'] = path

          resource_type = resource_type_for_node(node)
          if resource_type.include?('{DAV:}collection') || resource_type.include?('{DAV:}principal')
            result[path]['href'] += '/'
          end
        end

        result
      end

      # Determines all properties for a node.
      #
      # This method tries to grab all properties for a node. This method is used
      # internally getPropertiesForPath and a few others.
      #
      # It could be useful to call this, if you already have an instance of your
      # target node and simply want to run through the system to get a correct
      # list of properties.
      #
      # @param PropFind prop_find
      # @param INode node
      # @return bool
      def properties_by_node(prop_find, node)
        emit('propFind', [prop_find, node])
      end

      # This method is invoked by sub-systems creating a new file.
      #
      # Currently this is done by HTTP PUT and HTTP LOCK (in the Locks_Plugin).
      # It was important to get this done through a centralized function,
      # allowing plugins to intercept this using the beforeCreateFile event.
      #
      # This method will return true if the file was actually created
      #
      # @param string   uri
      # @param resource data
      # @param string   etag
      # @return bool
      def create_file(uri, data, etag = Box.new)
        (dir, name) = Http::UrlUtil.split_path(uri)

        return false unless emit('beforeBind', [uri])

        parent = @tree.node_for_path(dir)
        unless parent.is_a?(ICollection)
          fail Exception::Conflict, 'Files can only be created as children of collections'
        end

        # It is possible for an event handler to modify the content of the
        # body, before it gets written. If this is the case, modified
        # should be set to true.
        #
        # If modified is true, we must not send back an ETag.
        modified = Box.new(false)
        box = Box.new(data)
        return false unless emit('beforeCreateFile', [uri, box, parent, modified])
        data = box.value

        etag.value = parent.create_file(name, data)
        etag.value = nil if modified.value

        @tree.mark_dirty(dir + '/' + name)

        emit('afterBind', [uri])
        emit('afterCreateFile', [uri, parent])

        true
      end

      # This method is invoked by sub-systems updating a file.
      #
      # This method will return true if the file was actually updated
      #
      # @param string   uri
      # @param resource data
      # @param string   etag
      # @return bool
      def update_file(uri, data, etag = Box.new)
        node = @tree.node_for_path(uri)

        # It is possible for an event handler to modify the content of the
        # body, before it gets written. If this is the case, modified
        # should be set to true.
        #
        # If modified is true, we must not send back an ETag.
        modified = Box.new(false)
        data = Box.new(data)

        return false unless emit('beforeWriteContent', [uri, node, data, modified])

        etag.value = node.put(data.value)
        etag.value = nil if modified.value

        emit('afterWriteContent', [uri, node])

        true
      end

      # This method is invoked by sub-systems creating a new Directory.
      #
      # @param string uri
      # @return void
      def create_directory(uri)
        create_collection(uri, MkCol.new(['{DAV:}collection'], []))
      end

      # Use this method to create a new collection
      #
      # @param string uri The new uri
      # @param MkCol mk_col
      # @return array|null
      def create_collection(uri, mk_col)
        (parent_uri, new_name) = Http::UrlUtil.split_path(uri)

        # Making sure the parent exists
        begin
          parent = @tree.node_for_path(parent_uri)
        rescue Exception::NotFound => e
          raise Exception::Conflict, 'Parent node does not exist'
        end

        # Making sure the parent is a collection
        unless parent.is_a?(ICollection)
          fail Exception::Conflict, 'Parent node is not a collection'
        end

        # Making sure the child does not already exist
        begin
          parent.child(new_name)

          # If we got here.. it means there's already a node on that url, and we need to throw a 405
          fail Exception::MethodNotAllowed, 'The resource you tried to create already exists'
        rescue Exception::NotFound => e
          # NotFound is the expected behavior.
        end

        return nil unless emit('beforeBind', [uri])

        if parent.is_a?(IExtendedCollection)
          # If the parent is an instance of IExtendedCollection, it means that
          # we can pass the MkCol object directly as it may be able to store
          # properties immediately.
          parent.create_extended_collection(new_name, mk_col)
        else
          # If the parent is a standard ICollection, it means only
          # 'standard' collections can be created, so we should fail any
          # MKCOL operation that carries extra resourcetypes.
          if mk_col.resource_type.size > 1
            fail Exception::InvalidResourceType, 'The {DAV:}resourcetype you specified is not supported here.'
          end

          parent.create_directory(new_name)
        end

        # If there are any properties that have not been handled/stored,
        # we ask the 'propPatch' event to handle them. This will allow for
        # example the propertyStorage system to store properties upon MKCOL.
        emit('propPatch', [uri, mk_col]) if mk_col.remaining_mutations
        success = mk_col.commit

        unless success
          result = mk_col.result
          # generateMkCol needs the href key to exist.
          result['href'] = uri
          return result
        end

        @tree.mark_dirty(parent_uri)
        emit('afterBind', [uri])
      end

      # This method updates a resource's properties
      #
      # The properties array must be a list of properties. Array-keys are
      # property names in clarknotation, array-values are it's values.
      # If a property must be deleted, the value should be null.
      #
      # Note that this request should either completely succeed, or
      # completely fail.
      #
      # The response is an array with properties for keys, and http status codes
      # as their values.
      #
      # @param string path
      # @param array properties
      # @return array
      def update_properties(path, properties)
        prop_patch = PropPatch.new(properties)
        emit('propPatch', [path, prop_patch])
        prop_patch.commit

        prop_patch.result
      end

      # This method checks the main HTTP preconditions.
      #
      # Currently these are:
      #   * If-Match
      #   * If-None-Match
      #   * If-Modified-Since
      #   * If-Unmodified-Since
      #
      # The method will return true if all preconditions are met
      # The method will return false, or throw an exception if preconditions
      # failed. If false is returned the operation should be aborted, and
      # the appropriate HTTP response headers are already set.
      #
      # Normally this method will throw 412 Precondition Failed for failures
      # related to If-None-Match, If-Match and If-Unmodified Since. It will
      # set the status to 304 Not Modified for If-Modified_since.
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def check_preconditions(request, response)
        path = request.path
        node = nil
        last_mod = nil
        etag = nil

        if_match = request.header('If-Match')
        if if_match
          # If-Match contains an entity tag. Only if the entity-tag
          # matches we are allowed to make the request succeed.
          # If the entity-tag is '*' we are only allowed to make the
          # request succeed if a resource exists at that url.
          begin
            node = @tree.node_for_path(path)
          rescue Exception::NotFound => e
            raise Exception::PreconditionFailed.new('If-Match'), 'An If-Match header was specified and the resource did not exist'
          end

          # Only need to check entity tags if they are not *
          if if_match != '*'
            # There can be multiple ETags
            if_match = if_match.split(',')
            have_match = false
            if_match.each do |if_match_item|
              # Stripping any extra spaces
              if_match_item = if_match_item.strip

              etag = node.is_a?(IFile) ? node.etag : nil
              if etag == if_match_item
                have_match = true
              else
                # Evolution has a bug where it sometimes prepends the "
                # with a \. This is our workaround.
                have_match = true if if_match_item.gsub('\\"', '"') == etag
              end
            end

            unless have_match
              response.update_header('ETag', etag) if etag
              fail Exception::PreconditionFailed.new('If-Match'), 'An If-Match header was specified, but none of the specified the ETags matched.'
            end
          end
        end

        if_none_match = request.header('If-None-Match')
        if if_none_match
          # The If-None-Match header contains an ETag.
          # Only if the ETag does not match the current ETag, the request will succeed
          # The header can also contain *, in which case the request
          # will only succeed if the entity does not exist at all.
          node_exists = true
          unless node
            begin
              node = @tree.node_for_path(path)
            rescue Exception::NotFound => e
              node_exists = false
            end
          end

          if node_exists
            have_match = false
            if if_none_match == '*'
              have_match = true
            else
              # There might be multiple ETags
              if_none_match = if_none_match.split(',')
              etag = node.is_a?(IFile) ? node.etag : nil

              if_none_match.each do |if_none_match_item|
                # Stripping any extra spaces
                if_none_match_item = if_none_match_item.strip

                have_match = true if etag == if_none_match_item
              end
            end

            if have_match
              response.update_header('ETag', etag) if etag
              if request.method == 'GET'
                response.status = 304
                return false
              else
                fail Exception::PreconditionFailed.new('If-None-Match'), 'An If-None-Match header was specified, but the ETag matched (or * was specified).'
              end
            end
          end
        end

        if_modified_since = request.header('If-Modified-Since')
        if !if_none_match && if_modified_since
          # The If-Modified-Since header contains a date. We
          # will only return the entity if it has been changed since
          # that date. If it hasn't been changed, we return a 304
          # header
          # Note that this header only has to be checked if there was no If-None-Match header
          # as per the HTTP spec.
          date = Http::Util.parse_http_date(if_modified_since)

          if date
            node = @tree.node_for_path(path) if node.nil?
            last_mod = node.last_modified
            if last_mod
              last_mod = Time.at(last_mod)
              if last_mod <= date
                response.status = 304
                response.update_header('Last-Modified', Http::Util.to_http_date(last_mod))
                return false
              end
            end
          end
        end

        if_unmodified_since = request.header('If-Unmodified-Since')
        if if_unmodified_since
          # The If-Unmodified-Since will allow allow the request if the
          # entity has not changed since the specified date.
          date = Http::Util.parse_http_date(if_unmodified_since)

          # We must only check the date if it's valid
          if date
            node = @tree.node_for_path(path) if node.nil?
            last_mod = node.last_modified
            if last_mod
              last_mod = Time.at(last_mod)
              if last_mod > date
                fail Exception::PreconditionFailed.new('If-Unmodified-Since'), 'An If-Unmodified-Since header was specified, but the entity has been changed since the specified date.'
              end
            end
          end
        end

        # Now the hardest, the If: header. The If: header can contain multiple
        # urls, ETags and so-called 'state tokens'.
        #
        # Examples of state tokens include lock-tokens (as defined in rfc4918)
        # and sync-tokens (as defined in rfc6578).
        #
        # The only proper way to deal with these, is to emit events, that a
        # Sync and Lock plugin can pick up.
        if_conditions = if_conditions(request)

        if_conditions.each_with_index do |if_condition, kk|
          if_condition['tokens'].each_with_index do |_token, ii|
            if_conditions[kk]['tokens'][ii]['validToken'] = false
          end
        end

        # Plugins are responsible for validating all the tokens.
        # If a plugin deemed a token 'valid', it will set 'validToken' to
        # true.
        box = Box.new(if_conditions)
        emit('validateTokens', [request, box])
        if_conditions = box.value

        # Now we're going to analyze the result.

        # Every ifCondition needs to validate to true, so we exit as soon as
        # we have an invalid condition.
        if_conditions.each do |if_condition|
          uri = if_condition['uri']
          tokens = if_condition['tokens']

          # We only need 1 valid token for the condition to succeed.
          skip = false
          tokens.each do |token|
            token_valid = token['validToken'] || token['token'].blank?

            etag_valid = false
            etag_valid = true if token['etag'].blank?

            # Checking the ETag, only if the token was already deamed
            # valid and there is one.
            if !token['etag'].blank? && token_valid
              # The token was valid, and there was an ETag. We must
              # grab the current ETag and check it.
              node = @tree.node_for_path(uri)
              etag_valid = node.is_a?(IFile) && node.etag == token['etag']
            end

            next unless (token_valid && etag_valid) ^ token['negate']
            skip = true
            break
          end
          next if skip

          # If we ended here, it means there was no valid ETag + token
          # combination found for the current condition. This means we fail!
          fail Exception::PreconditionFailed.new('If'), "Failed to find a valid token/etag combination for #{uri}"
        end

        true
      end

      # This method is created to extract information from the WebDAV HTTP 'If:' header
      #
      # The If header can be quite complex, and has a bunch of features. We're using a regex to extract all relevant information
      # The function will return an array, containing structs with the following keys
      #
      #   * uri   - the uri the condition applies to.
      #   * tokens - The lock token. another 2 dimensional array containing 3 elements
      #
      # Example 1:
      #
      # If: (<opaquelocktoken:181d4fae-7d8c-11d0-a765-00a0c91e6bf2>)
      #
      # Would result in:
      #
      # [
      #    [
      #       'uri' => '/request/uri',
      #       'tokens' => [
      #          [
      #              [
      #                  'negate' => false,
      #                  'token'  => 'opaquelocktoken:181d4fae-7d8c-11d0-a765-00a0c91e6bf2',
      #                  'etag'   => ""
      #              ]
      #          ]
      #       ],
      #    ]
      # ]
      #
      # Example 2:
      #
      # If: </path/> (Not <opaquelocktoken:181d4fae-7d8c-11d0-a765-00a0c91e6bf2> ["Im An ETag"]) (["Another ETag"]) </path2/> (Not ["Path2 ETag"])
      #
      # Would result in:
      #
      # [
      #    [
      #       'uri' => 'path',
      #       'tokens' => [
      #          [
      #              [
      #                  'negate' => true,
      #                  'token'  => 'opaquelocktoken:181d4fae-7d8c-11d0-a765-00a0c91e6bf2',
      #                  'etag'   => '"Im An ETag"'
      #              ],
      #              [
      #                  'negate' => false,
      #                  'token'  => '',
      #                  'etag'   => '"Another ETag"'
      #              ]
      #          ]
      #       ],
      #    ],
      #    [
      #       'uri' => 'path2',
      #       'tokens' => [
      #          [
      #              [
      #                  'negate' => true,
      #                  'token'  => '',
      #                  'etag'   => '"Path2 ETag"'
      #              ]
      #          ]
      #       ],
      #    ],
      # ]
      #
      # @param RequestInterface request
      # @return array
      def if_conditions(request)
        header = request.header('If')
        return [] unless header

        matches = []

        regex = /(?:\<(?<uri>.*?)\>\s)?\((?<not>Not\s)?(?:\<(?<token>[^\>]*)\>)?(?:\s?)(?:\[(?<etag>[^\]]*)\])?\)/im
        conditions = []

        header.scan(regex) do |match|
          # RUBY: #scan returns an Array, but we want a named match.
          # last_match provides this
          match = Regexp.last_match

          # If there was no uri specified in this match, and there were
          # already conditions parsed, we add the condition to the list of
          # conditions for the previous uri.
          if !match['uri'] && conditions.any?
            conditions[conditions.size - 1]['tokens'] << {
              'negate' => match['not'] ? true : false,
              'token'  => match['token'] || '',
              'etag'   => match['etag'] ? match['etag'] : ''
            }
          else
            if !match['uri']
              real_uri = request.path
            else
              real_uri = calculate_uri(match['uri'])
            end

            conditions << {
              'uri'    => real_uri,
              'tokens' => [
                {
                  'negate' => match['not'] ? true : false,
                  'token'  => match['token'] || '',
                  'etag'   => match['etag'] ? match['etag'] : ''
                }
              ]
            }
          end
        end

        conditions
      end

      # Returns an array with resourcetypes for a node.
      #
      # @param INode node
      # @return array
      def resource_type_for_node(node)
        result = []
        @resource_type_mapping.each do |class_name, resource_type|
          result << resource_type if node.is_a?(class_name)
        end

        result
      end

      # }}}
      # {{{ XML Readers & Writers

      # Generates a WebDAV propfind response body based on a list of nodes.
      #
      # If 'strip404s' is set to true, all 404 responses will be removed.
      #
      # @param array file_properties The list with nodes
      # @param bool strip404s
      # @return string
      def generate_multi_status(file_properties, strip404s = false)
        xml = []

        file_properties.each do |entry|
          href = entry['href']
          entry.delete('href')

          entry.delete(404) if strip404s

          response = Xml::Element::Response.new(
            href.gsub(%r{^/+}, ''),
            entry
          )
          xml << {
            'name'  => '{DAV:}response',
            'value' => response
          }
        end

        @xml.write('{DAV:}multistatus', xml, @base_uri)
      end
    end
  end
end
