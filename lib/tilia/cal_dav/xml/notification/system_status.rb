module Tilia
  module CalDav
    module Xml
      module Notification
        # SystemStatus notification
        #
        # This notification can be used to indicate to the user that the system is
        # down.
        #
        # @copyright Copyright (C) 2007-2015 fruux GmbH (https://fruux.com/).
        # @author Evert Pot (http://evertpot.com/)
        # @license http://sabre.io/license/ Modified BSD License
        class SystemStatus
          include NotificationInterface

          TYPE_LOW = 1
          TYPE_MEDIUM = 2
          TYPE_HIGH = 3

          # A unique id
          #
          # @var string
          # protected id

          # @!attribute [r] type
          #   @!visibility private
          #   The type of alert. This should be one of the TYPE_ constants.
          #
          #   @var int

          # @!attribute [r] description
          #   @!visibility private
          #   A human-readable description of the problem.
          #
          #   @var string

          # @!attribute [r] href
          #   @!visibility private
          #   A url to a website with more information for the user.
          #
          #   @var string

          # Notification Etag
          #
          # @var string
          # protected etag

          # Creates the notification.
          #
          # Some kind of unique id should be provided. This is used to generate a
          # url.
          #
          # @param string id
          # @param string etag
          # @param int type
          # @param string description
          # @param string href
          def initialize(id, etag, type = TYPE_HIGH, description = nil, href = nil)
            @id = id
            @type = type
            @description = description
            @href = href
            @etag = etag
          end

          # The serialize method is called during xml writing.
          #
          # It should use the writer argument to encode this object into XML.
          #
          # Important note: it is not needed to create the parent element. The
          # parent element is already created, and we only have to worry about
          # attributes, child elements and text (if any).
          #
          # Important note 2: If you are writing any new elements, you are also
          # responsible for closing them.
          #
          # @param Writer writer
          # @return void
          def xml_serialize(writer)
            case @type
            when TYPE_LOW
              type = 'low'
            when TYPE_MEDIUM
              type = 'medium'
            else
              type = 'high'
            end

            writer.start_element("{#{Plugin::NS_CALENDARSERVER}}systemstatus")
            writer.write_attribute('type', type)
            writer.end_element
          end

          # This method serializes the entire notification, as it is used in the
          # response body.
          #
          # @param Writer writer
          # @return void
          def xml_serialize_full(writer)
            cs = "{#{Plugin::NS_CALENDARSERVER}}"
            case @type
            when TYPE_LOW
              type = 'low'
            when TYPE_MEDIUM
              type = 'medium'
            else
              type = 'high'
            end

            writer.start_element(cs + 'systemstatus')
            writer.write_attribute('type', type)

            unless @description.blank?
              writer.write_element(cs + 'description', @description)
            end
            writer.write_element('{DAV:}href', @href) unless @href.blank?

            writer.end_element #  systemstatus
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
