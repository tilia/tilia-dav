require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Property
        class InviteTest < Dav::Xml::XmlTester
          def setup
            super
            @namespace_map[Plugin::NS_CALDAV] = 'cal'
            @namespace_map[Plugin::NS_CALENDARSERVER] = 'cs'
          end

          def test_simple
            sccs = Invite.new([])
            assert_kind_of(Invite, sccs)
          end

          def test_serialize
            property = Invite.new(
              [
                {
                  'href' => 'mailto:user1@example.org',
                  'status' => SharingPlugin::STATUS_ACCEPTED,
                  'readOnly' => false
                },
                {
                  'href' => 'mailto:user2@example.org',
                  'commonName' => 'John Doe',
                  'status' => SharingPlugin::STATUS_DECLINED,
                  'readOnly' => true
                },
                {
                  'href' => 'mailto:user3@example.org',
                  'commonName' => 'Joe Shmoe',
                  'status' => SharingPlugin::STATUS_NORESPONSE,
                  'readOnly' => true,
                  'summary' => 'Something, something'
                },
                {
                  'href' => 'mailto:user4@example.org',
                  'commonName' => 'Hoe Boe',
                  'status' => SharingPlugin::STATUS_INVALID,
                  'readOnly' => true
                }
              ],
              'href' => 'mailto:thedoctor@example.org',
              'commonName' => 'The Doctor',
              'firstName' => 'The',
              'lastName' => 'Doctor'
            )

            xml = write('{DAV:}root' => property)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
  <cs:organizer>
    <d:href>mailto:thedoctor@example.org</d:href>
    <cs:common-name>The Doctor</cs:common-name>
    <cs:first-name>The</cs:first-name>
    <cs:last-name>Doctor</cs:last-name>
  </cs:organizer>
  <cs:user>
    <d:href>mailto:user1@example.org</d:href>
    <cs:invite-accepted/>
    <cs:access>
      <cs:read-write/>
    </cs:access>
  </cs:user>
  <cs:user>
    <d:href>mailto:user2@example.org</d:href>
    <cs:common-name>John Doe</cs:common-name>
    <cs:invite-declined/>
    <cs:access>
      <cs:read/>
    </cs:access>
  </cs:user>
  <cs:user>
    <d:href>mailto:user3@example.org</d:href>
    <cs:common-name>Joe Shmoe</cs:common-name>
    <cs:invite-noresponse/>
    <cs:access>
      <cs:read/>
    </cs:access>
    <cs:summary>Something, something</cs:summary>
  </cs:user>
  <cs:user>
    <d:href>mailto:user4@example.org</d:href>
    <cs:common-name>Hoe Boe</cs:common-name>
    <cs:invite-invalid/>
    <cs:access>
      <cs:read/>
    </cs:access>
  </cs:user>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end

          def test_unserialize
            input = [
              {
                'href' => 'mailto:user1@example.org',
                'status' => SharingPlugin::STATUS_ACCEPTED,
                'readOnly' => false,
                'commonName' => nil,
                'summary' => nil
              },
              {
                'href' => 'mailto:user2@example.org',
                'commonName' => 'John Doe',
                'status' => SharingPlugin::STATUS_DECLINED,
                'readOnly' => true,
                'summary' => nil
              },
              {
                'href' => 'mailto:user3@example.org',
                'commonName' => 'Joe Shmoe',
                'status' => SharingPlugin::STATUS_NORESPONSE,
                'readOnly' => true,
                'summary' => 'Something, something'
              },
              {
                'href' => 'mailto:user4@example.org',
                'commonName' => 'Hoe Boe',
                'status' => SharingPlugin::STATUS_INVALID,
                'readOnly' => true,
                'summary' => nil
              }
            ]

            # Creating the xml
            input_property = Invite.new(input)
            xml = write('{DAV:}root' => input_property)
            # Parsing it again

            doc2 = parse(
              xml,
              '{DAV:}root' => Invite
            )

            output_property = doc2['value']

            assert_equal(input, output_property.value)
          end

          def test_unserialize_no_status
            xml = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
  <cs:user>
    <d:href>mailto:user1@example.org</d:href>
    <!-- <cs:invite-accepted/> -->
    <cs:access>
      <cs:read-write/>
    </cs:access>
  </cs:user>
</d:root>
XML

            assert_raises(ArgumentError) do
              parse(
                xml,
                '{DAV:}root' => Invite
              )
            end
          end
        end
      end
    end
  end
end
