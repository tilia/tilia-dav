require 'test_helper'

module Tilia
  module Dav
    class BasicNodeTest < Minitest::Test
      def test_put
        file = FileMock.new
        assert_raises(Exception::Forbidden) { file.put('hi') }
      end

      def test_get
        file = FileMock.new
        assert_raises(Exception::Forbidden) { file.get }
      end

      def test_get_size
        file = FileMock.new
        assert_equal(0, file.size)
      end

      def test_get_etag
        file = FileMock.new
        assert_nil(file.etag)
      end

      def test_get_content_type
        file = FileMock.new
        assert_nil(file.content_type)
      end

      def test_delete
        file = FileMock.new
        assert_raises(Exception::Forbidden) { file.delete }
      end

      def test_set_name
        file = FileMock.new
        assert_raises(Exception::Forbidden) { file.name = 'hi' }
      end

      def test_get_last_modified
        skip('Original test was faulty!')
        file = FileMock.new
        # checking if lastmod is within the range of a few seconds
        last_mod = file.last_modified
        assert_in_epsilon(Time.now.to_i, last_mod, 10)
      end

      def test_get_child
        dir = DirectoryMock.new
        file = dir.child('mockfile')
        assert_kind_of(FileMock, file)
      end

      def test_child_exists
        dir = DirectoryMock.new
        assert(dir.child_exists('mockfile'))
      end

      def test_child_exists_false
        dir = DirectoryMock.new
        refute(dir.child_exists('mockfile2'))
      end

      def test_get_child404
        dir = DirectoryMock.new
        assert_raises(Exception::NotFound) { dir.child('blabla') }
      end

      def test_create_file
        dir = DirectoryMock.new
        assert_raises(Exception::Forbidden) { dir.create_file('hello', 'data') }
      end

      def test_create_directory
        dir = DirectoryMock.new
        assert_raises(Exception::Forbidden) { dir.create_directory('hello') }
      end

      def test_simple_directory_construct
        dir = SimpleCollection.new('simpledir', [])
        assert_kind_of(SimpleCollection, dir)
      end

      def test_simple_directory_construct_child
        file = FileMock.new
        dir = SimpleCollection.new('simpledir', [file])
        file2 = dir.child('mockfile')

        assert_equal(file, file2)
      end

      def test_simple_directory_bad_param
        assert_raises(Exception) do
          SimpleCollection.new('simpledir', ['string shouldn\'t be here'])
        end
      end

      def test_simple_directory_add_child
        file = FileMock.new
        dir = SimpleCollection.new('simpledir')
        dir.add_child(file)
        file2 = dir.child('mockfile')

        assert_equal(file, file2)
      end

      def test_simple_directory_get_children
        file = FileMock.new
        dir = SimpleCollection.new('simpledir')
        dir.add_child(file)

        assert_equal([file], dir.children)
      end

      def test_simple_directory_get_name
        dir = SimpleCollection.new('simpledir')
        assert_equal('simpledir', dir.name)
      end

      def test_simple_directory_get_child404
        dir = SimpleCollection.new('simpledir')
        assert_raises(Exception::NotFound) { dir.child('blabla') }
      end
    end

    class DirectoryMock < Collection
      def name
        'mockdir'
      end

      def children
        [FileMock.new]
      end
    end

    class FileMock < File
      def name
        'mockfile'
      end
    end
  end
end
