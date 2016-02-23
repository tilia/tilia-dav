require 'stringio'

module Tilia
  module Dav
    # The tree object is responsible for basic tree operations.
    #
    # It allows for fetching nodes by path, facilitates deleting, copying and
    # moving.
    class Tree
      # The root node
      #
      # @var ICollection
      attr_accessor :root_node

      # This is the node cache. Accessed nodes are stored here.
      # Arrays keys are path names, values are the actual nodes.
      #
      # @var array
      attr_accessor :cache

      # Creates the object
      #
      # This method expects the rootObject to be passed as a parameter
      #
      # @param ICollection root_node
      def initialize(root_node)
        self.root_node = root_node
        self.cache = {}
      end

      # Returns the INode object for the requested path
      #
      # @param string path
      # @return INode
      def node_for_path(path)
        path = path.gsub(%r{^/+|/+$}, '')
        return cache[path] if cache.key? path

        # Is it the root node?
        return root_node if path.size == 0

        # Attempting to fetch its parent
        (parent_name, base_name) = Tilia::Http::UrlUtil.split_path(path)

        # If there was no parent, we must simply ask it from the root node.
        if parent_name == ''
          node = root_node.child(base_name)
        else
          # Otherwise, we recursively grab the parent and ask him/her.
          parent = node_for_path(parent_name)

          unless parent.is_a?(ICollection)
            fail Exception::NotFound, "Could not find node at path: #{path}"
          end

          node = parent.child(base_name)
        end

        cache[path] = node
      end

      # This function allows you to check if a node exists.
      #
      # Implementors of this class should override this method to make
      # it cheaper.
      #
      # @param string path
      # @return bool
      def node_exists(path)
        # The root always exists
        return true if path == ''

        (parent, base) = Tilia::Http::UrlUtil.split_path(path)

        parent_node = node_for_path(parent)
        return false unless parent_node.is_a? ICollection
        parent_node.child_exists(base)
      rescue Exception::NotFound => e
        false
      end

      # Copies a file from path to another
      #
      # @param string source_path The source location
      # @param string destination_path The full destination path
      # @return void
      def copy(source_path, destination_path)
        source_node = node_for_path(source_path)

        # grab the dirname and basename components
        (destination_dir, destination_name) = Tilia::Http::UrlUtil.split_path(destination_path)

        destination_parent = node_for_path(destination_dir)
        copy_node(source_node, destination_parent, destination_name)

        mark_dirty(destination_dir)
      end

      # Moves a file from one location to another
      #
      # @param string source_path The path to the file which should be moved
      # @param string destination_path The full destination path, so not just the destination parent node
      # @return int
      def move(source_path, destination_path)
        (source_dir,) = Tilia::Http::UrlUtil.split_path(source_path)
        (destination_dir, destination_name) = Tilia::Http::UrlUtil.split_path(destination_path)

        if source_dir == destination_dir
          # If this is a 'local' rename, it means we can just trigger a rename.
          source_node = node_for_path(source_path)
          source_node.name = destination_name
        else
          new_parent_node = node_for_path(destination_dir)
          move_success = false
          if new_parent_node.is_a? IMoveTarget
            # The target collection may be able to handle the move
            source_node = node_for_path(source_path)
            move_success = new_parent_node.move_into(destination_name, source_path, source_node)
          end
          unless move_success
            copy(source_path, destination_path)
            node_for_path(source_path).delete
          end
        end
        mark_dirty(source_dir)
        mark_dirty(destination_dir)
      end

      # Deletes a node from the tree
      #
      # @param string path
      # @return void
      def delete(path)
        node = node_for_path(path)
        node.delete

        (parent,) = Tilia::Http::UrlUtil.split_path(path)
        mark_dirty(parent)
      end

      # Returns a list of childnodes for a given path.
      #
      # @param string path
      # @return array
      def children(path)
        node = node_for_path(path)
        children = node.children
        base_path = path.gsub(/^\/+|\/+$/, '')
        base_path += '/' unless base_path.blank?

        children.each do |child|
          cache[base_path + child.name] = child
        end

        children
      end

      # This method is called with every tree update
      #
      # Examples of tree updates are:
      #   * node deletions
      #   * node creations
      #   * copy
      #   * move
      #   * renaming nodes
      #
      # If Tree classes implement a form of caching, this will allow
      # them to make sure caches will be expired.
      #
      # If a path is passed, it is assumed that the entire subtree is dirty
      #
      # @param string path
      # @return void
      def mark_dirty(path)
        # We don't care enough about sub-paths
        # flushing the entire cache
        path = path.gsub(%r{^/+|/+$}, '') + '/'
        cache.each do |node_path, _node|
          if node_path == path || node_path.index(path + '/') == 0
            cache.delete node_path
          end
        end
      end

      # This method tells the tree system to pre-fetch and cache a list of
      # children of a single parent.
      #
      # There are a bunch of operations in the WebDAV stack that request many
      # children (based on uris), and sometimes fetching many at once can
      # optimize this.
      #
      # This method returns an array with the found nodes. It's keys are the
      # original paths. The result may be out of order.
      #
      # @param array paths List of nodes that must be fetched.
      # @return array
      def multiple_nodes(paths)
        # Finding common parents
        parents = {}
        paths.each do |path|
          (parent, node) = Tilia::Http::UrlUtil.split_path(path)
          unless parents.key? parent
            parents[parent] = [node]
          else
            parents[parent] << node
          end
        end

        result = {}

        parents.each do |parent, children|
          parent_node = node_for_path(parent)
          if parent_node.is_a?(IMultiGet)
            parent_node.multiple_children(children).each do |child_node|
              full_path = parent + '/' + child_node.name
              result[full_path] = child_node
              cache[full_path] = child_node
            end
          else
            children.each do |child|
              full_path = parent + '/' + child
              result[full_path] = node_for_path(full_path)
            end
          end
        end

        result
      end

      protected

      # copy_node
      #
      # @param INode source
      # @param ICollection destination_parent
      # @param string destination_name
      # @return void
      def copy_node(source, destination_parent, destination_name = nil)
        destination_name = source.name unless destination_name

        if source.is_a? IFile
          data = source.get

          # If the body was a string, we need to convert it to a stream
          if data.is_a? String
            stream = StringIO.new
            stream.write data
            stream.rewind
            data = stream
          end
          destination_parent.create_file(destination_name, data)
          destination = destination_parent.child(destination_name)
        elsif source.is_a? ICollection
          destination_parent.create_directory(destination_name)

          destination = destination_parent.child(destination_name)
          source.children.each do |child|
            copy_node(child, destination)
          end
        end

        if source.is_a?(IProperties) && destination.is_a?(IProperties)
          props = source.properties([])
          prop_patch = PropPatch.new(props)
          destination.prop_patch(prop_patch)
          prop_patch.commit
        end
      end
    end
  end
end
