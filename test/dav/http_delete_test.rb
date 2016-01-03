require 'test_helper'

module Tilia
  module Dav
    # Tests related to the PUT request.
    class HttpDeleteTest < DavServerTest
      # Sets up the DAV tree.
      #
      # @return void
      def set_up_tree
        @tree = Mock::Collection.new(
          'root',
          'file1' => 'foo',
          'dir' => {
            'subfile' => 'bar',
            'subfile2' => 'baz'
          }
        )
      end

      # A successful DELETE
      def test_delete
        request = Http::Request.new('DELETE', '/file1')

        response = self.request(request)

        assert_equal(
          204,
          response.status,
          "Incorrect status code. Response body:  #{response.body_as_string}"
        )

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0']
          },
          response.headers
        )
      end

      # Deleting a Directory
      def test_delete_directory
        request = Http::Request.new('DELETE', '/dir')

        response = self.request(request)

        assert_equal(
          204,
          response.status,
          "Incorrect status code. Response body:  #{response.body_as_string}"
        )

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0']
          },
          response.headers
        )
      end

      # DELETE on a node that does not exist
      def test_delete_not_found
        request = Http::Request.new('DELETE', '/file2')
        response = self.request(request)

        assert_equal(
          404,
          response.status,
          "Incorrect status code. Response body:  #{response.body_as_string}"
        )
      end

      # DELETE with preconditions
      def test_delete_preconditions
        request = Http::Request.new(
          'DELETE',
          '/file1',
          'If-Match' => "\"#{Digest::MD5.hexdigest('foo')}\""
        )

        response = self.request(request)

        assert_equal(
          204,
          response.status,
          "Incorrect status code. Response body:  #{response.body_as_string}"
        )
      end

      # DELETE with incorrect preconditions
      def test_delete_preconditions_failed
        request = Http::Request.new(
          'DELETE',
          '/file1',
          'If-Match' => "\"#{Digest::MD5.hexdigest('bar')}\""
        )

        response = self.request(request)

        assert_equal(
          412,
          response.status,
          "Incorrect status code. Response body:  #{response.body_as_string}"
        )
      end
    end
  end
end
