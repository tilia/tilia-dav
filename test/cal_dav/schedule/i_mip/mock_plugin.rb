module Tilia
  module CalDav
    module Schedule
      module IMip
        # iMIP handler.
        #
        # This class is responsible for sending out iMIP messages. iMIP is the
        # email-based transport for iTIP. iTIP deals with scheduling operations for
        # iCalendar objects.
        #
        # If you want to customize the email that gets sent out, you can do so by
        # extending this class and overriding the sendMessage method.
        class MockPlugin < IMipPlugin
          def initialize(*args)
            super
            @sent_emails = []
          end

          # This function is reponsible for sending the actual email.
          #
          # @param string to Recipient email address
          # @param string subject Subject of the email
          # @param string body iCalendar body
          # @param array headers List of headers
          # @return void
          def mail(to, subject, body, headers)
            @sent_emails << {
              'to' => to,
              'subject' => subject,
              'body' => body,
              'headers' => headers
            }
          end

          attr_reader :sent_emails
        end
      end
    end
  end
end
