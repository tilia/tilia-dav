require 'test_helper'

module Tilia
  module Dav
    class ClientTest < Minitest::Test
      def test_construct
        client = ClientMock.new(
          'baseUri' => '/'
        )
        assert_kind_of(ClientMock, client)
      end

      def test_construct_no_base_uri
        assert_raises(ArgumentError) do
          client = ClientMock.new({})
        end
      end

      def test_auth
        client = ClientMock.new(
          'baseUri' => '/',
          'userName' => 'foo',
          'password' => 'bar'
        )

        assert_equal('foo:bar', client.curl_settings[:userpwd])
        assert_equal([:basic, :digest], client.curl_settings[:httpauth])
      end

      def test_basic_auth
        client = ClientMock.new(
          'baseUri' => '/',
          'userName' => 'foo',
          'password' => 'bar',
          'authType' => Client::AUTH_BASIC
        )

        assert_equal('foo:bar', client.curl_settings[:userpwd])
        assert_equal([:basic], client.curl_settings[:httpauth])
      end

      def test_digest_auth
        client = ClientMock.new(
          'baseUri' => '/',
          'userName' => 'foo',
          'password' => 'bar',
          'authType' => Client::AUTH_DIGEST
        )

        assert_equal('foo:bar', client.curl_settings[:userpwd])
        assert_equal([:digest], client.curl_settings[:httpauth])
      end

      def test_ntlm_auth
        client = ClientMock.new(
          'baseUri' => '/',
          'userName' => 'foo',
          'password' => 'bar',
          'authType' => Client::AUTH_NTLM
        )

        assert_equal('foo:bar', client.curl_settings[:userpwd])
        assert_equal([:ntlm], client.curl_settings[:httpauth])
      end

      def test_proxy
        client = ClientMock.new(
          'baseUri' => '/',
          'proxy' => 'localhost:8888'
        )

        assert_equal('localhost:8888', client.curl_settings[:proxy])
      end

      def test_encoding
        client = ClientMock.new(
          'baseUri' => '/',
          'encoding' => Client::ENCODING_IDENTITY | Client::ENCODING_GZIP | Client::ENCODING_DEFLATE
        )

        assert_equal('identity,deflate,gzip', client.curl_settings[:encoding])
      end

      def test_prop_find
        client = ClientMock.new(
          'baseUri' => '/'
        )

        response_body = <<XML
<?xml version="1.0"?>
<multistatus xmlns="DAV:">
  <response>
    <href>/foo</href>
    <propstat>
      <prop>
        <displayname>bar</displayname>
      </prop>
      <status>HTTP/1.1 200 OK</status>
    </propstat>
  </response>
</multistatus>
XML

        client.response = Http::Response.new(207, {}, response_body)
        result = client.prop_find('foo', ['{DAV:}displayname', '{urn:zim}gir'])

        assert_equal({ '{DAV:}displayname' => 'bar' }, result)

        request = client.request
        assert_equal('PROPFIND', request.method)
        assert_equal('/foo', request.url)
        assert_equal(
          {
            'Depth' => [0],
            'Content-Type' => ['application/xml']
          },
          request.headers
        )
      end

      def test_prop_find_error
        client = ClientMock.new(
          'baseUri' => '/'
        )

        client.response = Http::Response.new(405, {})
        assert_raises(Exception) do
          client.prop_find('foo', ['{DAV:}displayname', '{urn:zim}gir'])
        end
      end

      def test_prop_find_depth1
        client = ClientMock.new(
          'baseUri' => '/'
        )

        response_body = <<XML
<?xml version="1.0"?>
<multistatus xmlns="DAV:">
  <response>
    <href>/foo</href>
    <propstat>
      <prop>
        <displayname>bar</displayname>
      </prop>
      <status>HTTP/1.1 200 OK</status>
    </propstat>
  </response>
</multistatus>
XML

        client.response = Http::Response.new(207, {}, response_body)
        result = client.prop_find('foo', ['{DAV:}displayname', '{urn:zim}gir'], 1)

        assert_equal(
          {
            '/foo' => {
              '{DAV:}displayname' => 'bar'
            }
          },
          result
        )

        request = client.request
        assert_equal('PROPFIND', request.method)
        assert_equal('/foo', request.url)
        assert_equal(
          {
            'Depth' => [1],
            'Content-Type' => ['application/xml']
          },
          request.headers
        )
      end

      def test_prop_patch
        client = ClientMock.new(
          'baseUri' => '/'
        )

        response_body = <<XML
<?xml version="1.0"?>
<multistatus xmlns="DAV:">
  <response>
    <href>/foo</href>
    <propstat>
      <prop>
        <displayname>bar</displayname>
      </prop>
      <status>HTTP/1.1 200 OK</status>
    </propstat>
  </response>
</multistatus>
XML

        client.response = Http::Response.new(207, {}, response_body)
        result = client.prop_patch('foo', '{DAV:}displayname' => 'hi', '{urn:zim}gir' => nil)
        request = client.request
        assert_equal('PROPPATCH', request.method)
        assert_equal('/foo', request.url)
        assert_equal(
          {
            'Content-Type' => ['application/xml']
          },
          request.headers
        )
      end

      def test_options
        client = ClientMock.new(
          'baseUri' => '/'
        )

        client.response = Http::Response.new(207,
                                             'DAV' => 'calendar-access, extended-mkcol'
                                            )
        result = client.options

        assert_equal(
          ['calendar-access', 'extended-mkcol'],
          result
        )

        request = client.request
        assert_equal('OPTIONS', request.method)
        assert_equal('/', request.url)
        assert_equal({}, request.headers)
      end
    end
  end
end
