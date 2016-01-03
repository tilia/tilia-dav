module Tilia
  module Dav
    module FsExt
      # File class
      class File < Fs::Node
        include PartialUpdate::IPatchSupport

        # Updates the data
        #
        # Data is a readable stream resource.
        #
        # @param resource|string data
        # @return string
        def put(data)
          ::File.open(@path, 'w') do |file|
            if data.is_a?(String)
              file.write(data.to_s)
            else
              ::File.copy_stream(data, file)
            end
          end
          etag
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
        # ETAG must always be surrounded by double-quotes. These quotes must
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
        def patch(data, range_type, offset = nil)
          case range_type
          when 1
            f = ::File.open(@path, 'a')
          when 2
            f = ::File.open(@path, 'r+') # TODO: php 'c' vs. ruby 'w'?
            f.seek(offset)
          when 3
            f = ::File.open(@path, 'r+')
            f.seek(offset, IO::SEEK_END)
          end

          if data.is_a?(String)
            f.write(data)
          else
            IO.copy_stream(data, f)
          end

          f.close

          etag
        end

        # Returns the data
        #
        # @return resource
        def get
          ::File.open(@path, 'r')
        end

        # Delete the current file
        #
        # @return bool
        def delete
          ::File.unlink(@path)
        end

        # Returns the ETag for a file
        #
        # An ETag is a unique identifier representing the current version of the file. If the file changes, the ETag MUST change.
        # The ETag is an arbitrary string, but MUST be surrounded by double-quotes.
        #
        # Return null if the ETag can not effectively be determined
        #
        # @return string|null
        def etag
          stat = ::File.stat(@path)
          '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'
        end

        # Returns the mime-type for a file
        #
        # If null is returned, we'll assume application/octet-stream
        #
        # @return string|null
        def content_type
          nil
        end

        # Returns the size of the file, in bytes
        #
        # @return int
        def size
          ::File.size(@path)
        end
      end
    end
  end
end
