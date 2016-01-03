module Tilia
  module CalDav
    module Xml
      module Notification
        # This class represents the cs:invite-reply notification element.
        class InviteReply
          include NotificationInterface

          # A unique id for the message
          #
          # @var string
          # protected id

          # @!attribute [r] dt_stamp
          #   @!visibility private
          #   Timestamp of the notification
          #
          #   @var DateTime

          # @!attribute [r] in_reply_to
          #   @!visibility private
          #   The unique id of the notification this was a reply to.
          #
          #   @var string

          # @!attribute [r] href
          #   @!visibility private
          #   A url to the recipient of the original (!) notification.
          #
          #   @var string

          # @!attribute [r] type
          #   @!visibility private
          #   The type of message, see the SharingPlugin::STATUS_ constants.
          #
          #   @var int

          # @!attribute [r] host_url
          #   @!visibility private
          #   A url to the shared calendar.
          #
          #   @var string

          # @!attribute [r] summary
          #   @!visibility private
          #   A description of the share request
          #
          #   @var string

          # Notification Etag
          #
          # @var string
          # protected etag

          # Creates the Invite Reply Notification.
          #
          # This constructor receives an array with the following elements:
          #
          #   * id           - A unique id
          #   * etag         - The etag
          #   * dtStamp      - A DateTime object with a timestamp for the notification.
          #   * inReplyTo    - This should refer to the 'id' of the notification
          #                    this is a reply to.
          #   * type         - The type of notification, see SharingPlugin::STATUS_*
          #                    constants for details.
          #   * hostUrl      - A url to the shared calendar.
          #   * summary      - Description of the share, can be the same as the
          #                    calendar, but may also be modified (optional).
          #
          # @param array values
          def initialize(values)
            required = [
              'id',
              'etag',
              'href',
              'dtStamp',
              'inReplyTo',
              'type',
              'hostUrl'
            ]

            required.each do |item|
              fail ArgumentError, "#{item} is a required constructor option" unless values.key?(item)
            end

            values.each do |key, value|
              key = key.underscore
              fail ArgumentError, "Unknown option: #{key}" unless %w(id dt_stamp in_reply_to href type host_url summary etag).include?(key)
              instance_variable_set("@#{key}".to_sym, value)
            end
          end

          # The xmlSerialize metod is called during xml writing.
          #
          # Use the writer argument to write its own xml serialization.
          #
          # An important note: do _not_ create a parent element. Any element
          # implementing XmlSerializble should only ever write what's considered
          # its 'inner xml'.
          #
          # The parent of the current element is responsible for writing a
          # containing element.
          #
          # This allows serializers to be re-used for different element names.
          #
          # If you are opening new elements, you must also close them again.
          #
          # @param Writer writer
          # @return void
          def xml_serialize(writer)
            writer.write_element("{#{Plugin::NS_CALENDARSERVER}}invite-reply")
          end

          # This method serializes the entire notification, as it is used in the
          # response body.
          #
          # @param Writer writer
          # @return void
          def xml_serialize_full(writer)
            cs = "{#{Plugin::NS_CALENDARSERVER}}"

            writer.write_element(cs + 'dtstamp', @dt_stamp.utc.strftime('%Y%m%dT%H%M%SZ'))

            writer.start_element(cs + 'invite-reply')

            writer.write_element(cs + 'uid', @id)
            writer.write_element(cs + 'in-reply-to', @in_reply_to)
            writer.write_element('{DAV:}href', @href)

            case @type
            when SharingPlugin::STATUS_ACCEPTED
              writer.write_element(cs + 'invite-accepted')
            when SharingPlugin::STATUS_DECLINED
              writer.write_element(cs + 'invite-declined')
            end

            writer.write_element(
              cs + 'hosturl',
              '{DAV:}href' => writer.context_uri + @host_url
            )

            unless @summary.blank?
              writer.write_element(cs + 'summary', @summary)
            end

            writer.end_element # invite-reply
          end

          # Returns a unique id for this notification
          #
          # This is just the base url. This should generally be some kind of unique
          # id.
          #
          # @return string
          attr_reader :id

          # Returns the ETag for this notification.
          #
          # The ETag must be surrounded by literal double-quotes.
          #
          # @return string
          attr_reader :etag
        end
      end
    end
  end
end
