module Tilia
  module Dav
    module PartialUpdate
      class FileMock
        include IPatchSupport

        def initialize
          @data = ''
        end

        def put(str)
          if str.respond_to?(:read)
            @data = str.read
          else
            @data = str
          end
        end

        # Updates the file based on a range specification.
        #
        # The first argument is the data, which is either a readable stream
        # resource or a string.
        #
        # The second argument is the type of update we're doing.
        # This is either:
        # * 1. append
        # * 2. update based on a start byte
        # * 3. update based on an end byte
        #
        # The third argument is the start or end byte.
        #
        # After a successful put operation, you may choose to return an ETag. The
        # etag must always be surrounded by double-quotes. These quotes must
        # appear in the actual string you're returning.
        #
        # Clients may use the ETag from a PUT request to later on make sure that
        # when they update the file, the contents haven't changed in the mean
        # time.
        #
        # @param resource|string data
        # @param int range_type
        # @param int offset
        # @return string|null
        def patch(data, range_type, offset = 0)
          data = data.read if data.respond_to?(:read)

          case range_type
          when 1
            @data += data
          when 2, 3
            # Turn the offset into an offset-offset.
            offset = @data.length - offset if range_type == 3
            @data[offset, data.length] = data
          end
          nil
        end

        def get
          @data
        end

        def content_type
          'text/plain'
        end

        def size
          @data.length
        end

        def etag
          "\"#{@data}\""
        end

        def delete
          fail Exception::MethodNotAllowed
        end

        def name=(_name)
          fail Exception::MethodNotAllowed
        end

        def name
          'partial'
        end

        def last_modified
          nil
        end
      end
    end
  end
end
