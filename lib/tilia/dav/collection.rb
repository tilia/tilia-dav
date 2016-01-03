module Tilia
  module Dav
    # Collection class
    #
    # This is a helper class, that should aid in getting collections classes setup.
    # Most of its methods are implemented, and throw permission denied exceptions
    class Collection < Node
      include ICollection

      # Returns a child object, by its name.
      #
      # This method makes use of the children method to grab all the child
      # nodes, and compares the name.
      # Generally its wise to override this, as this can usually be optimized
      #
      # This method must throw Sabre\DAV\Exception\NotFound if the node does not
      # exist.
      #
      # @param string name
      # @throws Exception\NotFound
      # @return INode
      def child(name)
        children.each do |child|
          return child if child.name == name
        end

        fail Exception::NotFound, "File not found: #{name}"
      end

      # Checks is a child-node exists.
      #
      # It is generally a good idea to try and override this. Usually it can be optimized.
      #
      # @param string name
      # @return bool
      def child_exists(name)
        child(name)
        true
      rescue Exception::NotFound => e
        false
      end

      # Creates a new file in the directory
      #
      # Data will either be supplied as a stream resource, or in certain cases
      # as a string. Keep in mind that you may have to support either.
      #
      # After succesful creation of the file, you may choose to return the ETag
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
      def create_file(name, _data = nil)
        fail Exception::Forbidden, "Permission denied to create file (filename #{name})"
      end

      # Creates a new subdirectory
      #
      # @param string name
      # @throws Exception\Forbidden
      # @return void
      def create_directory(_name)
        fail Exception::Forbidden, 'Permission denied to create directory'
      end
    end
  end
end
