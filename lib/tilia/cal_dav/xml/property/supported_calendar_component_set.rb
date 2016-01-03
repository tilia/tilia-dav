module Tilia
  module CalDav
    module Xml
      module Property
        # SupportedCalendarComponentSet property.
        #
        # This class represents the
        # {urn:ietf:params:xml:ns:caldav}supported-calendar-component-set property, as
        # defined in:
        #
        # https://tools.ietf.org/html/rfc4791#section-5.2.3
        class SupportedCalendarComponentSet
          include Tilia::Xml::Element

          # @!attribute [r] components
          #   @!visibility private
          #   List of supported components.
          #
          #   This array will contain values such as VEVENT, VTODO and VJOURNAL.
          #
          #   @var array

          # Creates the property.
          #
          # @param array components
          def initialize(components)
            @components = components
          end

          # Returns the list of supported components
          #
          # @return array
          def value
            @components
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
            @components.each do |component|
              writer.start_element("{#{Plugin::NS_CALDAV}}comp")
              writer.write_attributes('name' => component)
              writer.end_element
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
            elems = reader.parse_inner_tree || []

            components = []

            elems.each do |elem|
              components << elem['attributes']['name'] if elem['name'] == "{#{Plugin::NS_CALDAV}}comp"
            end

            if components.empty?
              fail Tilia::Xml::ParseException, 'supported-calendar-component-set must have at least one CALDAV:comp element'
            end

            new(components)
          end
        end
      end
    end
  end
end
