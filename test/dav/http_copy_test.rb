require 'test_helper'

module Tilia
  module Dav
    # Tests related to the COPY request.
    class HttpCopyTest < DavServerTest
      # Sets up the DAV tree.
      #
      # @return void
      def set_up_tree
        @tree = Mock::Collection.new(
          'root',
          'file1' => 'content1',
          'file2' => 'content2',
          'coll1' => {
            'file3' => 'content3',
            'file4' => 'content4'
          }
        )
      end

      def test_copy_file
        request = Http::Request.new(
          'COPY',
          '/file1',
          'Destination' => '/file5'
        )
        response = request(request)
        assert_equal(201, response.status)
        assert_equal('content1', @tree.child('file5').get)
      end

      def test_copy_file_to_self
        request = Http::Request.new(
          'COPY',
          '/file1',
          'Destination' => '/file1'
        )
        response = request(request)
        assert_equal(403, response.status)
      end

      def test_copy_file_to_existing
        request = Http::Request.new(
          'COPY',
          '/file1',
          'Destination' => '/file2'
        )
        response = request(request)
        assert_equal(204, response.status)
        assert_equal('content1', @tree.child('file2').get)
      end

      def test_copy_file_to_existing_overwrite_t
        request = Http::Request.new(
          'COPY',
          '/file1',
          'Destination' => '/file2',
          'Overwrite'   => 'T',
        )
        response = request(request)
        assert_equal(204, response.status)
        assert_equal('content1', @tree.child('file2').get)
      end

      def test_copy_file_to_existing_overwrite_bad_value
        request = Http::Request.new(
          'COPY',
          '/file1',
          'Destination' => '/file2',
          'Overwrite'   => 'B',
        )
        response = request(request)
        assert_equal(400, response.status)
      end

      def test_copy_file_non_existant_parent
        request = Http::Request.new(
          'COPY',
          '/file1',
          'Destination' => '/notfound/file2',
        )
        response = request(request)
        assert_equal(409, response.status)
      end

      def test_copy_file_to_existing_overwrite_f
        request = Http::Request.new(
          'COPY',
          '/file1',
          'Destination' => '/file2',
          'Overwrite'   => 'F',
        )
        response = request(request)
        assert_equal(412, response.status)
        assert_equal('content2', @tree.child('file2').get)
      end

      def test_copy_file_to_existin_blocked_create_destination
        @server.on(
          'beforeBind',
          lambda do |path|
            path != 'file2'
          end
        )
        request = Http::Request.new(
          'COPY',
          '/file1',
          'Destination' => '/file2',
          'Overwrite'   => 'T',
        )
        response = request(request)

        # This checks if the destination file is intact.
        assert_equal('content2', @tree.child('file2').get)
      end

      def test_copy_coll
        request = Http::Request.new(
          'COPY',
          '/coll1',
          'Destination' => '/coll2'
        )
        response = request(request)
        assert_equal(201, response.status)
        assert_equal('content3', @tree.child('coll2').child('file3').get)
      end

      def test_copy_coll_to_self
        request = Http::Request.new(
          'COPY',
          '/coll1',
          'Destination' => '/coll1'
        )
        response = request(request)
        assert_equal(403, response.status)
      end

      def test_copy_coll_to_existing
        request = Http::Request.new(
          'COPY',
          '/coll1',
          'Destination' => '/file2'
        )
        response = request(request)
        assert_equal(204, response.status)
        assert_equal('content3', @tree.child('file2').child('file3').get)
      end

      def test_copy_coll_to_existing_overwrite_t
        request = Http::Request.new(
          'COPY',
          '/coll1',
          'Destination' => '/file2',
          'Overwrite'   => 'T',
        )
        response = request(request)
        assert_equal(204, response.status)
        assert_equal('content3', @tree.child('file2').child('file3').get)
      end

      def test_copy_coll_to_existing_overwrite_f
        request = Http::Request.new(
          'COPY',
          '/coll1',
          'Destination' => '/file2',
          'Overwrite'   => 'F',
        )
        response = request(request)
        assert_equal(412, response.status)
        assert_equal('content2', @tree.child('file2').get)
      end

      def test_copy_coll_into_subtree
        request = Http::Request.new(
          'COPY',
          '/coll1',
          'Destination' => '/coll1/subcol',
        )
        response = request(request)
        assert_equal(409, response.status)
      end
    end
  end
end
