require 'test_helper'

module Tilia
  module Dav
    module FsExt
      class FileTest < Minitest::Test
        def setup
          @temp_dir = Dir.mktmpdir
          ::File.open("#{@temp_dir}/file.txt", 'w') { |f| f.write('Contents') }
          @filename = "#{@temp_dir}/file.txt"
          @file = File.new(@filename)
        end

        def teardown
          FileUtils.remove_entry @temp_dir
        end

        def etag
          stat = ::File.stat(@filename)
          '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'
        end

        def test_put
          result = @file.put('New contents')

          assert_equal('New contents', ::File.read(@filename))
          assert_equal(etag, result)
        end

        def test_range
          @file.put('0000000')
          @file.patch('111', 2, 3)

          assert_equal('0001110', ::File.read(@filename))
        end

        def test_range_stream
          stream = StringIO.new
          stream.write('222')
          stream.rewind

          @file.put('0000000')
          @file.patch(stream, 2, 3)

          assert_equal('0002220', ::File.read(@filename))
        end

        def test_get
          assert_equal('Contents', @file.get.read)
        end

        def test_delete
          @file.delete

          refute(::File.exist?(@filename))
        end

        def test_get_etag
          assert_equal(etag, @file.etag)
        end

        def test_get_content_type
          assert_nil(@file.content_type)
        end

        def test_get_size
          assert_equal(8, @file.size)
        end
      end
    end
  end
end
