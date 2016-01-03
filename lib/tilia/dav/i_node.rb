module Tilia
  module Dav
    # The INode interface is the base interface, and the parent class of both ICollection and IFile
    module INode
      # Deleted the current node
      #
      # @return void
      def delete
      end

      # Returns the name of the node.
      #
      # This is used to generate the url.
      #
      # @return string
      def name
      end

      # Renames the node
      #
      # @param string name The new name
      # @return void
      def name=(name)
      end

      # Returns the last modification time, as a unix timestamp
      #
      # @return int
      def last_modified
      end
    end
  end
end
