require 'test_helper'

module Tilia
  module Dav
    # Tests related to the MOVE request.
    class HttpMoveTest < DavServerTest
      # Sets up the DAV tree.
      #
      # @return void
      def set_up_tree
        @tree = Mock::Collection.new(
          'root',
          'file1' => 'content1',
          'file2' => 'content2'
        )
      end

      def test_move_to_self
        request = Http::Request.new(
          'MOVE',
          '/file1',
          'Destination' => '/file1'
        )
        response = self.request(request)
        assert_equal(403, response.status)
        assert_equal('content1', @tree.child('file1').get)
      end

      def test_move
        request = Http::Request.new(
          'MOVE',
          '/file1',
          'Destination' => '/file3'
        )
        response = self.request(request)
        assert_equal(201, response.status, response.inspect)
        assert_equal('content1', @tree.child('file3').get)
        refute(@tree.child_exists('file1'))
      end

      def test_move_to_existing
        request = Http::Request.new(
          'MOVE',
          '/file1',
          'Destination' => '/file2'
        )
        response = self.request(request)
        assert_equal(204, response.status, response.inspect)
        assert_equal('content1', @tree.child('file2').get)
        refute(@tree.child_exists('file1'))
      end

      def test_move_to_existing_overwrite_t
        request = Http::Request.new(
          'MOVE',
          '/file1',
          'Destination' => '/file2',
          'Overwrite' => 'T'
        )
        response = self.request(request)
        assert_equal(204, response.status, response.inspect)
        assert_equal('content1', @tree.child('file2').get)
        refute(@tree.child_exists('file1'))
      end

      def test_move_to_existing_overwrite_f
        request = Http::Request.new(
          'MOVE',
          '/file1',
          'Destination' => '/file2',
          'Overwrite' => 'F'
        )
        response = self.request(request)
        assert_equal(412, response.status, response.inspect)
        assert_equal('content1', @tree.child('file1').get)
        assert_equal('content2', @tree.child('file2').get)
        assert(@tree.child_exists('file1'))
        assert(@tree.child_exists('file2'))
      end

      # If we MOVE to an existing file, but a plugin prevents the original from
      # being deleted, we need to make sure that the server does not delete
      # the destination.
      def test_move_to_existing_blocked_delete_source
        @server.on(
          'beforeUnbind',
          lambda do |path|
            fail Exception::Forbidden, 'uh oh' if path == 'file1'
          end
        )
        request = Http::Request.new(
          'MOVE',
          '/file1',
          'Destination' => '/file2'
        )
        response = self.request(request)
        assert_equal(403, response.status, response.inspect)
        assert_equal('content1', @tree.child('file1').get)
        assert_equal('content2', @tree.child('file2').get)
        assert(@tree.child_exists('file1'))
        assert(@tree.child_exists('file2'))
      end
    end
  end
end
