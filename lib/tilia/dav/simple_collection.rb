module Tilia
  module Dav
    # SimpleCollection
    #
    # The SimpleCollection is used to quickly setup static directory structures.
    # Just create the object with a proper name, and add children to use it.
    class SimpleCollection < Collection
      # List of childnodes
      #
      # @var INode[]
      attr_accessor :children

      # Name of this resource
      #
      # @var string
      attr_accessor :name

      # Creates this node
      #
      # The name of the node must be passed, child nodes can also be passed.
      # This nodes must be instances of INode
      #
      # @param string name
      # @param INode[] children
      def initialize(name, children = [])
        @name = name
        @children = {}
        children.each do |child|
          fail(Exception, 'Only instances of Sabre\DAV\INode are allowed to be passed in the children argument') unless child.is_a? INode
          add_child(child)
        end
      end

      # Adds a new childnode to this collection
      #
      # @param INode child
      # @return void
      def add_child(child)
        @children[child.name] = child
      end

      # Returns the name of the collection
      #
      # @return string
      attr_reader :name

      # Returns a child object, by its name.
      #
      # This method makes use of the getChildren method to grab all the child nodes, and compares the name.
      # Generally its wise to override this, as this can usually be optimized
      #
      # This method must throw Sabre\DAV\Exception\NotFound if the node does not
      # exist.
      #
      # @param string name
      # @throws Exception\NotFound
      # @return INode
      def child(name)
        return @children[name] if @children.key?(name)
        fail Exception::NotFound, "File not found: #{name} in '#{name}'"
      end

      # Returns a list of children for this collection
      #
      # @return INode[]
      def children
        @children.values
      end
    end
  end
end
