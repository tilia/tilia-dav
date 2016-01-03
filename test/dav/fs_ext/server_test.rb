require 'test_helper'

module Tilia
  module Dav
    module FsExt
      class ServerTest < AbstractServer
        def root_node
          Directory.new(@temp_dir)
        end

        def etag(filename)
          stat = ::File.stat(filename)
          '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'
        end

        def test_get
          request = Http::Request.new('GET', '/test.txt')
          filename = "#{@temp_dir}/test.txt"
          @server.http_request = request
          @server.exec

          assert_equal(200, @response.status, 'Invalid status code received.')
          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type'    => ['application/octet-stream'],
              'Content-Length'  => [13],
              'Last-Modified'   => [Http::Util.to_http_date(::File.mtime(filename))],
              'ETag'            => [etag(filename)]
            },
            @response.headers
          )

          assert_equal('Test contents', @response.body_as_string)
        end

        def test_head
          request = Http::Request.new('HEAD', '/test.txt')
          filename = "#{@temp_dir}/test.txt"
          @server.http_request = request
          @server.exec

          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type'    => ['application/octet-stream'],
              'Content-Length'  => [13],
              'Last-Modified'   => [Http::Util.to_http_date(::File.mtime("#{@temp_dir}/test.txt"))],
              'ETag'            => [etag(filename)]
            },
            @response.headers
          )

          assert_equal(200, @response.status)
          assert_equal('', @response.body_as_string)
        end

        def test_put
          request = Http::Request.new('PUT', '/testput.txt')
          filename = "#{@temp_dir}/testput.txt"
          request.body = 'Testing new file'
          @server.http_request = request
          @server.exec

          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Length'  => ['0'],
              'ETag'            => [etag(filename)]
            },
            @response.headers
          )

          assert_equal(201, @response.status)
          assert_equal('', @response.body_as_string)
          assert_equal('Testing new file', ::File.read(filename))
        end

        def test_put_already_exists
          request = Http::Request.new('PUT', '/test.txt', 'If-None-Match' => '*')
          request.body = 'Testing new file'
          @server.http_request = request
          @server.exec

          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type' => ['application/xml; charset=utf-8']
            },
            @response.headers
          )

          assert_equal(412, @response.status)
          refute_equal('Testing new file', ::File.read("#{@temp_dir}/test.txt"))
        end

        def test_mkcol
          request = Http::Request.new('MKCOL', '/testcol')
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
          assert_equal('', @response.body_as_string)
          assert(::File.directory?("#{@temp_dir}/testcol"))
        end

        def test_put_update
          request = Http::Request.new('PUT', '/test.txt')
          request.body = 'Testing updated file'
          @server.http_request = request
          @server.exec

          assert_equal('0', @response.header('Content-Length'))

          assert_equal(204, @response.status)
          assert_equal('', @response.body_as_string)
          assert_equal('Testing updated file', ::File.read("#{@temp_dir}/test.txt"))
        end

        def test_delete
          request = Http::Request.new('DELETE', '/test.txt')
          @server.http_request = request
          @server.exec

          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Length' => ['0']
            },
            @response.headers
          )

          assert_equal(204, @response.status)
          assert_equal('', @response.body_as_string)
          refute(::File.exist?("#{@temp_dir}/test.txt"))
        end

        def test_delete_directory
          ::Dir.mkdir("#{@temp_dir}/testcol")
          ::File.open("#{@temp_dir}/testcol/test.txt", 'w') do |f|
            f.write 'Hi! I\'m a file with a short lifespan'
          end

          request = Http::Request.new('DELETE', '/testcol')
          @server.http_request = request
          @server.exec

          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Length' => ['0']
            },
            @response.headers
          )

          assert_equal(204, @response.status)
          assert_equal('', @response.body_as_string)
          refute(::File.exist?("#{@temp_dir}/col"))
        end

        def test_options
          request = Http::Request.new('OPTIONS', '/')
          @server.http_request = request
          @server.exec

          assert_equal(
            {
              'DAV'            => ['1, 3, extended-mkcol'],
              'MS-Author-Via'  => ['DAV'],
              'Allow'          => ['OPTIONS, GET, HEAD, DELETE, PROPFIND, PUT, PROPPATCH, COPY, MOVE, REPORT'],
              'Accept-Ranges'  => ['bytes'],
              'Content-Length' => ['0'],
              'X-Sabre-Version' => [Version::VERSION]
            },
            @response.headers
          )

          assert_equal(200, @response.status)
          assert_equal('', @response.body_as_string)
        end

        def test_move
          ::Dir.mkdir("#{@temp_dir}/testcol")

          request = Http::Request.new('MOVE', '/test.txt', 'Destination' => '/testcol/test2.txt')
          @server.http_request = request
          @server.exec

          assert_equal(201, @response.status)
          assert_equal('', @response.body_as_string)

          assert_equal(
            {
              'Content-Length' => ['0'],
              'X-Sabre-Version' => [Version::VERSION]
            },
            @response.headers
          )

          assert(::File.file?("#{@temp_dir}/testcol/test2.txt"))
        end

        # This test checks if it's possible to move a non-FSExt collection into a
        # FSExt collection.
        #
        # The moveInto function *should* ignore the object and let sabredav itself
        # execute the slow move.
        def test_move_other_object
          ::Dir.mkdir("#{@temp_dir}/tree1")
          ::Dir.mkdir("#{@temp_dir}/tree2")

          tree = Tree.new(
            SimpleCollection.new(
              'root',
              [
                Fs::Directory.new("#{@temp_dir}/tree1"),
                FsExt::Directory.new("#{@temp_dir}/tree2")
              ]
            )
          )
          @server.tree = tree

          request = Http::Request.new('MOVE', '/tree1', 'Destination' => '/tree2/tree1')
          @server.http_request = request
          @server.exec

          assert_equal(201, @response.status)
          assert_equal('', @response.body_as_string)

          assert_equal(
            {
              'Content-Length' => ['0'],
              'X-Sabre-Version' => [Version::VERSION]
            },
            @response.headers
          )

          assert(::File.directory?("#{@temp_dir}/tree2/tree1"))
        end
      end
    end
  end
end
