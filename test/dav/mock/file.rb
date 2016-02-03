module Tilia
  module Dav
    module Mock
      # Mock File
      #
      # See the Collection in this directory for more details.
      class File < Dav::File
        protected

        attr_accessor :name
        attr_accessor :contents
        attr_accessor :parent

        public

        # Creates the object
        #
        # @param string name
        # @param array children
        # @return void
        def initialize(name, contents, parent = nil)
          @name = name
          put(contents)
          @parent = parent
        end

        # Returns the name of the node.
        #
        # This is used to generate the url.
        #
        # @return string
        attr_reader :name

        # Changes the name of the node.
        #
        # @return void
        attr_writer :name

        # Updates the data
        #
        # The data argument is a readable stream resource.
        #
        # After a succesful put operation, you may choose to return an ETag. The
        # etag must always be surrounded by double-quotes. These quotes must
        # appear in the actual string you're returning.
        #
        # Clients may use the ETag from a PUT request to later on make sure that
        # when they update the file, the contents haven't changed in the mean
        # time.
        #
        # If you don't plan to store the file byte-by-byte, and you return a
        # different object on a subsequent GET you are strongly recommended to not
        # return an ETag, and just return null.
        #
        # @param resource data
        # @return string|null
        def put(data)
          data = data.read unless data.is_a?(String)

          @contents = data
          "\"#{Digest::MD5.hexdigest(data)}\""
        end

        # Returns the data
        #
        # This method may either return a string or a readable stream resource
        #
        # @return mixed
        def get
          @contents
        end

        # Returns the ETag for a file
        #
        # An ETag is a unique identifier representing the current version of the file. If the file changes, the ETag MUST change.
        #
        # Return null if the ETag can not effectively be determined
        #
        # @return void
        def etag
          "\"#{Digest::MD5.hexdigest(@contents)}\""
        end

        # Returns the size of the node, in bytes
        #
        # @return int
        def size
          @contents.bytesize
        end

        # Delete the node
        #
        # @return void
        def delete
          @parent.delete_child(@name)
        end
      end
    end
  end
end
