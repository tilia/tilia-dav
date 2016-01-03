require 'test_helper'

module Tilia
  module Dav
    class ObjectTreeTest < Minitest::Test
      def setup
        @temp_dir = Dir.mktmpdir
        Dir.mkdir("#{@temp_dir}/subdir")
        ::File.open("#{@temp_dir}/file.txt", 'w') { |f| f.write('contents') }
        ::File.open("#{@temp_dir}/subdir/subfile.txt", 'w') { |f| f.write('subcontents') }
        root_node = FsExt::Directory.new(@temp_dir)
        @tree = Tree.new(root_node)
      end

      def teardown
        FileUtils.remove_entry @temp_dir
      end

      def test_get_root_node
        root = @tree.node_for_path('')
        assert_kind_of(FsExt::Directory, root)
      end

      def test_get_sub_dir
        root = @tree.node_for_path('subdir')
        assert_kind_of(FsExt::Directory, root)
      end

      def test_copy_file
        @tree.copy('file.txt', 'file2.txt')
        assert(::File.exist?("#{@temp_dir}/file2.txt"))
        assert_equal('contents', ::File.read("#{@temp_dir}/file2.txt"))
      end

      def test_copy_directory
        @tree.copy('subdir', 'subdir2')
        assert(::File.exist?("#{@temp_dir}/subdir2"))
        assert(::File.exist?("#{@temp_dir}/subdir2/subfile.txt"))
        assert_equal('subcontents', ::File.read("#{@temp_dir}/subdir2/subfile.txt"))
      end

      def test_move_file
        @tree.move('file.txt', 'file2.txt')
        assert(::File.exist?("#{@temp_dir}/file2.txt"))
        refute(::File.exist?("#{@temp_dir}/file.txt"))
        assert_equal('contents', ::File.read("#{@temp_dir}/file2.txt"))
      end

      def test_move_file_new_parent
        @tree.move('file.txt', 'subdir/file2.txt')
        assert(::File.exist?("#{@temp_dir}/subdir/file2.txt"))
        refute(::File.exist?("#{@temp_dir}/file.txt"))
        assert_equal('contents', ::File.read("#{@temp_dir}/subdir/file2.txt"))
      end

      def test_move_directory
        @tree.move('subdir', 'subdir2')
        assert(::File.exist?("#{@temp_dir}/subdir2"))
        assert(::File.exist?("#{@temp_dir}/subdir2/subfile.txt"))
        refute(::File.exist?("#{@temp_dir}/subdir"))
        assert_equal('subcontents', ::File.read("#{@temp_dir}/subdir2/subfile.txt"))
      end
    end
  end
end
