module Tilia
  module Dav
    module Xml
      module Element
        # This class is responsible for decoding the {DAV:}prop element as it appears
        # in {DAV:}property-update.
        #
        # This class doesn't return an instance of itself. It just returns a
        # key.value array.
        class Prop
          include Tilia::Xml::XmlDeserializable

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
            # If there's no children, we don't do anything.
            if reader.empty_element?
              reader.next
              return {}
            end

            values = {}

            reader.read
            loop do
              if reader.node_type == ::LibXML::XML::Reader::TYPE_ELEMENT
                clark = reader.clark
                values[clark] = parse_current_element(reader)['value']
              else
                reader.read
              end
              break unless reader.node_type != ::LibXML::XML::Reader::TYPE_END_ELEMENT
            end

            reader.read
            values
          end

          private

          # This function behaves similar to Sabre\Xml\Reader::parseCurrentElement,
          # but instead of creating deep xml array structures, it will turn any
          # top-level element it doesn't recognize into either a string, or an
          # XmlFragment class.
          #
          # This method returns arn array with 2 properties:
          #   * name - A clark-notation XML element name.
          #   * value - The parsed value.
          #
          # @param Reader reader
          # @return array
          def self.parse_current_element(reader)
            name = reader.clark

            if reader.element_map.key?(name)
              deserializer = reader.element_map[name]
              if deserializer.is_a?(Class) && deserializer.include?(Tilia::Xml::XmlDeserializable)
                value = deserializer.xml_deserialize(reader)
              elsif deserializer.is_a? Proc
                value = deserializer.call(reader)
              else
                # Omit php stuff for error creation
                fail "Could not use this type as a deserializer: #{deserializer.inspect}"
              end
            else
              value = Property::Complex.xml_deserialize(reader)
            end

            { 'name' => name, 'value' => value }
          end
        end
      end
    end
  end
end
