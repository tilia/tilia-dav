require 'test_helper'

module Tilia
  module CalDav
    module Schedule
      class IMipPluginTest < Minitest::Test
        def test_get_plugin_info
          plugin = IMipPlugin.new('system@example.com')
          assert_equal(
            'imip',
            plugin.plugin_info['name']
          )
        end

        def test_deliver_reply
          message = VObject::ITip::Message.new
          message.sender = 'mailto:sender@example.org'
          message.sender_name = 'Sender'
          message.recipient = 'mailto:recipient@example.org'
          message.recipient_name = 'Recipient'
          message.method = 'REPLY'

          ics = <<ICS
BEGIN:VCALENDAR\r
METHOD:REPLY\r
BEGIN:VEVENT\r
SUMMARY:Birthday party\r
END:VEVENT\r
END:VCALENDAR\r
ICS

          message.message = VObject::Reader.read(ics)

          result = schedule(message)

          expected = [
            {
              'to' => 'Recipient <recipient@example.org>',
              'subject' => 'Re: Birthday party',
              'body' => ics,
              'headers' => {
                'Reply-To' => 'Sender <sender@example.org>',
                'From' => 'system@example.org',
                'Content-Type' => 'text/calendar; charset=UTF-8; method=REPLY',
                'X-Sabre-Version' => Dav::Version::VERSION
              }
            }
          ]

          assert_equal(expected, result)
        end

        def test_deliver_reply_no_mailto
          message = VObject::ITip::Message.new
          message.sender = 'mailto:sender@example.org'
          message.sender_name = 'Sender'
          message.recipient = 'http://example.org/recipient'
          message.recipient_name = 'Recipient'
          message.method = 'REPLY'

          ics = <<ICS
BEGIN:VCALENDAR\r
METHOD:REPLY\r
BEGIN:VEVENT\r
SUMMARY:Birthday party\r
END:VEVENT\r
END:VCALENDAR\r

ICS

          message.message = VObject::Reader.read(ics)

          result = schedule(message)

          expected = []

          assert_equal(expected, result)
        end

        def test_deliver_request
          message = VObject::ITip::Message.new
          message.sender = 'mailto:sender@example.org'
          message.sender_name = 'Sender'
          message.recipient = 'mailto:recipient@example.org'
          message.recipient_name = 'Recipient'
          message.method = 'REQUEST'

          ics = <<ICS
BEGIN:VCALENDAR\r
METHOD:REQUEST\r
BEGIN:VEVENT\r
SUMMARY:Birthday party\r
END:VEVENT\r
END:VCALENDAR\r
ICS

          message.message = VObject::Reader.read(ics)

          result = schedule(message)

          expected = [
            {
              'to' => 'Recipient <recipient@example.org>',
              'subject' => 'Birthday party',
              'body' => ics,
              'headers' => {
                'Reply-To' => 'Sender <sender@example.org>',
                'From' => 'system@example.org',
                'Content-Type' => 'text/calendar; charset=UTF-8; method=REQUEST',
                'X-Sabre-Version' => Dav::Version::VERSION
              }
            }
          ]

          assert_equal(expected, result)
        end

        def test_deliver_cancel
          message = VObject::ITip::Message.new
          message.sender = 'mailto:sender@example.org'
          message.sender_name = 'Sender'
          message.recipient = 'mailto:recipient@example.org'
          message.recipient_name = 'Recipient'
          message.method = 'CANCEL'

          ics = <<ICS
BEGIN:VCALENDAR\r
METHOD:CANCEL\r
BEGIN:VEVENT\r
SUMMARY:Birthday party\r
END:VEVENT\r
END:VCALENDAR\r
ICS

          message.message = VObject::Reader.read(ics)

          result = schedule(message)

          expected = [
            {
              'to' => 'Recipient <recipient@example.org>',
              'subject' => 'Cancelled: Birthday party',
              'body' => ics,
              'headers' => {
                'Reply-To' => 'Sender <sender@example.org>',
                'From' => 'system@example.org',
                'Content-Type' => 'text/calendar; charset=UTF-8; method=CANCEL',
                'X-Sabre-Version' => Dav::Version::VERSION
              }
            }
          ]

          assert_equal(expected, result)
          assert_equal('1.1', message.schedule_status[0..2])
        end

        def schedule(message)
          plugin = IMip::MockPlugin.new('system@example.org')

          server = Dav::ServerMock.new
          server.add_plugin(plugin)
          server.emit('schedule', [message])

          plugin.sent_emails
        end

        def test_deliver_insignificant_request
          message = VObject::ITip::Message.new
          message.sender = 'mailto:sender@example.org'
          message.sender_name = 'Sender'
          message.recipient = 'mailto:recipient@example.org'
          message.recipient_name = 'Recipient'
          message.method = 'REQUEST'
          message.significant_change = false

          ics = <<ICS
BEGIN:VCALENDAR\r
METHOD:REQUEST\r
BEGIN:VEVENT\r
SUMMARY:Birthday party\r
END:VEVENT\r
END:VCALENDAR\r
ICS

          message.message = VObject::Reader.read(ics)

          result = schedule(message)

          expected = []
          assert_equal(expected, result)
          assert_equal('1.0', message.schedule_status[0..2])
        end
      end
    end
  end
end
