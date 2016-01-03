module Tilia
  module CardDav
    module Xml
      module Filter
        # ParamFilter parser.
        #
        # This class parses the {urn:ietf:params:xml:ns:carddav}param-filter XML
        # element, as defined in:
        #
        # http://tools.ietf.org/html/rfc6352#section-10.5.2
        #
        # The result will be spit out as an array.
        class ParamFilter
          include Tilia::Xml::Element

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
            result = {
              'name'           => nil,
              'is-not-defined' => false,
              'text-match'     => nil
            }

            att = reader.parse_attributes
            result['name'] = att['name']

            elems = reader.parse_inner_tree

            (elems || []).each do |elem|
              case elem['name']
              when "{#{Plugin::NS_CARDDAV}}is-not-defined"
                result['is-not-defined'] = true
              when "{#{Plugin::NS_CARDDAV}}text-match"
                match_type = elem['attributes'].key?('match-type') ? elem['attributes']['match-type'] : 'contains'

                fail Dav::Exception::BadRequest, "Unknown match-type: #{match_type}" unless %w(contains equals starts-with ends-with).include?(match_type)

                result['text-match'] = {
                  'negate-condition' => elem['attributes'].key?('negate-condition') && elem['attributes']['negate-condition'] == 'yes',
                  'collation'        => elem['attributes'].key?('collation') ? elem['attributes']['collation'] : 'i;unicode-casemap',
                  'value'            => elem['value'],
                  'match-type'       => match_type
                }
              end
            end

            result
          end
        end
      end
    end
  end
end
