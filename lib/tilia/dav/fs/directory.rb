module Tilia
  module Dav
    module Fs
      # Directory class
      class Directory < Node
        include ICollection
        include IQuota

        # Creates a new file in the directory
        #
        # Data will either be supplied as a stream resource, or in certain cases
        # as a string. Keep in mind that you may have to support either.
        #
        # After successful creation of the file, you may choose to return the ETag
        # of the new file here.
        #
        # The returned ETag must be surrounded by double-quotes (The quotes should
        # be part of the actual string).
        #
        # If you cannot accurately determine the ETag, you should not return it.
        # If you don't store the file exactly as-is (you're transforming it
        # somehow) you should also not return an ETag.
        #
        # This means that if a subsequent GET to this new file does not exactly
        # return the same contents of what was submitted here, you are strongly
        # recommended to omit the ETag.
        #
        # @param string name Name of the file
        # @param resource|string data Initial payload
        # @return null|string
        def create_file(name, data = nil)
          new_path = @path + '/' + name
          ::File.open(new_path, 'w') do |file|
            if data.is_a?(String)
              file.write(data)
            else
              IO.copy_stream(data, file)
            end
          end

          nil
        end

        # Creates a new subdirectory
        #
        # @param string name
        # @return void
        def create_directory(name)
          new_path = @path + '/' + name
          ::Dir.mkdir(new_path)
        end

        # Returns a specific child node, referenced by its name
        #
        # This method must throw DAV\Exception\NotFound if the node does not
        # exist.
        #
        # @param string name
        # @throws DAV\Exception\NotFound
        # @return DAV\INode
        def child(name)
          path = @path + '/' + name

          unless ::File.exist?(path)
            fail Exception::NotFound, "File with name #{path} could not be located"
          end

          if ::File.directory?(path)
            Directory.new(path)
          else
            File.new(path)
          end
        end

        # Returns an array with all the child nodes
        #
        # @return DAV\INode[]
        def children
          nodes = []
          Dir.foreach(@path) do |entry|
            next if entry == '.' || entry == '..'

            nodes << child(entry)
          end

          nodes
        end

        # Checks if a child exists.
        #
        # @param string name
        # @return bool
        def child_exists(name)
          new_path = @path + '/' + name
          ::File.exist?(new_path)
        end

        # Deletes all files in this directory, and then itself
        #
        # @return void
        def delete
          children.each(&:delete)
          ::Dir.rmdir(@path)
        end

        # Returns available diskspace information
        #
        # @return array
        def quota_info
          stat = Sys::Filesystem.stat(@path)
          [
            stat.blocks_available,
            stat.blocks_free
          ]
        end
      end
    end
  end
end
