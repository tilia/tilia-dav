module Tilia
  module Dav
    # The ICollection Interface
    #
    # This interface should be implemented by each class that represents a collection
    module ICollection
      include INode

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
      # @return nil|string
      def create_file(name, data = nil)
      end

      # Creates a new subdirectory
      #
      # @param string name
      # @return void
      def create_directory(name)
      end

      # Returns a specific child node, referenced by its name
      #
      # This method must throw Sabre\DAV\Exception\NotFound if the node does not
      # exist.
      #
      # @param string name
      # @return DAV\INode
      def child(name)
      end

      # Returns an array with all the child nodes
      #
      # @return DAV\INode[]
      def children
      end

      # Checks if a child-node with the specified name exists
      #
      # @param string name
      # @return bool
      def child_exists(name)
      end
    end
  end
end
