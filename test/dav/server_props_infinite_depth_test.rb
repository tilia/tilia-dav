require 'test_helper'

module Tilia
  module Dav
    class ServerPropsInfiniteDepthTest < AbstractServer
      def root_node
        FsExt::Directory.new(@temp_dir)
      end

      def setup
        super

        ::File.open("#{@temp_dir}/test2.txt", 'w') { |f| f.write 'Test contents2' }
        Dir.mkdir("#{@temp_dir}/col")
        Dir.mkdir("#{@temp_dir}/col/col")
        ::File.open("#{@temp_dir}/col/col/test.txt", 'w') { |f| f.write 'Test contents' }
        @server.add_plugin(Locks::Plugin.new(Locks::Backend::File.new("#{@temp_dir}/.locksdb")))
        @server.enable_propfind_depth_infinity = true
      end

      def send_request(body)
        request = Http::Request.new('PROPFIND', '/', 'Depth' => 'infinity')
        request.body = body

        @server.http_request = request
        @server.exec
      end

      def test_prop_find_empty_body
        send_request('')

        assert_equal(207, @response.status, "Incorrect status received. Full response body: #{@response.body_as_string}")

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8'],
            'DAV' => ['1, 3, extended-mkcol, 2'],
            'Vary' => ['Brief,Prefer']
          },
          @response.headers
        )

        body = @response.body.gsub(/xmlns(:[A-Za-z0-9_])?=("|')DAV:("|')/) { "xmlns#{Regexp.last_match(1)}=\"urn:DAV\"" }
        xml = LibXML::XML::Document.string(body)

        data = xml.find_first('/d:multistatus/d:response/d:href')
        assert_equal('/', data.content, 'href element should have been /')

        data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:resourcetype')
        # 8 resources are to be returned: /, col, col/col, col/col/test.txt, dir, dir/child.txt, test.txt and test2.txt
        assert_equal(8, data.size)
      end

      def test_supported_locks
        xml = <<XML
<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:supportedlock />
  </d:prop>
</d:propfind>
XML

        send_request(xml)

        body = @response.body_as_string
        assert_equal(207, @response.status, body)

        body = @response.body.gsub(/xmlns(:[A-Za-z0-9_])?=("|')DAV:("|')/) { "xmlns#{Regexp.last_match(1)}=\"urn:DAV\"" }
        xml = LibXML::XML::Document.string(body)

        data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supportedlock/d:lockentry')
        assert_equal(16, data.size, 'We expected sixteen \'d:lockentry\' tags')

        data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supportedlock/d:lockentry/d:lockscope')
        assert_equal(16, data.size, 'We expected sixteen \'d:lockscope\' tags')

        data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supportedlock/d:lockentry/d:locktype')
        assert_equal(16, data.size, 'We expected sixteen \'d:locktype\' tags')

        data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supportedlock/d:lockentry/d:lockscope/d:shared')
        assert_equal(8, data.size, 'We expected eight \'d:shared\' tags')

        data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supportedlock/d:lockentry/d:lockscope/d:exclusive')
        assert_equal(8, data.size, 'We expected eight \'d:exclusive\' tags')

        data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supportedlock/d:lockentry/d:locktype/d:write')
        assert_equal(16, data.size, 'We expected sixteen \'d:write\' tags')
      end

      def test_lock_discovery
        xml = <<XML
<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:lockdiscovery />
  </d:prop>
</d:propfind>
XML

        send_request(xml)

        body = @response.body.gsub(/xmlns(:[A-Za-z0-9_])?=("|')DAV:("|')/) { "xmlns#{Regexp.last_match(1)}=\"urn:DAV\"" }
        xml = LibXML::XML::Document.string(body)

        data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:lockdiscovery')
        assert_equal(8, data.size, 'We expected eight \'d:lockdiscovery\' tags')
      end

      def test_unknown_property
        xml = <<XML
<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:macaroni />
  </d:prop>
</d:propfind>
XML

        send_request(xml)

        body = @response.body.gsub(/xmlns(:[A-Za-z0-9_])?=("|')DAV:("|')/) { "xmlns#{Regexp.last_match(1)}=\"urn:DAV\"" }
        xml = LibXML::XML::Document.string(body)

        path_tests = [
          '/d:multistatus',
          '/d:multistatus/d:response',
          '/d:multistatus/d:response/d:propstat',
          '/d:multistatus/d:response/d:propstat/d:status',
          '/d:multistatus/d:response/d:propstat/d:prop',
          '/d:multistatus/d:response/d:propstat/d:prop/d:macaroni'
        ]
        path_tests.each do |test|
          assert(xml.find(test).size > 0, "We expected the #{test} element to appear in the response, we got: #{body}")
        end

        val = xml.find('/d:multistatus/d:response/d:propstat/d:status')
        assert_equal(8, val.size, body)
        assert_equal('HTTP/1.1 404 Not Found', val[0].content)
      end
    end
  end
end
