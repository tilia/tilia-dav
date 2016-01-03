module Tilia
  module CalDav
    module Xml
      module Property
        # schedule-calendar-transp property.
        #
        # This property is a representation of the schedule-calendar-transp property.
        # This property is defined in:
        #
        # http://tools.ietf.org/html/rfc6638#section-9.1
        #
        # Its values are either 'transparent' or 'opaque'. If it's transparent, it
        # means that this calendar will not be taken into consideration when a
        # different user queries for free-busy information. If it's 'opaque', it will.
        class ScheduleCalendarTransp
          include Tilia::Xml::Element

          TRANSPARENT = 'transparent'
          OPAQUE = 'opaque'

          # value
          #
          # @var string
          # protected value

          # Creates the property
          #
          # @param string value
          def initialize(value)
            if value != TRANSPARENT && value != OPAQUE
              fail ArgumentError, 'The value must either be specified as "transparent" or "opaque"'
            end
            @value = value
          end

          # Returns the current value
          #
          # @return string
          attr_reader :value

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
            case @value
            when TRANSPARENT
              writer.write_element("{#{Plugin::NS_CALDAV}}transparent")
            when OPAQUE
              writer.write_element("{#{Plugin::NS_CALDAV}}opaque")
            end
          end

          # The deserialize method is called during xml parsing.
          #
          # This method is called statictly, this is because in theory this method
          # may be used as a type of constructor, or factory method.
          #
          # Often you want to return an instance of the current class, but you are
          # free to return other data as well.
          #
          # You are responsible for advancing the reader to the next element. Not
          # doing anything will result in a never-ending loop.
          #
          # If you just want to skip parsing for this element altogether, you can
          # just call reader.next
          #
          # reader.parse_inner_tree will parse the entire sub-tree, and advance to
          # the next element.
          #
          # @param Reader reader
          # @return mixed
          def self.xml_deserialize(reader)
            elems = Tilia::Xml::Element::Elements.xml_deserialize(reader)

            value = nil

            elems.each do |elem|
              case elem
              when "{#{Plugin::NS_CALDAV}}opaque"
                value = OPAQUE
              when "{#{Plugin::NS_CALDAV}}transparent"
                value = TRANSPARENT
              end
            end

            return nil unless value

            new(value)
          end
        end
      end
    end
  end
end
