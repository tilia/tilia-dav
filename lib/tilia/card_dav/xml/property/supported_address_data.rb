module Tilia
  module CardDav
    module Xml
      module Property
        # Supported-address-data property
        #
        # This property is a representation of the supported-address-data property
        # in the CardDAV namespace.
        #
        # This property is defined in:
        #
        # http://tools.ietf.org/html/rfc6352#section-6.2.2
        class SupportedAddressData
          include Tilia::Xml::XmlSerializable

          # @!attribute [rw] supported versions
          #   @!visibility private
          #
          #   @return [Array]

          # Creates the property
          #
          # @param array|null supported_data
          def initialize(supported_data = nil)
            if supported_data.nil?
              supported_data = [
                { 'contentType' => 'text/vcard', 'version' => '3.0' },
                { 'contentType' => 'text/vcard', 'version' => '4.0' },
                { 'contentType' => 'application/vcard+json', 'version' => '4.0' }
              ]
            end

            @supported_data = supported_data
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
            @supported_data.each do |supported|
              writer.start_element("{#{Plugin::NS_CARDDAV}}address-data-type")
              writer.write_attributes(
                'content-type' => supported['contentType'],
                'version'      => supported['version']
              )
              writer.end_element # address-data-type
            end
          end
        end
      end
    end
  end
end
