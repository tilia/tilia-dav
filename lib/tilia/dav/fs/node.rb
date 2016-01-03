module Tilia
  module Dav
    module Fs
      # Base node-class
      #
      # The node class implements the method used by both the File and the Directory classes
      class Node
        include INode

        protected

        # The path to the current node
        #
        # @var string
        attr_accessor :path

        public

        # Sets up the node, expects a full path name
        #
        # @param string path
        def initialize(path)
          @path = path
        end

        # Returns the name of the node
        #
        # @return string
        def name
          (_, name) = Http::UrlUtil.split_path(@path)
          name
        end

        # Renames the node
        #
        # @param string name The new name
        # @return void
        def name=(name)
          parent_path = Http::UrlUtil.split_path(@path).first
          new_name = Http::UrlUtil.split_path(name).second

          new_path = parent_path + '/' + new_name
          ::File.rename(@path, new_path)

          @path = new_path
        end

        # Returns the last modification time, as a unix timestamp
        #
        # @return int
        def last_modified
          ::File.mtime(@path)
        end
      end
    end
  end
end
