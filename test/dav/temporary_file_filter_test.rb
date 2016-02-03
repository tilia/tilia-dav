require 'test_helper'

module Tilia
  module Dav
    class TemporaryFileFilterTest < AbstractServer
      def setup
        super
        plugin = Tilia::Dav::TemporaryFileFilterPlugin.new(::File.join(@temp_dir, '/tff'))
        @server.add_plugin(plugin)
      end

      def test_put_normal
        request = Tilia::Http::Request.new('PUT', '/testput.txt', {}, 'Testing new file')

        @server.http_request = request
        @server.exec

        assert_equal(nil, @response.body)
        assert_equal(201, @response.status)
        assert_equal('0', @response.header('Content-Length'))

        assert_equal('Testing new file', ::File.read(::File.join(@temp_dir, 'testput.txt')))
      end

      def test_put_temp
        # mimicking an OS/X resource fork
        request = Tilia::Http::Request.new('PUT', '/._testput.txt', [], 'Testing new file')

        @server.http_request = request
        @server.exec

        assert_equal(nil, @response.body)
        assert_equal(201, @response.status)
        assert_equal({ 'X-Sabre-Temp' => ['true'] }, @response.headers)

        refute(::File.exist?(::File.join(@temp_dir, '._testput.txt'))) # ._testput.txt should not exist in the regular file structure.
      end

      def test_put_temp_if_none_match
        # mimicking an OS/X resource fork
        request = Tilia::Http::Request.new('PUT', '/._testput.txt', { 'If-None-Match' => '*' }, 'Testing new file')

        @server.http_request = request
        @server.exec

        assert_equal(nil, @response.body)
        assert_equal(201, @response.status)
        assert_equal({ 'X-Sabre-Temp' => ['true'] }, @response.headers)

        refute(::File.exist?(::File.join(@temp_dir, '._testput.txt'))) # _testput.txt should not exist in the regular file structure.

        @server.exec

        assert_equal(412, @response.status)
        assert_equal(
          {
            'X-Sabre-Temp' => ['true'],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )
      end

      def test_put_get
        # mimicking an OS/X resource fork
        request = Tilia::Http::Request.new('PUT', '/._testput.txt', [], 'Testing new file')
        @server.http_request = request
        @server.exec

        assert_equal(nil, @response.body)
        assert_equal(201, @response.status)
        assert_equal({ 'X-Sabre-Temp' => ['true'] }, @response.headers)

        request = Tilia::Http::Request.new('GET', '/._testput.txt')

        @server.http_request = request
        @server.exec

        assert_equal(200, @response.status)
        assert_equal(
          {
            'X-Sabre-Temp' => ['true'],
            'Content-Length' => [16],
            'Content-Type' => ['application/octet-stream']
          },
          @response.headers
        )

        assert_equal('Testing new file', @response.body_as_string)
      end

      def test_lock_non_existant
        Dir.mkdir(::File.join(@temp_dir, 'locksdir'))
        locks_backend = Tilia::Dav::Locks::Backend::File.new(::File.join(@temp_dir, 'locks'))
        locks_plugin = Tilia::Dav::Locks::Plugin.new(locks_backend)
        @server.add_plugin(locks_plugin)

        # mimicking an OS/X resource fork
        request = Tilia::Http::Request.new('LOCK', '/._testput.txt')
        request.body = <<XML
<?xml version="1.0"?>
<D:lockinfo xmlns:D="DAV:">
  <D:lockscope><D:exclusive/></D:lockscope>
  <D:locktype><D:write/></D:locktype>
  <D:owner>
    <D:href>http://example.org/~ejw/contact.html</D:href>
  </D:owner>
</D:lockinfo>
XML

        @server.http_request = request
        @server.exec

        assert_equal(201, @response.status)
        assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
        assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")
        assert_equal('true', @response.header('X-Sabre-Temp'))

        refute(::File.exist?(::File.join(@temp_dir, '._testlock.txt')), '_testlock.txt should not exist in the regular file structure.')
      end

      def test_put_delete
        # mimicking an OS/X resource fork
        request = Tilia::Http::Request.new('PUT', '/._testput.txt', [], 'Testing new file')

        @server.http_request = request
        @server.exec

        assert_equal(nil, @response.body)
        assert_equal(201, @response.status)
        assert_equal({ 'X-Sabre-Temp' => ['true'] }, @response.headers)

        request = Tilia::Http::Request.new('DELETE', '/._testput.txt')
        @server.http_request = request
        @server.exec

        assert_equal(204, @response.status, "Incorrect status code received. Full body:\n#{@response.body}")
        assert_equal({ 'X-Sabre-Temp' => ['true'] }, @response.headers)

        assert_equal(nil, @response.body)
      end

      def test_put_propfind
        # mimicking an OS/X resource fork
        request = Tilia::Http::Request.new('PUT', '/._testput.txt', [], 'Testing new file')
        @server.http_request = request
        @server.exec

        assert_equal(nil, @response.body)
        assert_equal(201, @response.status)
        assert_equal({ 'X-Sabre-Temp' => ['true'] }, @response.headers)

        request = Tilia::Http::Request.new('PROPFIND', '/._testput.txt')

        @server.http_request = request
        @server.exec

        assert_equal(207, @response.status, "Incorrect status code returned. Body: #{@response.body}")
        assert_equal(
          {
            'X-Sabre-Temp' => ['true'],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        body = @response.body.gsub(/xmlns(:[A-Za-z0-9_])?=("|')DAV:("|')/) { "xmlns#{Regexp.last_match(1)}=\"urn:DAV\"" }

        xml = LibXML::XML::Document.string(body)

        data = xml.find_first('/d:multistatus/d:response/d:href')
        assert_equal('/._testput.txt', data.content, 'href element should have been /._testput.txt')

        data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:resourcetype')
        assert_equal(1, data.size)
      end
    end
  end
end
