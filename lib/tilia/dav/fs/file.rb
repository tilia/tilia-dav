require 'digest'

module Tilia
  module Dav
    module Fs
      # File class
      class File < Node
        include IFile

        # Updates the data
        #
        # @param resource|string data
        # @return void
        def put(data)
          ::File.open(@path, 'w') do |file|
            if data.is_a?(String)
              file.write(data)
            else
              IO.copy_stream(data, file)
            end
          end
        end

        # Returns the data
        #
        # @return resource
        def get
          ::File.open(@path, 'r')
        end

        # Delete the current file
        #
        # @return void
        def delete
          ::File.unlink(@path)
        end

        # Returns the size of the node, in bytes
        #
        # @return int
        def size
          ::File.size(@path)
        end

        # Returns the ETag for a file
        #
        # An ETag is a unique identifier representing the current version of the file. If the file changes, the ETag MUST change.
        # The ETag is an arbitrary string, but MUST be surrounded by double-quotes.
        #
        # Return null if the ETag can not effectively be determined
        #
        # @return mixed
        def etag
          stat = ::File.stat(@path)
          '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'
        end

        # Returns the mime-type for a file
        #
        # If null is returned, we'll assume application/octet-stream
        #
        # @return mixed
        def content_type
          nil
        end
      end
    end
  end
end
