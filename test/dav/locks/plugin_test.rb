require 'test_helper'

module Tilia
  module Dav
    module Locks
      class PluginTest < AbstractServer
        def setup
          super

          locks_backend = Backend::File.new("#{@temp_dir}/locksdb")
          @locks_plugin = Plugin.new(locks_backend)
          @server.add_plugin(@locks_plugin)
        end

        def test_get_info
          assert_has_key('name', @locks_plugin.plugin_info)
        end

        def test_get_features
          assert_equal([2], @locks_plugin.features)
        end

        def test_get_http_methods
          assert_equal(['LOCK', 'UNLOCK'], @locks_plugin.http_methods(''))
        end

        def test_lock_no_body
          request = Http::Request.new('LOCK', '/test.txt')
          @server.http_request = request
          @server.exec

          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type' => ['application/xml; charset=utf-8']
            },
            @response.headers
          )

          assert_equal(400, @response.status)
        end

        def test_lock
          request = Http::Request.new('LOCK', '/test.txt')
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(200, @response.status, "Got an incorrect status back. Response body: #{@response.body_as_string}")

          body = @response.body.gsub(/xmlns(:[A-Za-z0-9_])?=("|')DAV:("|')/) { "xmlns#{Regexp.last_match(1)}=\"urn:DAV\"" }

          xml = LibXML::XML::Document.string(body)

          elements = [
            '/d:prop',
            '/d:prop/d:lockdiscovery',
            '/d:prop/d:lockdiscovery/d:activelock',
            '/d:prop/d:lockdiscovery/d:activelock/d:locktype',
            '/d:prop/d:lockdiscovery/d:activelock/d:lockroot',
            '/d:prop/d:lockdiscovery/d:activelock/d:lockroot/d:href',
            '/d:prop/d:lockdiscovery/d:activelock/d:locktype/d:write',
            '/d:prop/d:lockdiscovery/d:activelock/d:lockscope',
            '/d:prop/d:lockdiscovery/d:activelock/d:lockscope/d:exclusive',
            '/d:prop/d:lockdiscovery/d:activelock/d:depth',
            '/d:prop/d:lockdiscovery/d:activelock/d:owner',
            '/d:prop/d:lockdiscovery/d:activelock/d:timeout',
            '/d:prop/d:lockdiscovery/d:activelock/d:locktoken',
            '/d:prop/d:lockdiscovery/d:activelock/d:locktoken/d:href'
          ]

          elements.each do |elem|
            data = xml.find(elem)
            assert_equal(1, data.size, "We expected 1 match for the xpath expression \"#{elem}\". #{data.size} were found. Full response body: #{@response.body_as_string}")
          end

          depth = xml.find('/d:prop/d:lockdiscovery/d:activelock/d:depth')
          assert_equal('infinity', depth[0].content)

          token = xml.find('/d:prop/d:lockdiscovery/d:activelock/d:locktoken/d:href')
          assert_equal(@response.header('Lock-Token'), "<#{token[0].content}>", 'Token in response body didn\'t match token in response header.')
        end

        def test_double_lock
          request = Http::Request.new('LOCK', '/test.txt')
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

          @response = Http::ResponseMock.new
          @server.http_response = @response

          @server.exec

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))

          assert_equal(423, @response.status, "Full response: #{@response.body_as_string}")
        end

        def test_lock_refresh
          request = Http::Request.new('LOCK', '/test.txt')
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

          lock_token = @response.header('Lock-Token')

          @response = Http::ResponseMock.new
          @server.http_response = @response

          request = Http::Request.new('LOCK', '/test.txt', 'If' => "(#{lock_token})")
          request.body = ''

          @server.http_request = request
          @server.exec

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))

          assert_equal(200, @response.status, "We received an incorrect status code. Full response body: #{@response.body_as_string}")
        end

        def test_lock_refresh_bad_token
          request = Http::Request.new('LOCK', '/test.txt')
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

          lock_token = @response.header('Lock-Token')

          @response = Http::ResponseMock.new
          @server.http_response = @response

          request = Http::Request.new('LOCK', '/test.txt', 'If' => "(#{lock_token}foobar) (<opaquelocktoken:anotherbadtoken>)")
          request.body = ''

          @server.http_request = request
          @server.exec

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))

          assert_equal(423, @response.status, "We received an incorrect status code. Full response body: #{@response.body_as_string}")
        end

        def test_lock_no_file
          request = Http::Request.new('LOCK', '/notfound.txt')
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(201, @response.status)
        end

        def test_unlock_no_token
          request = Http::Request.new('UNLOCK', '/test.txt')
          @server.http_request = request
          @server.exec

          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type' => ['application/xml; charset=utf-8']
            },
            @response.headers
          )

          assert_equal(400, @response.status)
        end

        def test_unlock_bad_token
          request = Http::Request.new('UNLOCK', '/test.txt', 'Lock-Token' => '<opaquelocktoken:blablabla>')
          @server.http_request = request
          @server.exec

          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type' => ['application/xml; charset=utf-8']
            },
            @response.headers
          )

          assert_equal(409, @response.status, "Got an incorrect status code. Full response body: #{@response.body_as_string}")
        end

        def test_lock_put_no_token
          request = Http::Request.new('LOCK', '/test.txt')
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(200, @response.status)

          request = Http::Request.new('PUT', '/test.txt')
          request.body = 'newbody'
          @server.http_request = request
          @server.exec

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(423, @response.status)
        end

        def test_unlock
          request = Http::Request.new('LOCK', '/test.txt')
          @server.http_request = request

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

          @server.invoke_method(request, @server.http_response)
          lock_token = @server.http_response.header('Lock-Token')

          request = Http::Request.new('UNLOCK', '/test.txt', 'Lock-Token' => lock_token)
          @server.http_request = request
          @server.http_response = Http::ResponseMock.new
          @server.invoke_method(request, @server.http_response)

          assert_equal(204, @server.http_response.status, "Got an incorrect status code. Full response body: #{@response.body_as_string}")
          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Length' => ['0']
            },
            @server.http_response.headers
          )
        end

        def test_unlock_windows_bug
          request = Http::Request.new('LOCK', '/test.txt')
          @server.http_request = request

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

          @server.invoke_method(request, @server.http_response)
          lock_token = @server.http_response.header('Lock-Token')

          # See Issue 123
          lock_token = lock_token.gsub(/^(<>)+|(<>)+$/, '')

          request = Http::Request.new('UNLOCK', '/test.txt', 'Lock-Token' => lock_token)
          @server.http_request = request
          @server.http_response = Http::ResponseMock.new
          @server.invoke_method(request, @server.http_response)

          assert_equal(204, @server.http_response.status, "Got an incorrect status code. Full response body: #{@response.body_as_string}")
          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Length' => ['0']
            },
            @server.http_response.headers
          )
        end

        def test_lock_retain_owner
          request = Http::Sapi.create_from_server_array(
            'PATH_INFO'      => '/test.txt',
            'REQUEST_METHOD' => 'LOCK'
          )
          @server.http_request = request

          request.body = <<XML
<?xml version="1.0"?>
<D:lockinfo xmlns:D="DAV:">
  <D:lockscope><D:exclusive/></D:lockscope>
  <D:locktype><D:write/></D:locktype>
  <D:owner>Evert</D:owner>
</D:lockinfo>
XML

          @server.invoke_method(request, @server.http_response)
          lock_token = @server.http_response.header('Lock-Token')

          locks = @locks_plugin.locks('test.txt')
          assert_equal(1, locks.size)
          assert_equal('Evert', locks[0].owner)
        end

        def test_lock_put_bad_token
          server_vars = {
            'PATH_INFO'      => '/test.txt',
            'REQUEST_METHOD' => 'LOCK'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(200, @response.status)

          server_vars = {
            'PATH_INFO'      => '/test.txt',
            'REQUEST_METHOD' => 'PUT',
            'HTTP_IF' => '(<opaquelocktoken:token1>)'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          request.body = 'newbody'
          @server.http_request = request
          @server.exec

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          # assert_equal('412 Precondition failed',@response.status)
          assert_equal(423, @response.status)
        end

        def test_lock_delete_parent
          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'LOCK'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(200, @response.status)

          server_vars = {
            'PATH_INFO'      => '/dir',
            'REQUEST_METHOD' => 'DELETE'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          @server.http_request = request
          @server.exec

          assert_equal(423, @response.status)
          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
        end

        def test_lock_delete_succeed
          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'LOCK'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(200, @response.status)

          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'DELETE',
            'HTTP_IF' => "(#{@response.header('Lock-Token')})"
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          @server.http_request = request
          @server.exec

          assert_equal(204, @response.status)
          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
        end

        def test_lock_copy_lock_source
          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'LOCK'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(200, @response.status)

          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'COPY',
            'HTTP_DESTINATION' => '/dir/child2.txt'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          @server.http_request = request
          @server.exec

          assert_equal(201, @response.status, 'Copy must succeed if only the source is locked, but not the destination')
          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
        end

        def test_lock_copy_lock_destination
          server_vars = {
            'PATH_INFO'      => '/dir/child2.txt',
            'REQUEST_METHOD' => 'LOCK'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(201, @response.status)

          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'COPY',
            'HTTP_DESTINATION' => '/dir/child2.txt'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          @server.http_request = request
          @server.exec

          assert_equal(423, @response.status, 'Copy must succeed if only the source is locked, but not the destination')
          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
        end

        def test_lock_move_lock_source_locked
          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'LOCK'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(200, @response.status)

          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'MOVE',
            'HTTP_DESTINATION' => '/dir/child2.txt'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          @server.http_request = request
          @server.exec

          assert_equal(423, @response.status, 'Copy must succeed if only the source is locked, but not the destination')
          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
        end

        def test_lock_move_lock_source_succeed
          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'LOCK'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(200, @response.status)

          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'MOVE',
            'HTTP_DESTINATION' => '/dir/child2.txt',
            'HTTP_IF' => "(#{@response.header('Lock-Token')})"
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          @server.http_request = request
          @server.exec

          assert_equal(201, @response.status, "A valid lock-token was provided for the source, so this MOVE operation must succeed. Full response body: #{@response.body_as_string}")
        end

        def test_lock_move_lock_destination
          server_vars = {
            'PATH_INFO'      => '/dir/child2.txt',
            'REQUEST_METHOD' => 'LOCK'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(201, @response.status)

          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'MOVE',
            'HTTP_DESTINATION' => '/dir/child2.txt'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          @server.http_request = request
          @server.exec

          assert_equal(423, @response.status, 'Copy must succeed if only the source is locked, but not the destination')
          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
        end

        def test_lock_move_lock_parent
          server_vars = {
            'PATH_INFO'      => '/dir',
            'REQUEST_METHOD' => 'LOCK',
            'HTTP_DEPTH' => 'infinite'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(200, @response.status)

          server_vars = {
            'PATH_INFO'      => '/dir/child.txt',
            'REQUEST_METHOD' => 'MOVE',
            'HTTP_DESTINATION' => '/dir/child2.txt',
            'HTTP_IF' => "</dir> (#{@response.header('Lock-Token')})"
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          @server.http_request = request
          @server.exec

          assert_equal(201, @response.status, 'We locked the parent of both the source and destination, but the move didn\'t succeed.')
          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
        end

        def test_lock_put_good_token
          server_vars = {
            'PATH_INFO'      => '/test.txt',
            'REQUEST_METHOD' => 'LOCK'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(200, @response.status)

          server_vars = {
            'PATH_INFO'      => '/test.txt',
            'REQUEST_METHOD' => 'PUT',
            'HTTP_IF' => "(#{@response.header('Lock-Token')})"
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          request.body = 'newbody'
          @server.http_request = request
          @server.exec

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(204, @response.status)
        end

        def test_lock_put_unrelated_token
          request = Http::Request.new('LOCK', '/unrelated.txt')
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

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(201, @response.status)

          request = Http::Request.new(
            'PUT',
            '/test.txt',
            'If' => "</unrelated.txt> (#{@response.header('Lock-Token')})"
          )
          request.body = 'newbody'
          @server.http_request = request
          @server.exec

          assert_equal('application/xml; charset=utf-8', @response.header('Content-Type'))
          assert(@response.header('Lock-Token') =~ /^<opaquelocktoken:(.*)>$/, "We did not get a valid Locktoken back (#{@response.header('Lock-Token')})")

          assert_equal(204, @response.status)
        end

        def test_put_with_incorrect_etag
          server_vars = {
            'PATH_INFO'      => '/test.txt',
            'REQUEST_METHOD' => 'PUT',
            'HTTP_IF' => '(["etag1"])'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          request.body = 'newbody'
          @server.http_request = request
          @server.exec
          assert_equal(412, @response.status)
        end

        def test_put_with_correct_etag
          # We need an ETag-enabled file node.
          tree = Tree.new(FsExt::Directory.new(@temp_dir))
          @server.tree = tree

          filename = "#{@temp_dir}/test.txt"
          stat = ::File.stat(filename)
          etag = Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s)
          server_vars = {
            'PATH_INFO'      => '/test.txt',
            'REQUEST_METHOD' => 'PUT',
            'HTTP_IF' => "([\"#{etag}\"])"
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          request.body = 'newbody'
          @server.http_request = request
          @server.exec
          assert_equal(204, @response.status, "Incorrect status received. Full response body:#{@response.body_as_string}")
        end

        def test_delete_with_etag_on_collection
          server_vars = {
            'PATH_INFO'      => '/dir',
            'REQUEST_METHOD' => 'DELETE',
            'HTTP_IF' => '(["etag1"])'
          }
          request = Http::Sapi.create_from_server_array(server_vars)

          @server.http_request = request
          @server.exec
          assert_equal(412, @response.status)
        end

        def test_get_timeout_header
          request = Http::Sapi.create_from_server_array(
            'HTTP_TIMEOUT' => 'second-100'
          )

          @server.http_request = request
          assert_equal(100, @locks_plugin.timeout_header)
        end

        def test_get_timeout_header_two_items
          request = Http::Sapi.create_from_server_array(
            'HTTP_TIMEOUT' => 'second-5, infinite'
          )

          @server.http_request = request
          assert_equal(5, @locks_plugin.timeout_header)
        end

        def test_get_timeout_header_infinite
          request = Http::Sapi.create_from_server_array(
            'HTTP_TIMEOUT' => 'infinite, second-5'
          )

          @server.http_request = request
          assert_equal(LockInfo::TIMEOUT_INFINITE, @locks_plugin.timeout_header)
        end

        def test_get_timeout_header_invalid
          request = Http::Sapi.create_from_server_array(
            'HTTP_TIMEOUT' => 'yourmom'
          )

          @server.http_request = request
          assert_raises(Exception::BadRequest) { @locks_plugin.timeout_header }
        end
      end
    end
  end
end
