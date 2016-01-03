module Tilia
  module Dav
    module Xml
      module Request
        # WebDAV PROPPATCH request parser.
        #
        # This class parses the {DAV:}propertyupdate request, as defined in:
        #
        # https://tools.ietf.org/html/rfc4918#section-14.20
        class PropPatch
          include Tilia::Xml::Element

          # The list of properties that will be updated and removed.
          #
          # If a property will be removed, it's value will be set to null.
          #
          # @var array
          attr_accessor :properties

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
            properties.each do |property_name, property_value|
              if property_value.nil?
                writer.start_element('{DAV:}remove')
                writer.write('{DAV:}prop' => { property_name => property_value })
                writer.end_element
              else
                writer.start_element('{DAV:}set')
                writer.write('{DAV:}prop' => { property_name => property_value })
                writer.end_element
              end
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
            instance = new

            element_map = reader.element_map
            element_map['{DAV:}prop']   = Tilia::Dav::Xml::Element::Prop
            element_map['{DAV:}set']    = Tilia::Xml::Element::KeyValue
            element_map['{DAV:}remove'] = Tilia::Xml::Element::KeyValue

            elems = reader.parse_inner_tree(element_map)

            elems.each do |elem|
              if elem['name'] == '{DAV:}set'
                instance.properties.merge! elem['value']['{DAV:}prop']
              elsif elem['name'] == '{DAV:}remove'
                # Ensuring there are no values.
                elem['value']['{DAV:}prop'].each do |remove, _value|
                  instance.properties[remove] = nil
                end
              end
            end

            instance
          end

          def initialize
            @properties = {}
          end
        end
      end
    end
  end
end
