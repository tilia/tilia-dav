require 'test_helper'

module Tilia
  module Dav
    class SimpleFileTest < Minitest::Test
      def test_all
        file = Tilia::Dav::SimpleFile.new('filename.txt', 'contents', 'text/plain')

        assert_equal('filename.txt', file.name)
        assert_equal('contents', file.get)
        assert_equal(8, file.size)
        assert_equal("\"#{Digest::SHA1.hexdigest('contents')}\"", file.etag)
        assert_equal('text/plain', file.content_type)
      end
    end
  end
end
