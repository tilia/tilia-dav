module Tilia
  module CalDav
    module Schedule
      # iMIP handler.
      #
      # This class is responsible for sending out iMIP messages. iMIP is the
      # email-based transport for iTIP. iTIP deals with scheduling operations for
      # iCalendar objects.
      #
      # If you want to customize the email that gets sent out, you can do so by
      # extending this class and overriding the sendMessage method.
      class IMipPlugin < Dav::ServerPlugin
        # @!attribute [r] sender_email
        #   @!visibility private
        #   Email address used in From: header.
        #
        #   @var string

        # @!attribute [r] itip_message
        #   @!visibility private
        #   ITipMessage
        #
        #   @var ITip\Message

        # Creates the email handler.
        #
        # @param string sender_email. The 'senderEmail' is the email that shows up
        #                             in the 'From:' address. This should
        #                             generally be some kind of no-reply email
        #                             address you own.
        def initialize(sender_email)
          @sender_email = sender_email
        end

        # This initializes the plugin.
        #
        # This function is called by Sabre\DAV\Server, after
        # addPlugin is called.
        #
        # This method should set up the required event subscriptions.
        #
        # @param DAV\Server server
        # @return void
        def setup(server)
          server.on('schedule', method(:schedule), 120)
        end

        # Returns a plugin name.
        #
        # Using this name other plugins will be able to access other plugins
        # using \Sabre\DAV\Server::getPlugin
        #
        # @return string
        def plugin_name
          'imip'
        end

        # Event handler for the 'schedule' event.
        #
        # @param ITip\Message i_tip_message
        # @return void
        def schedule(i_tip_message)
          # Not sending any emails if the system considers the update
          # insignificant.
          unless i_tip_message.significant_change
            unless i_tip_message.schedule_status
              i_tip_message.schedule_status = '1.0;We got the message, but it\'s not significant enough to warrant an email'
            end
            return nil
          end

          summary = i_tip_message.message['VEVENT']['SUMMARY'].to_s

          return nil unless Uri.parse(i_tip_message.sender)['scheme'] == 'mailto'
          return nil unless Uri.parse(i_tip_message.recipient)['scheme'] == 'mailto'

          sender = i_tip_message.sender[7..-1]
          recipient = i_tip_message.recipient[7..-1]

          sender = "#{i_tip_message.sender_name} <#{sender}>" if i_tip_message.sender_name
          recipient = "#{i_tip_message.recipient_name} <#{recipient}>" if i_tip_message.recipient_name

          subject = 'SabreDAV iTIP message'
          case i_tip_message.method.upcase
          when 'REPLY'
            subject = 'Re: ' + summary
          when 'REQUEST'
            subject = summary
          when 'CANCEL'
            subject = 'Cancelled: ' + summary
          end

          headers = {
            'Reply-To' => sender,
            'From' => @sender_email,
            'Content-Type' => "text/calendar; charset=UTF-8; method=#{i_tip_message.method}"
          }

          headers['X-Sabre-Version'] = Dav::Version::VERSION if Dav::Server.expose_version

          mail(
            recipient,
            subject,
            i_tip_message.message.serialize,
            headers
          )
          i_tip_message.schedule_status = '1.1; Scheduling message is sent via iMip'
        end

        protected

        # This is deemed untestable in a reasonable manner

        # This function is responsible for sending the actual email.
        #
        # @param string to Recipient email address
        # @param string subject Subject of the email
        # @param string body iCalendar body
        # @param array headers List of headers
        # @return void
        def mail(to, subject, body, headers)
          headers['to'] = to

          mail = Mail.new
          mail.subject = subject
          mail.body = body

          headers.each do |_key, value|
            mail[header] = value
          end

          mail.deliver!
        end

        public

        # Returns a bunch of meta-data about the plugin.
        #
        # Providing this information is optional, and is mainly displayed by the
        # Browser plugin.
        #
        # The description key in the returned array may contain html and will not
        # be sanitized.
        #
        # @return array
        def plugin_info
          {
            'name'        => plugin_name,
            'description' => 'Email delivery (rfc6037) for CalDAV scheduling',
            'link'        => 'http://sabre.io/dav/scheduling/'
          }
        end
      end
    end
  end
end
