module Tilia
  module Dav
    # Node class
    #
    # This is a helper class, that should aid in getting nodes setup.
    class Node
      include INode

      # Returns the last modification time as a unix timestamp.
      #
      # If the information is not available, return null.
      #
      # @return int
      def last_modified
        nil
      end

      # Deletes the current node
      #
      # @throws Sabre\DAV\Exception\Forbidden
      # @return void
      def delete
        fail Exception::Forbidden, 'Permission denied to delete node'
      end

      # Renames the node
      #
      # @throws Sabre\DAV\Exception\Forbidden
      # @param string name The new name
      # @return void
      def name=(_name)
        fail Exception::Forbidden, 'Permission denied to rename file'
      end
    end
  end
end
