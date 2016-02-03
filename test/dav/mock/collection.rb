module Tilia
  module Dav
    module Mock
      # Mock Collection.
      #
      # This collection quickly allows you to create trees of nodes.
      # Children are specified as an array.
      #
      # Every key a filename, every array value is either:
      #   * an array, for a sub-collection
      #   * a string, for a file
      #   * An instance of \Sabre\DAV\INode.
      class Collection < Dav::Collection
        protected

        attr_accessor :name
        attr_accessor :children
        attr_accessor :parent

        public

        # Creates the object
        #
        # @param string name
        # @param array children
        # @return void
        def initialize(name, children = {}, parent = nil)
          @name = name
          @children = []
          children.each do |key, value|
            if value.is_a?(String)
              @children << File.new(key, value, self)
            elsif value.is_a?(Hash)
              @children << self.class.new(key, value, self)
            elsif value.is_a?(Dav::INode)
              @children << value
            else
              fail ArgumentError, 'Unknown value passed in children'
            end
          end
          @parent = parent
        end

        # Returns the name of the node.
        #
        # This is used to generate the url.
        #
        # @return string
        attr_reader :name

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
          data = data.read unless data.is_a?(String)

          @children << File.new(name, data, self)
          "\"#{Digest::MD5.hexdigest(data)}\""
        end

        # Creates a new subdirectory
        #
        # @param string name
        # @return void
        def create_directory(name)
          @children << self.class.new(name)
        end

        # Returns an array with all the child nodes
        #
        # @return \Sabre\DAV\INode[]
        attr_reader :children

        # Removes a childnode from this node.
        #
        # @param string name
        # @return void
        def delete_child(name)
          @children.delete_if do |value|
            value.name == name
          end
        end

        # Deletes this collection and all its children,.
        #
        # @return void
        def delete
          @children = []
          @parent.delete_child(name)
        end
      end
    end
  end
end
