module Tilia
  module CardDav
    module Xml
      module Request
        # AddressBookMultiGetReport request parser.
        #
        # This class parses the {urn:ietf:params:xml:ns:carddav}addressbook-multiget
        # REPORT, as defined in:
        #
        # http://tools.ietf.org/html/rfc6352#section-8.7
        class AddressBookMultiGetReport
          include Tilia::Xml::XmlDeserializable

          # An array with requested properties.
          #
          # @var array
          attr_accessor :properties

          # This is an array with the urls that are being requested.
          #
          # @var array
          attr_accessor :hrefs

          # The mimetype of the content that should be returend. Usually
          # text/vcard.
          #
          # @var string
          attr_accessor :content_type

          # The version of vcard data that should be returned. Usually 3.0,
          # referring to vCard 3.0.
          #
          # @var string
          attr_accessor :version

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
            elems = reader.parse_inner_tree(
              '{urn:ietf:params:xml:ns:carddav}address-data' => Filter::AddressData,
              '{DAV:}prop'                                   => Tilia::Xml::Element::KeyValue
            )

            new_props = {
              'hrefs'      => [],
              'properties' => []
            }

            elems.each do |elem|
              case elem['name']
              when '{DAV:}prop'
                new_props['properties'] = elem['value'].keys
                if elem['value'].key?("{#{Plugin::NS_CARDDAV}}address-data")
                  new_props = new_props.merge(elem['value']["{#{Plugin::NS_CARDDAV}}address-data"])
                end
              when '{DAV:}href'
                new_props['hrefs'] << Uri.resolve(reader.context_uri, elem['value'])
              end
            end

            obj = new
            new_props.each do |key, value|
              key = key.underscore
              next unless %w(properties hrefs content_type version).include?(key)
              obj.send("#{key}=".to_sym, value)
            end

            obj
          end
        end
      end
    end
  end
end
