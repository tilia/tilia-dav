module Tilia
  module Dav
    module Xml
      module Property
        # This class represents a 'complex' property that didn't have a default
        # decoder.
        #
        # It's basically a container for an xml snippet.
        class Complex < Tilia::Xml::Element::XmlFragment
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
            xml = reader.read_inner_xml

            if reader.node_type == ::LibXML::XML::Reader::TYPE_ELEMENT && reader.empty_element?
              # Easy!
              reader.next
              return nil
            end

            # Now we have a copy of the inner xml, we need to traverse it to get
            # all the strings. If there's no non-string data, we just return the
            # string, otherwise we return an instance of this class.
            reader.read

            non_text = false
            text = ''

            loop do
              case reader.node_type
              when ::LibXML::XML::Reader::TYPE_ELEMENT
                non_text = true
                reader.next
                next
              when ::LibXML::XML::Reader::TYPE_TEXT,
                  ::LibXML::XML::Reader::TYPE_CDATA
                text += reader.value
              when ::LibXML::XML::Reader::TYPE_END_ELEMENT
                break
              end

              reader.read
            end

            # Make sure we advance the cursor one step further.
            reader.read

            if non_text
              instance = new(xml)
              return instance
            else
              return text
            end
          end
        end
      end
    end
  end
end
