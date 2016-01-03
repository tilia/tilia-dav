module Tilia
  module Dav
    module FsExt
      # Directory class
      class Directory < Fs::Node
        include Dav::ICollection
        include Dav::IQuota
        include Dav::IMoveTarget

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
          # We're not allowing dots
          fail Exception::Forbidden, 'Permission denied to . and ..' if name == '.' || name == '..'

          new_path = @path + '/' + name

          ::File.open(new_path, 'w') do |file|
            if data.is_a?(String)
              file.write(data)
            else
              IO.copy_stream(data, file)
            end
          end

          stat = ::File.stat(new_path)
          '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'
        end

        # Creates a new subdirectory
        #
        # @param string name
        # @return void
        def create_directory(name)
          # We're not allowing dots
          fail Exception::Forbidden, 'Permission denied to . and ..' if name == '.' || name == '..'

          new_path = @path + '/' + name
          ::Dir.mkdir(new_path)
        end

        # Returns a specific child node, referenced by its name
        #
        # This method must throw Sabre\DAV\Exception\NotFound if the node does not
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
          fail Exception::Forbidden, 'Permission denied to . and ..' if name == '.' || name == '..'

          if ::File.directory?(path)
            Directory.new(path)
          else
            File.new(path)
          end
        end

        # Checks if a child exists.
        #
        # @param string name
        # @return bool
        def child_exists(name)
          fail Exception::Forbidden, 'Permission denied to . and ..' if name == '.' || name == '..'

          path = @path + '/' + name
          ::File.exist?(path)
        end

        # Returns an array with all the child nodes
        #
        # @return DAV\INode[]
        def children
          nodes = []
          Dir.foreach(@path) do |entry|
            next if entry == '.' || entry == '..'
            next if entry == '.sabredav'

            nodes << child(entry)
          end

          nodes
        end

        # Deletes all files in this directory, and then itself
        #
        # @return bool
        def delete
          # Deleting all children
          children.each(&:delete)

          # Removing resource info, if its still around
          if ::File.exist?(@path + '/.sabredav')
            ::File.unlink(@path + '/.sabredav')
          end

          # Removing the directory itself
          ::Dir.rmdir(@path)

          true
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

        # Moves a node into this collection.
        #
        # It is up to the implementors to:
        #   1. Create the new resource.
        #   2. Remove the old resource.
        #   3. Transfer any properties or other data.
        #
        # Generally you should make very sure that your collection can easily move
        # the move.
        #
        # If you don't, just return false, which will trigger sabre/dav to handle
        # the move itself. If you return true from this function, the assumption
        # is that the move was successful.
        #
        # @param string target_name New local file/collection name.
        # @param string source_path Full path to source node
        # @param DAV\INode source_node Source node itself
        # @return bool
        def move_into(target_name, _source_path, source_node)
          # We only support FSExt\Directory or FSExt\File objects, so
          # anything else we want to quickly reject.
          if !source_node.is_a?(self.class) && !source_node.is_a?(File)
            return false
          end

          # PHP allows us to access protected properties from other objects, as
          # long as they are defined in a class that has a shared inheritence
          # with the current class.
          ::File.rename(source_node.path, @path + '/' + target_name)

          true
        end
      end
    end
  end
end
