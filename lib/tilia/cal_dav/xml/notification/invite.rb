module Tilia
  module CalDav
    module Xml
      module Notification
        # This class represents the cs:invite-notification notification element.
        #
        # This element is defined here:
        # http://svn.calendarserver.org/repository/calendarserver/CalendarServer/trunk/doc/Extensions/caldav-sharing.txt
        class Invite
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

          # @!attribute [r] href
          #   @!visibility private
          #   A url to the recipient of the notification. This can be an email
          #   address (mailto:), or a principal url.
          #
          #   @var string

          # @!attribute [r] type
          #   @!visibility private
          #   The type of message, see the SharingPlugin::STATUS_* constants.
          #
          #   @var int

          # @!attribute [r] read_only
          #   @!visibility private
          #   True if access to a calendar is read-only.
          #
          #   @var bool

          # @!attribute [r] host_url
          #   @!visibility private
          #   A url to the shared calendar.
          #
          #   @var string

          # @!attribute [r] organizer
          #   @!visibility private
          #   Url to the sharer of the calendar
          #
          #   @var string

          # @!attribute [r] common_name
          #   @!visibility private
          #   The name of the sharer.
          #
          #   @var string

          # @!attribute [r] first_name
          #   @!visibility private
          #   The name of the sharer.
          #
          #   @var string

          # @!attribute [r] last_name
          #   @!visibility private
          #   The name of the sharer.
          #
          #   @var string

          # @!attribute [r] summary
          #   @!visibility private
          #   A description of the share request
          #
          #   @var string

          # The Etag for the notification
          #
          # @var string
          # protected etag

          # @!attribute [r] supported_components
          #   @!visibility private
          #   The list of supported components
          #
          #   @var Sabre\CalDAV\Property\SupportedCalendarComponentSet

          # Creates the Invite notification.
          #
          # This constructor receives an array with the following elements:
          #
          #   * id           - A unique id
          #   * etag         - The etag
          #   * dtStamp      - A DateTime object with a timestamp for the notification.
          #   * type         - The type of notification, see SharingPlugin::STATUS_*
          #                    constants for details.
          #   * readOnly     - This must be set to true, if this is an invite for
          #                    read-only access to a calendar.
          #   * hostUrl      - A url to the shared calendar.
          #   * organizer    - Url to the sharer principal.
          #   * commonName   - The real name of the sharer (optional).
          #   * firstName    - The first name of the sharer (optional).
          #   * lastName     - The last name of the sharer (optional).
          #   * summary      - Description of the share, can be the same as the
          #                    calendar, but may also be modified (optional).
          #   * supportedComponents - An instance of
          #                    Sabre\CalDAV\Property\SupportedCalendarComponentSet.
          #                    This allows the client to determine which components
          #                    will be supported in the shared calendar. This is
          #                    also optional.
          #
          # @param array values All the options
          def initialize(values)
            required = [
              'id',
              'etag',
              'href',
              'dtStamp',
              'type',
              'readOnly',
              'hostUrl',
              'organizer'
            ]
            required.each do |item|
              fail ArgumentError, "#{item} is a required constructor option" unless values.key?(item)
            end

            values.each do |key, value|
              key = key.underscore
              fail ArgumentError, "Unknown option: #{key}" unless %w(id dt_stamp href type read_only host_url organizer common_name first_name last_name summary etag supported_components).include?(key)
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
            writer.write_element("{#{Plugin::NS_CALENDARSERVER}}invite-notification")
          end

          # This method serializes the entire notification, as it is used in the
          # response body.
          #
          # @param Writer writer
          # @return void
          def xml_serialize_full(writer)
            cs = "{#{Plugin::NS_CALENDARSERVER}}"

            writer.write_element(cs + 'dtstamp', @dt_stamp.utc.strftime('%Y%m%dT%H%M%SZ'))
            writer.start_element(cs + 'invite-notification')
            writer.write_element(cs + 'uid', @id)
            writer.write_element('{DAV:}href', @href)

            case @type
            when SharingPlugin::STATUS_ACCEPTED
              writer.write_element(cs + 'invite-accepted')
            when SharingPlugin::STATUS_DECLINED
              writer.write_element(cs + 'invite-declined')
            when SharingPlugin::STATUS_DELETED
              writer.write_element(cs + 'invite-deleted')
            when SharingPlugin::STATUS_NORESPONSE
              writer.write_element(cs + 'invite-noresponse')
            end

            writer.write_element(
              cs + 'hosturl',
              '{DAV:}href' => writer.context_uri + @host_url
            )

            unless @summary.blank?
              writer.write_element(cs + 'summary', @summary)
            end

            writer.start_element(cs + 'access')
            if @read_only
              writer.write_element(cs + 'read')
            else
              writer.write_element(cs + 'read-write')
            end
            writer.end_element # access

            writer.start_element(cs + 'organizer')

            # If the organizer contains a 'mailto:' part, it means it should be
            # treated as absolute.
            if @organizer[0, 7].downcase == 'mailto:'
              writer.write_element('{DAV:}href', @organizer)
            else
              writer.write_element('{DAV:}href', writer.context_uri + @organizer)
            end

            unless @common_name.blank?
              writer.write_element(cs + 'common-name', @common_name)
            end
            unless @first_name.blank?
              writer.write_element(cs + 'first-name', @first_name)
            end
            unless @last_name.blank?
              writer.write_element(cs + 'last-name', @last_name)
            end
            writer.end_element # organizer

            unless @common_name.blank?
              writer.write_element(cs + 'organizer-cn', @common_name)
            end
            unless @first_name.blank?
              writer.write_element(cs + 'organizer-first', @first_name)
            end
            unless @last_name.blank?
              writer.write_element(cs + 'organizer-last', @last_name)
            end
            unless @supported_components.blank?
              writer.write_element("{#{Plugin::NS_CALDAV}}supported-calendar-component-set", @supported_components)
            end

            writer.end_element # invite-notification
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
