module Tilia
  module CalDav
    module Xml
      module Filter
        # PropFilter parser.
        #
        # This class parses the {urn:ietf:params:xml:ns:caldav}prop-filter XML
        # element, as defined in:
        #
        # https://tools.ietf.org/html/rfc4791#section-9.7.2
        #
        # The result will be spit out as an array.
        class PropFilter
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
            result = {
              'name'           => nil,
              'is-not-defined' => false,
              'param-filters'  => [],
              'text-match'     => nil,
              'time-range'     => false
            }

            att = reader.parse_attributes
            result['name'] = att['name']

            elems = reader.parse_inner_tree || []

            elems.each do |elem|
              case elem['name']
              when "{#{Plugin::NS_CALDAV}}param-filter"
                result['param-filters'] << elem['value']
              when "{#{Plugin::NS_CALDAV}}is-not-defined"
                result['is-not-defined'] = true
              when "{#{Plugin::NS_CALDAV}}time-range"
                result['time-range'] = {
                  'start' => elem['attributes'].key?('start') ? VObject::DateTimeParser.parse_date_time(elem['attributes']['start']) : nil,
                  'end'   => elem['attributes'].key?('end') ? VObject::DateTimeParser.parse_date_time(elem['attributes']['end']) : nil
                }
                if result['time-range']['start'] &&
                   result['time-range']['end'] &&
                   result['time-range']['end'] <= result['time-range']['start']
                  fail Dav::Exception::BadRequest, 'The end-date must be larger than the start-date'
                end
              when "{#{Plugin::NS_CALDAV}}text-match"
                result['text-match'] = {
                  'negate-condition' => elem['attributes'].key?('negate-condition') && elem['attributes']['negate-condition'] == 'yes',
                  'collation'        => elem['attributes'].key?('collation') ? elem['attributes']['collation'] : 'i;ascii-casemap',
                  'value'            => elem['value']
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
