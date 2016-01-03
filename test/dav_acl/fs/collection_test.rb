require 'dav_acl/fs/file_test'

module Tilia
  module DavAcl
    module Fs
      class CollectionTest < FileTest
        def setup
          super
          @path = Dir.mktmpdir
          @sut = Collection.new(@path, @acl, @owner)
        end

        def teardown
          FileUtils.remove_entry @path
        end

        def test_get_child_file
          ::File.open("#{@path}/file.txt", 'w') { |f| f.write('hello') }
          child = @sut.child('file.txt')
          assert_kind_of(File, child)

          assert_equal('file.txt', child.name)
          assert_equal(@acl, child.acl)
          assert_equal(@owner, child.owner)
        end

        def test_get_child_directory
          Dir.mkdir("#{@path}/dir")
          child = @sut.child('dir')
          assert_kind_of(Collection, child)

          assert_equal('dir', child.name)
          assert_equal(@acl, child.acl)
          assert_equal(@owner, child.owner)
        end
      end
    end
  end
end
