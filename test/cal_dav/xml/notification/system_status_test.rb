require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Notification
        class SystemStatusTest < Minitest::Test
          def test_serializers
            data_provider.each do |data|
              (notification, expected1, expected2) = data

              assert_equal('foo', notification.id)
              assert_equal('"1"', notification.etag)

              writer = Tilia::Xml::Writer.new
              writer.namespace_map = {
                'http://calendarserver.org/ns/' => 'cs'
              }
              writer.open_memory
              writer.start_document
              writer.start_element('{http://calendarserver.org/ns/}root')
              writer.write(notification)
              writer.end_element
              assert_xml_equal(expected1, writer.output_memory)

              writer = Tilia::Xml::Writer.new
              writer.namespace_map = {
                'http://calendarserver.org/ns/' => 'cs',
                'DAV:' => 'd'
              }
              writer.open_memory
              writer.start_document
              writer.start_element('{http://calendarserver.org/ns/}root')
              notification.xml_serialize_full(writer)
              writer.end_element
              assert_xml_equal(expected2, writer.output_memory)
            end
          end

          def data_provider
            [
              [
                SystemStatus.new('foo', '"1"'),
                '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + '<cs:root xmlns:cs="http://calendarserver.org/ns/"><cs:systemstatus type="high"/></cs:root>' + "\n",
                '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + '<cs:root xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:"><cs:systemstatus type="high"/></cs:root>' + "\n"
              ],
              [
                SystemStatus.new('foo', '"1"', SystemStatus::TYPE_MEDIUM, 'bar'),
                '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + '<cs:root xmlns:cs="http://calendarserver.org/ns/"><cs:systemstatus type="medium"/></cs:root>' + "\n",
                '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + '<cs:root xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:"><cs:systemstatus type="medium"><cs:description>bar</cs:description></cs:systemstatus></cs:root>' + "\n"
              ],
              [
                SystemStatus.new('foo', '"1"', SystemStatus::TYPE_LOW, nil, 'http://example.org/'),
                '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + '<cs:root xmlns:cs="http://calendarserver.org/ns/"><cs:systemstatus type="low"/></cs:root>' + "\n",
                '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + '<cs:root xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:"><cs:systemstatus type="low"><d:href>http://example.org/</d:href></cs:systemstatus></cs:root>' + "\n"
              ]
            ]
          end
        end
      end
    end
  end
end
