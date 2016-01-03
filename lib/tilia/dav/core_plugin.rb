require 'stringio'

module Tilia
  module Dav
    # The core plugin provides all the basic features for a WebDAV server.
    class CorePlugin < ServerPlugin
      # Reference to server object.
      #
      # @var Server
      # RUBY: attr_accessor :server

      # Sets up the plugin
      #
      # @param Server server
      # @return void
      def setup(server)
        @server = server
        server.on('method:GET',       method(:http_get))
        server.on('method:OPTIONS',   method(:http_options))
        server.on('method:HEAD',      method(:http_head))
        server.on('method:DELETE',    method(:http_delete))
        server.on('method:PROPFIND',  method(:http_prop_find))
        server.on('method:PROPPATCH', method(:http_prop_patch))
        server.on('method:PUT',       method(:http_put))
        server.on('method:MKCOL',     method(:http_mkcol))
        server.on('method:MOVE',      method(:http_move))
        server.on('method:COPY',      method(:http_copy))
        server.on('method:REPORT',    method(:http_report))

        server.on('propPatch',        method(:prop_patch_protected_property_check), 90)
        server.on('propPatch',        method(:prop_patch_node_update), 200)
        server.on('propFind',         method(:prop_find))
        server.on('propFind',         method(:prop_find_node), 120)
        server.on('propFind',         method(:prop_find_late), 200)
      end

      # Returns a plugin name.
      #
      # Using this name other plugins will be able to access other plugins
      # using DAV\Server::getPlugin
      #
      # @return string
      def plugin_name
        'core'
      end

      # This is the default implementation for the GET method.
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_get(request, response)
        path = request.path
        node = @server.tree.node_for_path(path)

        return nil unless node.is_a?(IFile)

        body = node.get

        # Converting string into stream, if needed.
        if body.is_a?(String)
          stream = StringIO.new
          stream.write(body)
          stream.rewind
          body = stream
        end

        # TODO: getetag, getlastmodified, getsize should also be used using
        # this method
        http_headers = @server.http_headers(path)

        # ContentType needs to get a default, because many webservers will otherwise
        # default to text/html, and we don't want this for security reasons.
        unless http_headers.key?('Content-Type')
          http_headers['Content-Type'] = 'application/octet-stream'
        end

        if http_headers.key?('Content-Length')
          node_size = http_headers['Content-Length'].to_i

          # Need to unset Content-Length, because we'll handle that during figuring out the range
          http_headers.delete('Content-Length')
        else
          node_size = 0
        end

        response.add_headers(http_headers)

        range = @server.http_range
        if_range = request.header('If-Range')
        ignore_range_header = false

        # If ifRange is set, and range is specified, we first need to check
        # the precondition.
        if node_size > 0 && range && if_range
          # if IfRange is parsable as a date we'll treat it as a DateTime
          # otherwise, we must treat it as an etag.

          if_range_date = Chronic.parse(if_range)

          if if_range_date
            # It's a date. We must check if the entity is modified since
            # the specified date.
            if !http_headers.key?('Last-Modified')
              ignore_range_header = true
            else
              modified = Time.parse(http_headers['Last-Modified'])
              ignore_range_header = true if modified > if_range_date
            end
          else
            # It's an entity. We can do a simple comparison.
            if !http_headers.key?('ETag')
              ignore_range_header = true
            elsif http_headers['ETag'] != if_range
              ignore_range_header = true
            end
          end
        end

        # We're only going to support HTTP ranges if the backend provided a filesize
        if !ignore_range_header && node_size && range
          # Determining the exact byte offsets
          if range[0]
            start = range[0]
            ending = range[1] ? range[1] : node_size - 1
            if start >= node_size
              fail Exception::RequestedRangeNotSatisfiable, "The start offset (#{range[0]}) exceeded the size of the entity (#{node_size})"
            end

            if ending < start
              fail Exception::RequestedRangeNotSatisfiable, "The end offset (#{range[1]}) is lower than the start offset (#{range[0]})"
            end

            ending = node_size - 1 if ending >= node_size
          else
            start = node_size - range[1]
            ending = node_size - 1

            start = 0 if start < 0
          end

          # for a seekable body stream we simply set the pointer
          # for a non-seekable body stream we read and discard just the
          # right amount of data
          if body.respond_to?(:seek)
            body.seek(start)
          else
            consume_block = 8192
            consumed = 0
            loop do
              break unless start - consumed > 0

              if body.eof?
                fail Exception::RequestedRangeNotSatisfiable, "The start offset (#{start}) exceeded the size of the entity (#{consumed})"
              end

              consumed += body.read([start - consumed, consume_block].min)
            end
          end

          response.update_header('Content-Length', ending - start + 1)
          response.update_header('Content-Range', "bytes #{start}-#{ending}/#{node_size}")
          response.status = 206
          response.body = body
        else
          response.update_header('Content-Length', node_size) if node_size > 0
          response.status = 200
          response.body = body
        end

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # HTTP OPTIONS
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_options(request, response)
        methods = @server.allowed_methods(request.path)

        response.update_header('Allow', methods.join(', ').upcase)
        features = ['1', '3', 'extended-mkcol']

        @server.plugins.each do |_name, plugin|
          features += plugin.features
        end

        response.update_header('DAV', features.join(', '))
        response.update_header('MS-Author-Via', 'DAV')
        response.update_header('Accept-Ranges', 'bytes')
        response.update_header('Content-Length', '0')
        response.status = 200

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # HTTP HEAD
      #
      # This method is normally used to take a peak at a url, and only get the
      # HTTP response headers, without the body. This is used by clients to
      # determine if a remote file was changed, so they can use a local cached
      # version, instead of downloading it again
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_head(request, response)
        # This is implemented by changing the HEAD request to a GET request,
        # and dropping the response body.
        sub_request = request.clone
        sub_request.method = 'GET'

        begin
          @server.invoke_method(sub_request, response, false)
          response.body = ''
        rescue Exception::NotImplemented => e
          # Some clients may do HEAD requests on collections, however, GET
          # requests and HEAD requests _may_ not be defined on a collection,
          # which would trigger a 501.
          # This breaks some clients though, so we're transforming these
          # 501s into 200s.
          response.status = 200
          response.body = ''
          response.update_header('Content-Type', 'text/plain')
          response.update_header('X-Sabre-Real-Status', e.http_code)
        end

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # HTTP Delete
      #
      # The HTTP delete method, deletes a given uri
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return void
      def http_delete(request, response)
        path = request.path

        return false unless @server.emit('beforeUnbind', [path])

        @server.tree.delete(path)

        @server.emit('afterUnbind', [path])

        response.status = 204
        response.update_header('Content-Length', '0')

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # WebDAV PROPFIND
      #
      # This WebDAV method requests information about an uri resource, or a list of resources
      # If a client wants to receive the properties for a single resource it will add an HTTP Depth: header with a 0 value
      # If the value is 1, it means that it also expects a list of sub-resources (e.g.: files in a directory)
      #
      # The request body contains an XML data structure that has a list of properties the client understands
      # The response body is also an xml document, containing information about every uri resource and the requested properties
      #
      # It has to return a HTTP 207 Multi-status status code
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return void
      def http_prop_find(request, response)
        path = request.path

        request_body = request.body_as_string
        if request_body.size > 0
          begin
            prop_find_xml = @server.xml.expect('{DAV:}propfind', request_body)
          rescue Tilia::Xml::ParseException => e
            raise Exception::BadRequest, e.message, nil, e
          end
        else
          prop_find_xml = Xml::Request::PropFind.new
          prop_find_xml.all_prop = true
          prop_find_xml.properties = []
        end

        depth = @server.http_depth(1)
        # The only two options for the depth of a propfind is 0 or 1 - as long as depth infinity is not enabled
        depth = 1 if !@server.enable_propfind_depth_infinity && depth != 0

        new_properties = @server.properties_for_path(path, prop_find_xml.properties, depth)

        # This is a multi-status response
        response.status = 207
        response.update_header('Content-Type', 'application/xml; charset=utf-8')
        response.update_header('Vary', 'Brief,Prefer')

        # Normally this header is only needed for OPTIONS responses, however..
        # iCal seems to also depend on these being set for PROPFIND. Since
        # this is not harmful, we'll add it.
        features = ['1', '3', 'extended-mkcol']
        @server.plugins.each do |_, plugin|
          features += plugin.features
        end
        response.update_header('DAV', features.join(', '))

        prefer = @server.http_prefer
        minimal = prefer['return'] == 'minimal'

        data = @server.generate_multi_status(new_properties, minimal)
        response.body = data

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # WebDAV PROPPATCH
      #
      # This method is called to update properties on a Node. The request is an XML body with all the mutations.
      # In this XML body it is specified which properties should be set/updated and/or deleted
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_prop_patch(request, response)
        path = request.path

        begin
          prop_patch = @server.xml.expect('{DAV:}propertyupdate', request.body)
        rescue Tilia::Xml::ParseException => e
          raise Exception::BadRequest, e.message, nil, e
        end

        new_properties = prop_patch.properties

        result = @server.update_properties(path, new_properties)

        prefer = @server.http_prefer
        response.update_header('Vary', 'Brief,Prefer')

        if prefer['return'] == 'minimal'
          # If return-minimal is specified, we only have to check if the
          # request was succesful, and don't need to return the
          # multi-status.
          ok = true
          result.each do |_prop, code|
            ok = false if code.to_i > 299
          end

          if ok
            response.status = 204
            return false
          end
        end

        response.status = 207
        response.update_header('Content-Type', 'application/xml; charset=utf-8')

        # Reorganizing the result for generateMultiStatus
        multi_status = {}
        result.each do |property_name, code|
          if multi_status.key?(code)
            multi_status[code][property_name] = nil
          else
            multi_status[code] = { property_name => nil }
          end
        end
        multi_status['href'] = path

        response.body = @server.generate_multi_status([multi_status])

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # HTTP PUT method
      #
      # This HTTP method updates a file, or creates a new one.
      #
      # If a new resource was created, a 201 Created status code should be returned. If an existing resource is updated, it's a 204 No Content
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_put(request, response)
        body = request.body_as_stream
        path = request.path

        # Intercepting Content-Range
        if request.header('Content-Range')
          # An origin server that allows PUT on a given target resource MUST send
          # a 400 (Bad Request) response to a PUT request that contains a
          # Content-Range header field.
          #
          # Reference: http://tools.ietf.org/html/rfc7231#section-4.3.4
          fail Exception::BadRequest, 'Content-Range on PUT requests are forbidden.'
        end

        # Intercepting the Finder problem
        expected = request.header('X-Expected-Entity-Length').to_i
        if expected > 0
          # Many webservers will not cooperate well with Finder PUT requests,
          # because it uses 'Chunked' transfer encoding for the request body.
          #
          # The symptom of this problem is that Finder sends files to the
          # server, but they arrive as 0-length files in PHP.
          #
          # If we don't do anything, the user might think they are uploading
          # files successfully, but they end up empty on the server. Instead,
          # we throw back an error if we detect this.
          #
          # The reason Finder uses Chunked, is because it thinks the files
          # might change as it's being uploaded, and therefore the
          # Content-Length can vary.
          #
          # Instead it sends the X-Expected-Entity-Length header with the size
          # of the file at the very start of the request. If this header is set,
          # but we don't get a request body we will fail the request to
          # protect the end-user.

          # Only reading first byte
          first_byte = body.read(1)
          unless first_byte
            fail Exception::Forbidden, 'This server is not compatible with OS/X finder. Consider using a different WebDAV client or webserver.'
          end

          # The body needs to stay intact, so we copy everything to a
          # temporary stream.

          new_body = StringIO.new
          new_body.write(first_byte)
          IO.copy_stream(body, new_body)
          new_body.rewind

          body = new_body
        end

        if @server.tree.node_exists(path)
          node = @server.tree.node_for_path(path)

          # If the node is a collection, we'll deny it
          unless node.is_a?(IFile)
            fail Exception::Conflict, 'PUT is not allowed on non-files.'
          end

          etag = Box.new
          return false unless @server.update_file(path, body, etag)
          etag = etag.value

          response.update_header('Content-Length', '0')
          response.update_header('ETag', etag) if etag
          response.status = 204
        else
          # If we got here, the resource didn't exist yet.
          etag = Box.new
          unless @server.create_file(path, body, etag)
            # For one reason or another the file was not created.
            return false
          end
          etag = etag.value

          response.update_header('Content-Length', '0')
          response.update_header('ETag', etag) if etag
          response.status = 201
        end

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # WebDAV MKCOL
      #
      # The MKCOL method is used to create a new collection (directory) on the server
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_mkcol(request, response)
        request_body = request.body_as_string
        path = request.path

        if !request_body.blank?
          content_type = request.header('Content-Type') || ''
          if content_type.index('application/xml') != 0 && content_type.index('text/xml') != 0
            # We must throw 415 for unsupported mkcol bodies
            fail Exception::UnsupportedMediaType, 'The request body for the MKCOL request must have an xml Content-Type'
          end

          begin
            mkcol = @server.xml.expect('{DAV:}mkcol', request_body)
          rescue Tilia::Xml::ParseException => e
            raise Exception::BadRequest, e.message
          end

          properties = mkcol.properties

          unless properties.key?('{DAV:}resourcetype')
            fail Exception::BadRequest, 'The mkcol request must include a {DAV:}resourcetype property'
          end

          resource_type = properties['{DAV:}resourcetype'].value
          properties.delete('{DAV:}resourcetype')
        else
          properties = {}
          resource_type = ['{DAV:}collection']
        end

        mkcol = MkCol.new(resource_type, properties)

        result = @server.create_collection(path, mkcol)

        if result.is_a?(Hash)
          response.status = 207
          response.update_header('Content-Type', 'application/xml; charset=utf-8')

          response.body = @server.generate_multi_status([result])
        else
          response.update_header('Content-Length', '0')
          response.status = 201
        end

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # WebDAV HTTP MOVE method
      #
      # This method moves one uri to a different uri. A lot of the actual request processing is done in getCopyMoveInfo
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_move(request, response)
        path = request.path

        move_info = @server.copy_and_move_info(request)

        if move_info['destinationExists']
          return false unless @server.emit('beforeUnbind', [move_info['destination']])
        end

        return false unless @server.emit('beforeUnbind', [path])
        return false unless @server.emit('beforeBind', [move_info['destination']])
        return false unless @server.emit('beforeMove', [path, move_info['destination']])

        if move_info['destinationExists']
          @server.tree.delete(move_info['destination'])
          @server.emit('afterUnbind', [move_info['destination']])
        end

        @server.tree.move(path, move_info['destination'])

        # Its important afterMove is called before afterUnbind, because it
        # allows systems to transfer data from one path to another.
        # PropertyStorage uses this. If afterUnbind was first, it would clean
        # up all the properties before it has a chance.
        @server.emit('afterMove', [path, move_info['destination']])
        @server.emit('afterUnbind', [path])
        @server.emit('afterBind', [move_info['destination']])

        # If a resource was overwritten we should send a 204, otherwise a 201
        response.update_header('Content-Length', '0')
        response.status = move_info['destinationExists'] ? 204 : 201

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # WebDAV HTTP COPY method
      #
      # This method copies one uri to a different uri, and works much like the MOVE request
      # A lot of the actual request processing is done in getCopyMoveInfo
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_copy(request, response)
        path = request.path

        copy_info = @server.copy_and_move_info(request)

        if copy_info['destinationExists']
          return false unless @server.emit('beforeUnbind', [copy_info['destination']])
          @server.tree.delete(copy_info['destination'])
        end

        return false unless @server.emit('beforeBind', [copy_info['destination']])

        @server.tree.copy(path, copy_info['destination'])

        @server.emit('afterBind', [copy_info['destination']])

        # If a resource was overwritten we should send a 204, otherwise a 201
        response.update_header('Content-Length', '0')
        response.status = copy_info['destinationExists'] ? 204 : 201

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # HTTP REPORT method implementation
      #
      # Although the REPORT method is not part of the standard WebDAV spec (it's from rfc3253)
      # It's used in a lot of extensions, so it made sense to implement it into the core.
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_report(request, _response)
        path = request.path

        root_element_name = Box.new('')
        result = @server.xml.parse(request.body, request.url, root_element_name)
        root_element_name = root_element_name.value

        if @server.emit('report', [root_element_name, result, path])
          # If emit returned true, it means the report was not supported
          fail Exception::ReportNotSupported
        end

        # Sending back false will interupt the event chain and tell the server
        # we've handled this method.
        false
      end

      # This method is called during property updates.
      #
      # Here we check if a user attempted to update a protected property and
      # ensure that the process fails if this is the case.
      #
      # @param string path
      # @param PropPatch prop_patch
      # @return void
      def prop_patch_protected_property_check(_path, prop_patch)
        # Comparing the mutation list to the list of propetected properties.
        mutations = prop_patch.mutations

        protected_props = @server.protected_properties & mutations.keys

        prop_patch.update_result_code(protected_props, 403) if protected_props.any?
      end

      # This method is called during property updates.
      #
      # Here we check if a node implements IProperties and let the node handle
      # updating of (some) properties.
      #
      # @param string path
      # @param PropPatch prop_patch
      # @return void
      def prop_patch_node_update(path, prop_patch)
        # This should trigger a 404 if the node doesn't exist.
        node = @server.tree.node_for_path(path)

        node.prop_patch(prop_patch) if node.is_a?(IProperties)
      end

      # This method is called when properties are retrieved.
      #
      # Here we add all the default properties.
      #
      # @param PropFind prop_find
      # @param INode node
      # @return void
      def prop_find(prop_find, node)
        prop_find.handle(
          '{DAV:}getlastmodified',
          lambda do
            lm = node.last_modified
            return Xml::Property::GetLastModified.new(lm) if lm
            return nil
          end
        )

        if node.is_a?(IFile)
          prop_find.handle('{DAV:}getcontentlength', node.method(:size))
          prop_find.handle('{DAV:}getetag', node.method(:etag))
          prop_find.handle('{DAV:}getcontenttype', node.method(:content_type))
        end

        if node.is_a?(IQuota)
          quota_info = nil
          prop_find.handle(
            '{DAV:}quota-used-bytes',
            lambda do
              quota_info = node.quota_info
              return quota_info[0]
            end
          )
          prop_find.handle(
            '{DAV:}quota-available-bytes',
            lambda do
              quota_info = node.quota_info unless quota_info
              return quota_info[1]
            end
          )
        end

        prop_find.handle(
          '{DAV:}supported-report-set',
          lambda do
            reports = []
            @server.plugins.each do |_, plugin|
              reports += plugin.supported_report_set(prop_find.path)
            end
            return Xml::Property::SupportedReportSet.new(reports)
          end
        )
        prop_find.handle(
          '{DAV:}resourcetype',
          -> { return Xml::Property::ResourceType.new(@server.resource_type_for_node(node)) }
        )
        prop_find.handle(
          '{DAV:}supported-method-set',
          lambda do
            return Xml::Property::SupportedMethodSet.new(
              @server.allowed_methods(prop_find.path)
            )
          end
        )
      end

      # Fetches properties for a node.
      #
      # This event is called a bit later, so plugins have a chance first to
      # populate the result.
      #
      # @param PropFind prop_find
      # @param INode node
      # @return void
      def prop_find_node(prop_find, node)
        if node.is_a?(IProperties)
          property_names = prop_find.load_404_properties
          if property_names.any?
            node_properties = node.properties(property_names)
            property_names.each do |property_name|
              if node_properties.include?(property_name)
                prop_find.set(property_name, node_properties[property_name], 200)
              end
            end
          end
        end
      end

      # This method is called when properties are retrieved.
      #
      # This specific handler is called very late in the process, because we
      # want other systems to first have a chance to handle the properties.
      #
      # @param PropFind prop_find
      # @param INode node
      # @return void
      def prop_find_late(prop_find, _node)
        prop_find.handle(
          '{http://calendarserver.org/ns/}getctag',
          lambda do
            # If we already have a sync-token from the current propFind
            # request, we can re-use that.
            val = prop_find.get('{http://sabredav.org/ns}sync-token')
            return val if val

            val = prop_find.get('{DAV:}sync-token')
            return val if val && val.scalar?
            if val && val.is_a?(Xml::Property::Href)
              length = Sync::Plugin::SYNCTOKEN_PREFIX.length
              return val.href[length..-1]
            end

            # If we got here, the earlier two properties may simply not have
            # been part of the earlier request. We're going to fetch them.
            result = @server.properties(
              prop_find.path,
              [
                '{http://sabredav.org/ns}sync-token',
                '{DAV:}sync-token'
              ]
            )

            if result.key?('{http://sabredav.org/ns}sync-token')
              return result['{http://sabredav.org/ns}sync-token']
            end
            if result.key?('{DAV:}sync-token')
              val = result['{DAV:}sync-token']
              if val.scalar?
                return val
              elsif val.is_a?(Xml::Property::Href)
                length = Sync::Plugin::SYNCTOKEN_PREFIX.length
                return val.href[length..-1]
              end
            end
          end
        )
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
          'description' => 'The Core plugin provides a lot of the basic functionality required by WebDAV, such as a default implementation for all HTTP and WebDAV methods.',
          'link'        => nil
        }
      end
    end
  end
end
