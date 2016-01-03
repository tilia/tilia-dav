module Tilia
  module CalDav
    module Xml
      module Filter
        # CalendarData parser.
        #
        # This class parses the {urn:ietf:params:xml:ns:caldav}calendar-data XML
        # element, as defined in:
        #
        # https://tools.ietf.org/html/rfc4791#section-9.6
        #
        # This element is used in three distinct places in the caldav spec, but in
        # this case, this element class only implements the calendar-data element as
        # it appears in a DAV:prop element, in a calendar-query or calendar-multiget
        # REPORT request.
        class CalendarData
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
              'contentType' => reader['content-type'] || 'text/calendar',
              'version'     => reader['version'] || '2.0'
            }

            elems = reader.parse_inner_tree || []
            elems.each do |elem|
              case elem['name']
              when "{#{Plugin::NS_CALDAV}}expand"
                result['expand'] = {
                  'start' => elem['attributes'].key?('start') ? VObject::DateTimeParser.parse_date_time(elem['attributes']['start']) : nil,
                  'end'   => elem['attributes'].key?('end') ? VObject::DateTimeParser.parse_date_time(elem['attributes']['end']) : nil
                }

                fail Dav::Exception::BadRequest, 'The "start" and "end" attributes are required when expanding calendar-data' unless result['expand']['start'] && result['expand']['end']
                fail Dav::Exception::BadRequest, 'The end-date must be larger than the start-date when expanding calendar-data' if result['expand']['end'] <= result['expand']['start']
              end
            end

            result
          end
        end
      end
    end
  end
end
