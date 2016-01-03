module Tilia
  module Dav
    module PartialUpdate
      # Partial update plugin (Patch method)
      #
      # This plugin provides a way to modify only part of a target resource
      # It may bu used to update a file chunk, upload big a file into smaller
      # chunks or resume an upload.
      #
      # patch_plugin = new \Sabre\DAV\PartialUpdate\Plugin
      # server.add_plugin(patch_plugin)
      class Plugin < ServerPlugin
        RANGE_APPEND = 1
        RANGE_START = 2
        RANGE_END = 3

        # Reference to server
        #
        # @var Sabre\DAV\Server
        # RUBY: attr_accessor :server

        # Initializes the plugin
        #
        # This method is automatically called by the Server class after addPlugin.
        #
        # @param DAV\Server server
        # @return void
        def setup(server)
          @server = server
          server.on('method:PATCH', method(:http_patch))
        end

        # Returns a plugin name.
        #
        # Using this name other plugins will be able to access other plugins
        # using DAV\Server::getPlugin
        #
        # @return string
        def plugin_name
          'partialupdate'
        end

        # Use this method to tell the server this plugin defines additional
        # HTTP methods.
        #
        # This method is passed a uri. It should only return HTTP methods that are
        # available for the specified uri.
        #
        # We claim to support PATCH method (partirl update) if and only if
        #     - the node exist
        #     - the node implements our partial update interface
        #
        # @param string uri
        # @return array
        def http_methods(uri)
          tree = @server.tree

          if tree.node_exists(uri)
            node = tree.node_for_path(uri)
            return ['PATCH'] if node.is_a?(IPatchSupport)
          end
          []
        end

        # Returns a list of features for the HTTP OPTIONS Dav: header.
        #
        # @return array
        def features
          ['sabredav-partialupdate']
        end

        # Patch an uri
        #
        # The WebDAV patch request can be used to modify only a part of an
        # existing resource. If the resource does not exist yet and the first
        # offset is not 0, the request fails
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return void
        def http_patch(request, response)
          path = request.path

          # Get the node. Will throw a 404 if not found
          node = @server.tree.node_for_path(path)
          unless node.is_a?(IPatchSupport)
            fail Exception::MethodNotAllowed, 'The target resource does not support the PATCH method.'
          end

          range = http_update_range(request)

          unless range
            fail Exception::BadRequest, 'No valid "X-Update-Range" found in the headers'
          end

          content_type = request.header('Content-Type').to_s.downcase

          unless content_type == 'application/x-sabredav-partialupdate'
            fail Exception::UnsupportedMediaType, "Unknown Content-Type header \"#{content_type}\""
          end

          len = @server.http_request.header('Content-Length').to_i
          if len == 0
            fail Exception::LengthRequired, 'A Content-Length header is required'
          end

          case range[0]
          when RANGE_START
            # Calculate the end-range if it doesn't exist.
            if range[2].blank?
              range[2] = range[1] + len - 1
            else
              if range[2] < range[1]
                fail Exception::RequestedRangeNotSatisfiable, "The end offset (#{range[2]}) is lower than the start offset (#{range[1]})"
              end
              if range[2] - range[1] + 1 != len
                fail Exception::RequestedRangeNotSatisfiable, "Actual data length (#{len}) is not consistent with begin (#{range[1]}) and end (#{range[2]}) offsets"
              end
            end
          end

          unless @server.emit('beforeWriteContent', [path, node, nil, nil])
            return nil
          end

          body = @server.http_request.body

          etag = node.patch(body, range[0], range[1])

          @server.emit('afterWriteContent', [path, node])

          response.update_header('Content-Length', '0')
          response.update_header('ETag', etag) if etag

          response.status = 204

          # Breaks the event chain
          false
        end

        # Returns the HTTP custom range update header
        #
        # This method returns null if there is no well-formed HTTP range request
        # header. It returns array(1) if it was an append request, array(2,
        # start, end) if it's a start and end range, lastly it's array(3,
        # endoffset) if the offset was negative, and should be calculated from
        # the end of the file.
        #
        # Examples:
        #
        # null - invalid
        # [1] - append
        # [2,10,15] - update bytes 10, 11, 12, 13, 14, 15
        # [2,10,null] - update bytes 10 until the end of the patch body
        # [3,-5] - update from 5 bytes from the end of the file.
        #
        # @param RequestInterface request
        # @return array|null
        def http_update_range(request)
          range = request.header('X-Update-Range')
          return nil unless range

          # Matching "Range: bytes=1234-5678: both numbers are optional

          matches = /^(append)|(?:bytes=([0-9]+)-([0-9]*))|(?:bytes=(-[0-9]+))$/i.match(range)
          return nil unless matches

          if matches[1] == 'append'
            return [RANGE_APPEND]
          elsif matches[2].to_s.size > 0
            return [RANGE_START, matches[2].to_i, matches[3].blank? ? nil : matches[3].to_i]
          else
            return [RANGE_END, matches[4].to_i]
          end
        end
      end
    end
  end
end
