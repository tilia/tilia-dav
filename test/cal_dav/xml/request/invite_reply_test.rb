require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Request
        class InviteReplyTest < Dav::Xml::XmlTester
          def setup
            super
            @element_map['{http://calendarserver.org/ns/}invite-reply'] = InviteReply
          end

          def test_deserialize
            xml = <<XML
<?xml version="1.0"?>
<cs:invite-reply xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:">
    <d:href>/principal/1</d:href>
    <cs:hosturl><d:href>/calendar/1</d:href></cs:hosturl>
    <cs:invite-accepted />
    <cs:in-reply-to>blabla</cs:in-reply-to>
    <cs:summary>Summary</cs:summary>
</cs:invite-reply>
XML

            result = parse(xml)
            invite_reply = InviteReply.new('/principal/1', '/calendar/1', 'blabla', 'Summary', SharingPlugin::STATUS_ACCEPTED)

            assert_instance_equal(invite_reply, result['value'])
          end

          def test_deserialize_declined
            xml = <<XML
<?xml version="1.0"?>
<cs:invite-reply xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:">
    <d:href>/principal/1</d:href>
    <cs:hosturl><d:href>/calendar/1</d:href></cs:hosturl>
    <cs:invite-declined />
    <cs:in-reply-to>blabla</cs:in-reply-to>
    <cs:summary>Summary</cs:summary>
</cs:invite-reply>
XML

            result = parse(xml)
            invite_reply = InviteReply.new('/principal/1', '/calendar/1', 'blabla', 'Summary', SharingPlugin::STATUS_DECLINED)

            assert_instance_equal(invite_reply, result['value'])
          end

          def test_deserialize_no_host_url
            xml = <<XML
<?xml version="1.0"?>
<cs:invite-reply xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:">
    <d:href>/principal/1</d:href>
    <cs:invite-declined />
    <cs:in-reply-to>blabla</cs:in-reply-to>
    <cs:summary>Summary</cs:summary>
</cs:invite-reply>
XML

            assert_raises(Dav::Exception::BadRequest) do
              parse(xml)
            end
          end
        end
      end
    end
  end
end
