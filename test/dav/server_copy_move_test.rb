require 'test_helper'

module Tilia
  module Dav
    class ServerCopyMoveTest < AbstractServer
      def setup
        super

        @server.debug_exceptions = true

        ::File.open("#{@temp_dir}/test2.txt", 'w') { |f| f.write 'Test contents2' }
        Dir.mkdir("#{@temp_dir}/col")
        ::File.open("#{@temp_dir}/col/test.txt", 'w') { |f| f.write 'Test contents' }
      end

      def test_copy_over_write
        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'COPY',
          'HTTP_DESTINATION' => '/test2.txt'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(204, @response.status, "Received an incorrect HTTP status. Full body inspection: #{@response.body_as_string}")
        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0']
          },
          @response.headers
        )

        assert_equal('Test contents', ::File.read("#{@temp_dir}/test2.txt"))
      end

      def test_copy_to_self
        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'COPY',
          'HTTP_DESTINATION' => '/test.txt'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(403, @response.status, "Received an incorrect HTTP status. Full body inspection: #{@response.body_as_string}")
        assert_equal('Test contents', ::File.read("#{@temp_dir}/test.txt"))
      end

      def test_non_existant_parent
        server_vars = {
          'PATH_INFO'        => '/test.txt',
          'REQUEST_METHOD'   => 'COPY',
          'HTTP_DESTINATION' => '/testcol2/test2.txt',
          'HTTP_OVERWRITE'   => 'F'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(409, @response.status)
      end

      def test_random_overwrite_header
        server_vars = {
          'PATH_INFO'        => '/test.txt',
          'REQUEST_METHOD'   => 'COPY',
          'HTTP_DESTINATION' => '/testcol2/test2.txt',
          'HTTP_OVERWRITE'   => 'SURE!'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(400, @response.status)
      end

      def test_copy_directory
        server_vars = {
          'PATH_INFO'      => '/col',
          'REQUEST_METHOD' => 'COPY',
          'HTTP_DESTINATION' => '/col2'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(201, @response.status, "Full response: #{@response.body_as_string}")

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0']
          },
          @response.headers
        )

        assert_equal('Test contents', ::File.read("#{@temp_dir}/col/test.txt"))
      end

      def test_simple_copy_file
        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'COPY',
          'HTTP_DESTINATION' => '/test3.txt'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0']
          },
          @response.headers
        )

        assert_equal(201, @response.status)
        assert_equal('Test contents', ::File.read("#{@temp_dir}/test3.txt"))
      end

      def test_simple_copy_collection
        server_vars = {
          'PATH_INFO'      => '/col',
          'REQUEST_METHOD' => 'COPY',
          'HTTP_DESTINATION' => '/col2'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(201, @response.status, "Incorrect status received. Full response body: #{@response.body_as_string}")

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0']
          },
          @response.headers
        )

        assert_equal('Test contents', ::File.read("#{@temp_dir}/col2/test.txt"))
      end
    end
  end
end
