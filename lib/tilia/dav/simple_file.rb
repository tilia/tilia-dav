require 'digest'
module Tilia
  module Dav
    # SimpleFile
    #
    # The 'SimpleFile' class is used to easily add read-only immutable files to
    # the directory structure. One usecase would be to add a 'readme.txt' to a
    # root of a webserver with some standard content.
    class SimpleFile < File
      # File contents
      #
      # @var string
      attr_accessor :contents

      # Name of this resource
      #
      # @var string
      attr_accessor :name

      # A mimetype, such as 'text/plain' or 'text/html'
      #
      # @var string
      attr_accessor :mime_type

      # Creates this node
      #
      # The name of the node must be passed, as well as the contents of the
      # file.
      #
      # @param string name
      # @param string contents
      # @param string|nil mime_type
      def initialize(name, contents, mime_type = nil)
        @name = name
        @contents = contents
        @mime_type = mime_type
      end

      # Returns the node name for this file.
      #
      # This name is used to construct the url.
      #
      # @return string
      attr_reader :name

      # Returns the data
      #
      # This method may either return a string or a readable stream resource
      #
      # @return mixed
      def get
        @contents
      end

      # Returns the size of the file, in bytes.
      #
      # @return int
      def size
        @contents.bytes.size
      end

      # Returns the ETag for a file
      #
      # An ETag is a unique identifier representing the current version of the file. If the file changes, the ETag MUST change.
      # The ETag is an arbitrary string, but MUST be surrounded by double-quotes.
      #
      # Return null if the ETag can not effectively be determined
      # @return string
      def etag
        '"' + Digest::SHA1.hexdigest(@contents) + '"'
      end

      # Returns the mime-type for a file
      #
      # If null is returned, we'll assume application/octet-stream
      # @return string
      def content_type
        @mime_type
      end
    end
  end
end
