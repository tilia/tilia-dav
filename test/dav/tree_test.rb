require 'test_helper'

module Tilia
  module Dav
    class TreeTest < Minitest::Test
      def setup
        @tree = Tilia::Dav::TreeMock.new
      end

      def test_node_exists
        assert(@tree.node_exists('hi'))
        refute(@tree.node_exists('hello'))
      end

      def test_copy
        @tree.copy('hi', 'hi2')

        assert_has_key('hi2', @tree.node_for_path('').new_directories)
        assert_equal('foobar', @tree.node_for_path('hi/file').get)
        assert_equal({ 'test1' => 'value' }, @tree.node_for_path('hi/file').properties([]))
      end

      def test_move
        @tree.move('hi', 'hi2')

        assert_equal('hi2', @tree.node_for_path('hi').name)
        assert(@tree.node_for_path('hi').is_renamed)
      end

      def test_deep_move
        @tree.move('hi/sub', 'hi2')

        assert_has_key('hi2', @tree.node_for_path('').new_directories)
        assert(@tree.node_for_path('hi/sub').is_deleted)
      end

      def test_delete
        @tree.delete('hi')
        assert(@tree.node_for_path('hi').is_deleted)
      end

      def test_get_children
        children = @tree.children('')
        assert_equal(2, children.size)
        assert_equal('hi', children[0].name)
      end

      def test_get_multiple_nodes
        result = @tree.multiple_nodes(['hi/sub', 'hi/file'])
        assert_has_key('hi/sub', result)
        assert_has_key('hi/file', result)

        assert_equal('sub', result['hi/sub'].name)
        assert_equal('file', result['hi/file'].name)
      end

      def test_get_multiple_nodes2
        result = @tree.multiple_nodes(['multi/1', 'multi/2'])
        assert_has_key('multi/1', result)
        assert_has_key('multi/2', result)
      end
    end

    class TreeMock < Tree
      def initialize
        @nodes = []

        file = TreeFileTester.new('file')
        file.properties = { 'test1' => 'value' }
        file.data = 'foobar'

        super(
          TreeDirectoryTester.new(
            'root', [
              TreeDirectoryTester.new(
                'hi',
                [
                  TreeDirectoryTester.new('sub'),
                  file
                ]
              ),
              TreeMultiGetTester.new(
                'multi',
                [
                  TreeFileTester.new('1'),
                  TreeFileTester.new('2'),
                  TreeFileTester.new('3')
                ]
              )
            ]
          )
        )
      end
    end

    class TreeDirectoryTester < SimpleCollection
      attr_accessor :new_directories
      attr_accessor :new_files
      attr_accessor :is_deleted
      attr_accessor :is_renamed

      def initialize(*args)
        @new_directories = {}
        @new_files = {}
        @is_deleted = false
        @is_renamed = false
        super(*args)
      end

      def create_directory(name)
        @new_directories[name] = true
      end

      def create_file(name, data = nil)
        @new_files[name] = data
      end

      def child(name)
        return TreeDirectoryTester.new(name) if @new_directories.key?(name)
        return TreeFileTester.new(name, @new_files[name]) if @new_files[name]
        super(name)
      end

      def child_exists(name)
        !!child(name)
      end

      def delete
        @is_deleted = true
      end

      def name=(name)
        @is_renamed = true
        @name = name
      end
    end

    class TreeFileTester < File
      include IProperties

      attr_accessor :name
      attr_accessor :data
      attr_accessor :properties

      def initialize(name, data = nil)
        @name = name
        data = 'bla' if data.nil?
        @data = data
      end

      attr_reader :name

      def get
        @data
      end

      def properties(_properties)
        @properties
      end

      # Updates properties on this node.
      #
      # This method received a PropPatch object, which contains all the
      # information about the update.
      #
      # To update specific properties, call the 'handle' method on this object.
      # Read the PropPatch documentation for more information.
      #
      # @param array mutations
      # @return bool|array
      def prop_patch(prop_patch)
        @properties = prop_patch.mutations
        prop_patch.remaining_result_code = 200
      end
    end

    class TreeMultiGetTester < TreeDirectoryTester
      include IMultiGet

      # This method receives a list of paths in it's first argument.
      # It must return an array with Node objects.
      #
      # If any children are not found, you do not have to return them.
      #
      # @return array
      def multiple_children(paths)
        result = []
        paths.each do |path|
          begin
            child = child(path)
            result << child
          rescue Exception::NotFound => e
            # Do nothing
          end
        end

        result
      end
    end
  end
end
