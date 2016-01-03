require 'test_helper'

module Tilia
  module Dav
    module Xml
      module Property
        class SupportedMethodSetTest < AbstractServer
          def send_propfind(body)
            request = Tilia::Http::Request.new('PROPFIND', '/', 'Depth' => '0')
            request.body = body

            server.http_request = request
            server.exec
          end

          def test_methods
            xml = <<XML
<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:supported-method-set />
  </d:prop>
</d:propfind>
XML

            send_propfind(xml)

            assert_equal(207, response.status, "We expected a multi-status response. Full response body: #{response.body_as_string}")

            body = @response.body.gsub(/xmlns(:[A-Za-z0-9_])?=("|')DAV:("|')/) { "xmlns#{Regexp.last_match(1)}=\"urn:DAV\"" }

            xml = LibXML::XML::Document.string(body)

            data = xml.find('/d:multistatus/d:response/d:propstat/d:prop')
            assert_equal(1, data.size, 'We expected 1 \'d:prop\' element')

            data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supported-method-set')
            assert_equal(1, data.size, 'We expected 1 \'d:supported-method-set\' element')

            data = xml.find('/d:multistatus/d:response/d:propstat/d:status')
            assert_equal(1, data.size, 'We expected 1 \'d:status\' element')

            assert_equal('HTTP/1.1 200 OK', data[0].content, 'The status for this property should have been 200')
          end

          def test_get_obj
            result = server.properties('/', ['{DAV:}supported-method-set'])
            assert(result['{DAV:}supported-method-set'].has('PROPFIND'))
          end
        end
      end
    end
  end
end
