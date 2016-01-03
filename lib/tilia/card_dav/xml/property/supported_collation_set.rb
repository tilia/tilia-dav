module Tilia
  module CardDav
    module Xml
      module Property
        # supported-collation-set property
        #
        # This property is a representation of the supported-collation-set property
        # in the CardDAV namespace.
        class SupportedCollationSet
          include Tilia::Xml::XmlSerializable

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
            ['i;ascii-casemap', 'i;octet', 'i;unicode-casemap'].each do |coll|
              writer.write_element('{urn:ietf:params:xml:ns:carddav}supported-collation', coll)
            end
          end
        end
      end
    end
  end
end
