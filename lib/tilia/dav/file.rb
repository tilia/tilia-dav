module Tilia
  module Dav
    # File class
    #
    # This is a helper class, that should aid in getting file classes setup.
    # Most of its methods are implemented, and throw permission denied exceptions
    class File < Node
      include IFile

      # Updates the data
      #
      # data is a readable stream resource.
      #
      # @param resource data
      # @return void
      def put(_data)
        fail Exception::Forbidden, 'Permission denied to change data'
      end

      # Returns the data
      #
      # This method may either return a string or a readable stream resource
      #
      # @return mixed
      def get
        fail Exception::Forbidden, 'Permission denied to read this file'
      end

      # Returns the size of the file, in bytes.
      #
      # @return int
      def size
        0
      end

      # Returns the ETag for a file
      #
      # An ETag is a unique identifier representing the current version of the file. If the file changes, the ETag MUST change.
      # The ETag is an arbitrary string, but MUST be surrounded by double-quotes.
      #
      # Return null if the ETag can not effectively be determined
      #
      # @return string|null
      def etag
        nil
      end

      # Returns the mime-type for a file
      #
      # If null is returned, we'll assume application/octet-stream
      #
      # @return string|null
      def content_type
        nil
      end
    end
  end
end
