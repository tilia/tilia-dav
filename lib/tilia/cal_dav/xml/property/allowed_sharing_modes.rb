module Tilia
  module CalDav
    module Xml
      module Property
        # AllowedSharingModes
        #
        # This property encodes the 'allowed-sharing-modes' property, as defined by
        # the 'caldav-sharing-02' spec, in the http://calendarserver.org/ns/
        # namespace.
        #
        # This property is a representation of the supported-calendar_component-set
        # property in the CalDAV namespace. It simply requires an array of components,
        # such as VEVENT, VTODO
        class AllowedSharingModes
          include Tilia::Xml::XmlSerializable

          # @!attribute [r] can_be_shared
          #   @!visibility private
          #   Whether or not a calendar can be shared with another user
          #
          #   @var bool

          # @!attribute [r] can_be_published
          #   @!visibility private
          #   Whether or not the calendar can be placed on a public url.
          #
          #   @var bool

          # Constructor
          #
          # @param bool can_be_shared
          # @param bool can_be_published
          # @return void
          def initialize(can_be_shared, can_be_published)
            @can_be_shared = can_be_shared
            @can_be_published = can_be_published
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
            writer.write_element("{#{Plugin::NS_CALENDARSERVER}}can-be-shared") if @can_be_shared
            writer.write_element("{#{Plugin::NS_CALENDARSERVER}}can-be-published") if @can_be_published
          end
        end
      end
    end
  end
end
