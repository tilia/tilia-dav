require 'test_helper'

module Tilia
  module Dav
    module Xml
      module Property
        class SupportedReportSetTest < AbstractServer
          def send_propfind(body)
            server_vars = {
              'REQUEST_PATH'        => '/',
              'REQUEST_METHOD'      => 'PROPFIND',
              'HTTP_DEPTH'          => '0'
            }

            request = Http::Sapi.create_from_server_array(server_vars)
            request.body = body

            server.http_request = request
            server.exec
          end

          def test_no_reports
            xml = <<XML
<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:supported-report-set />
  </d:prop>
</d:propfind>
XML

            send_propfind(xml)

            assert_equal(207, @response.status, "We expected a multi-status response. Full response body: #{@response.body}")

            body = @response.body.gsub(/xmlns(:[A-Za-z0-9_])?=("|')DAV:("|')/) { "xmlns#{Regexp.last_match(1)}=\"urn:DAV\"" }

            xml = LibXML::XML::Document.string(body)

            data = xml.find('/d:multistatus/d:response/d:propstat/d:prop')
            assert_equal(1, data.size, 'We expected 1 \'d:prop\' element')

            data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supported-report-set')
            assert_equal(1, data.size, 'We expected 1 \'d:supported-report-set\' element')

            data = xml.find('/d:multistatus/d:response/d:propstat/d:status')
            assert_equal(1, data.size, 'We expected 1 \'d:status\' element')

            assert_equal('HTTP/1.1 200 OK', data[0].content, 'The status for this property should have been 200')
          end

          def test_custom_report
            # Intercepting the report property
            server.on(
              'propFind',
              lambda do |prop_find, _node|
                if prop = prop_find.get('{DAV:}supported-report-set')
                  prop.add_report('{http://www.rooftopsolutions.nl/testnamespace}myreport')
                  prop.add_report('{DAV:}anotherreport')
                end
              end,
              200
            )

            xml = <<XML
<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:supported-report-set />
  </d:prop>
</d:propfind>
XML

            send_propfind(xml)

            assert_equal(207, @response.status, "We expected a multi-status response. Full response body: #{@response.body}")

            body = @response.body.gsub(/xmlns(:[A-Za-z0-9_])?=("|')DAV:("|')/) { "xmlns#{Regexp.last_match(1)}=\"urn:DAV\"" }

            xml = LibXML::XML::Document.string(body)

            data = xml.find('/d:multistatus/d:response/d:propstat/d:prop')
            assert_equal(1, data.size, 'We expected 1 \'d:prop\' element')

            data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supported-report-set')
            assert_equal(1, data.size, 'We expected 1 \'d:supported-report-set\' element')

            data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supported-report-set/d:supported-report')
            assert_equal(2, data.size, 'We expected 2 \'d:supported-report\' elements')

            data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supported-report-set/d:supported-report/d:report')
            assert_equal(2, data.size, 'We expected 2 \'d:report\' elements')

            data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supported-report-set/d:supported-report/d:report/x:myreport', 'x:http://www.rooftopsolutions.nl/testnamespace')
            assert_equal(1, data.size, "We expected 1 'x:myreport' element. Full body: #{@response.body_as_string}")

            data = xml.find('/d:multistatus/d:response/d:propstat/d:prop/d:supported-report-set/d:supported-report/d:report/d:anotherreport')
            assert_equal(1, data.size, "We expected 1 \'d:anotherreport\' element. Full body: #{@response.body_as_string}")

            data = xml.find('/d:multistatus/d:response/d:propstat/d:status')
            assert_equal(1, data.size, 'We expected 1 \'d:status\' element')

            assert_equal('HTTP/1.1 200 OK', data[0].content, 'The status for this property should have been 200')
          end
        end
      end
    end
  end
end
