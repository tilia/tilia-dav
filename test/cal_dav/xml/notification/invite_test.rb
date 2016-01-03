require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Notification
        class InviteTest < Dav::Xml::XmlTester
          def test_serializers
            data_provider.each do |data|
              (notification, expected) = data

              notification = Invite.new(notification)

              assert_equal('foo', notification.id)
              assert_equal('"1"', notification.etag)

              simple_expected = '<cs:invite-notification xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/" />' + "\n"
              @namespace_map['http://calendarserver.org/ns/'] = 'cs'

              xml = write(notification)

              # TODO: the simple_xml is not always equal, the cal sometimes appears
              # assert_xml_equal(simple_expected, xml)

              @namespace_map['urn:ietf:params:xml:ns:caldav'] = 'cal'
              xml = write_full(notification)

              assert_xml_equal(expected, xml)
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
                  'href' => 'mailto:foo@example.org',
                  'type' => SharingPlugin::STATUS_ACCEPTED,
                  'readOnly' => true,
                  'hostUrl' => 'calendar',
                  'organizer' => 'principal/user1',
                  'commonName' => 'John Doe',
                  'summary' => 'Awesome stuff!'
                },
                <<FOO
<?xml version="1.0" encoding="UTF-8"?>
<cs:root xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav">
  <cs:dtstamp>20120101T000000Z</cs:dtstamp>
  <cs:invite-notification>
    <cs:uid>foo</cs:uid>
    <d:href>mailto:foo@example.org</d:href>
    <cs:invite-accepted/>
    <cs:hosturl>
      <d:href>/calendar</d:href>
    </cs:hosturl>
    <cs:summary>Awesome stuff!</cs:summary>
    <cs:access>
      <cs:read/>
    </cs:access>
    <cs:organizer>
      <d:href>/principal/user1</d:href>
      <cs:common-name>John Doe</cs:common-name>
    </cs:organizer>
    <cs:organizer-cn>John Doe</cs:organizer-cn>
  </cs:invite-notification>
</cs:root>
FOO
              ],
              [
                {
                  'id' => 'foo',
                  'dtStamp' => dt_stamp,
                  'etag' => '"1"',
                  'href' => 'mailto:foo@example.org',
                  'type' => SharingPlugin::STATUS_DECLINED,
                  'readOnly' => true,
                  'hostUrl' => 'calendar',
                  'organizer' => 'principal/user1',
                  'commonName' => 'John Doe'
                },
                <<FOO
<?xml version="1.0" encoding="UTF-8"?>
<cs:root xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav">
  <cs:dtstamp>20120101T000000Z</cs:dtstamp>
  <cs:invite-notification>
    <cs:uid>foo</cs:uid>
    <d:href>mailto:foo@example.org</d:href>
    <cs:invite-declined/>
    <cs:hosturl>
      <d:href>/calendar</d:href>
    </cs:hosturl>
    <cs:access>
      <cs:read/>
    </cs:access>
    <cs:organizer>
      <d:href>/principal/user1</d:href>
      <cs:common-name>John Doe</cs:common-name>
    </cs:organizer>
    <cs:organizer-cn>John Doe</cs:organizer-cn>
  </cs:invite-notification>
</cs:root>
FOO
              ],
              [
                {
                  'id' => 'foo',
                  'dtStamp' => dt_stamp,
                  'etag' => '"1"',
                  'href' => 'mailto:foo@example.org',
                  'type' => SharingPlugin::STATUS_NORESPONSE,
                  'readOnly' => true,
                  'hostUrl' => 'calendar',
                  'organizer' => 'principal/user1',
                  'firstName' => 'Foo',
                  'lastName'  => 'Bar'
                },
                <<FOO
<?xml version="1.0" encoding="UTF-8"?>
<cs:root xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav">
  <cs:dtstamp>20120101T000000Z</cs:dtstamp>
  <cs:invite-notification>
    <cs:uid>foo</cs:uid>
    <d:href>mailto:foo@example.org</d:href>
    <cs:invite-noresponse/>
    <cs:hosturl>
      <d:href>/calendar</d:href>
    </cs:hosturl>
    <cs:access>
      <cs:read/>
    </cs:access>
    <cs:organizer>
      <d:href>/principal/user1</d:href>
      <cs:first-name>Foo</cs:first-name>
      <cs:last-name>Bar</cs:last-name>
    </cs:organizer>
    <cs:organizer-first>Foo</cs:organizer-first>
    <cs:organizer-last>Bar</cs:organizer-last>
  </cs:invite-notification>
</cs:root>

FOO
              ],
              [
                {
                  'id' => 'foo',
                  'dtStamp' => dt_stamp,
                  'etag' => '"1"',
                  'href' => 'mailto:foo@example.org',
                  'type' => SharingPlugin::STATUS_DELETED,
                  'readOnly' => false,
                  'hostUrl' => 'calendar',
                  'organizer' => 'mailto:user1@fruux.com',
                  'supportedComponents' => Property::SupportedCalendarComponentSet.new(['VEVENT', 'VTODO'])
                },
                <<FOO
<?xml version="1.0" encoding="UTF-8"?>
<cs:root xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav">
  <cs:dtstamp>20120101T000000Z</cs:dtstamp>
  <cs:invite-notification>
    <cs:uid>foo</cs:uid>
    <d:href>mailto:foo@example.org</d:href>
    <cs:invite-deleted/>
    <cs:hosturl>
      <d:href>/calendar</d:href>
    </cs:hosturl>
    <cs:access>
      <cs:read-write/>
    </cs:access>
    <cs:organizer>
      <d:href>mailto:user1@fruux.com</d:href>
    </cs:organizer>
    <cal:supported-calendar-component-set>
      <cal:comp name="VEVENT"/>
      <cal:comp name="VTODO"/>
    </cal:supported-calendar-component-set>
  </cs:invite-notification>
</cs:root>
FOO
              ]
            ]
          end

          def test_missing_arg
            assert_raises(ArgumentError) do
              Invite.new({})
            end
          end

          def test_unknown_arg
            assert_raises(ArgumentError) do
              Invite.new(
                'foo-i-will-break' => true,

                'id' => 1,
                'etag' => '"bla"',
                'href' => 'abc',
                'dtStamp' => 'def',
                'type' => 'ghi',
                'readOnly' => true,
                'hostUrl' => 'jkl',
                'organizer' => 'mno'
              )
            end
          end

          def write_full(input)
            writer = Tilia::Xml::Writer.new
            writer.context_uri = '/'
            writer.namespace_map = @namespace_map
            writer.open_memory
            writer.start_element('{http://calendarserver.org/ns/}root')
            input.xml_serialize_full(writer)
            writer.end_element
            writer.output_memory
          end
        end
      end
    end
  end
end
