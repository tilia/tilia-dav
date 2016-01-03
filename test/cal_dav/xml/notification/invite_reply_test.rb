require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Notification
        class InviteReplyTest < Minitest::Test
          def test_serializers
            data_provider.each do |data|
              (notification, expected) = data

              notification = InviteReply.new(notification)

              assert_equal('foo', notification.id)
              assert_equal('"1"', notification.etag)

              simple_expected = '<?xml version="1.0"?>' + "\n" + '<cs:root xmlns:cs="http://calendarserver.org/ns/"><cs:invite-reply/></cs:root>'

              writer = Tilia::Xml::Writer.new
              writer.namespace_map = {
                'http://calendarserver.org/ns/' => 'cs'
              }
              writer.open_memory
              writer.start_document
              writer.start_element('{http://calendarserver.org/ns/}root')
              writer.write(notification)
              writer.end_element

              assert_equal(simple_expected, writer.output_memory)

              writer = Tilia::Xml::Writer.new
              writer.context_uri = '/'
              writer.namespace_map = {
                'http://calendarserver.org/ns/' => 'cs',
                'DAV:' => 'd'
              }
              writer.open_memory
              writer.start_document
              writer.start_element('{http://calendarserver.org/ns/}root')
              notification.xml_serialize_full(writer)
              writer.end_element

              assert_xml_equal(expected, writer.output_memory)
            end
          end

          def data_provider
            utc = ActiveSupport::TimeZone.new('UTC')
            dt_stamp = utc.parse('2012-01-01 00:00:00')

            [
              [
                {
                  'id' => 'foo',
                  'dtStamp' => dt_stamp,
                  'etag' => '"1"',
                  'inReplyTo' => 'bar',
                  'href' => 'mailto:foo@example.org',
                  'type' => SharingPlugin::STATUS_ACCEPTED,
                  'hostUrl' => 'calendar'
                },
                <<FOO
<?xml version="1.0" encoding="UTF-8"?>
<cs:root xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:">
  <cs:dtstamp>20120101T000000Z</cs:dtstamp>
  <cs:invite-reply>
    <cs:uid>foo</cs:uid>
    <cs:in-reply-to>bar</cs:in-reply-to>
    <d:href>mailto:foo@example.org</d:href>
    <cs:invite-accepted/>
    <cs:hosturl>
      <d:href>/calendar</d:href>
    </cs:hosturl>
  </cs:invite-reply>
</cs:root>

FOO
              ],
              [
                {
                  'id' => 'foo',
                  'dtStamp' => dt_stamp,
                  'etag' => '"1"',
                  'inReplyTo' => 'bar',
                  'href' => 'mailto:foo@example.org',
                  'type' => SharingPlugin::STATUS_DECLINED,
                  'hostUrl' => 'calendar',
                  'summary' => 'Summary!'
                },
                <<FOO
<?xml version="1.0" encoding="UTF-8"?>
<cs:root xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:">
  <cs:dtstamp>20120101T000000Z</cs:dtstamp>
  <cs:invite-reply>
    <cs:uid>foo</cs:uid>
    <cs:in-reply-to>bar</cs:in-reply-to>
    <d:href>mailto:foo@example.org</d:href>
    <cs:invite-declined/>
    <cs:hosturl>
      <d:href>/calendar</d:href>
    </cs:hosturl>
    <cs:summary>Summary!</cs:summary>
  </cs:invite-reply>
</cs:root>

FOO
              ]
            ]
          end

          def test_missing_arg
            assert_raises(ArgumentError) do
              InviteReply.new({})
            end
          end

          def test_unknown_arg
            assert_raises(ArgumentError) do
              InviteReply.new(
                'foo-i-will-break' => true,

                'id' => 1,
                'etag' => '"bla"',
                'href' => 'abc',
                'dtStamp' => 'def',
                'inReplyTo' => 'qrs',
                'type' => 'ghi',
                'hostUrl' => 'jkl'
              )
            end
          end
        end
      end
    end
  end
end
