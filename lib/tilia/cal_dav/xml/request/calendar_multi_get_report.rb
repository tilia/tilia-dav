module Tilia
  module CalDav
    module Xml
      module Request
        # CalendarMultiGetReport request parser.
        #
        # This class parses the {urn:ietf:params:xml:ns:caldav}calendar-multiget
        # REPORT, as defined in:
        #
        # https://tools.ietf.org/html/rfc4791#section-7.9
        class CalendarMultiGetReport
          include Tilia::Xml::XmlDeserializable

          # An array with requested properties.
          #
          # @var array
          attr_accessor :properties

          # This is an array with the urls that are being requested.
          #
          # @var array
          attr_accessor :hrefs

          # If the calendar data must be expanded, this will contain an array with 2
          # elements: start and end.
          #
          # Each may be a DateTime or null.
          #
          # @var array|null
          attr_accessor :expand

          # The mimetype of the content that should be returend. Usually
          # text/calendar.
          #
          # @var string
          attr_accessor :content_type

          # The version of calendar-data that should be returned. Usually '2.0',
          # referring to iCalendar 2.0.
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
              '{urn:ietf:params:xml:ns:caldav}calendar-data' => Filter::CalendarData,
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
                if elem['value'].key?("{#{Plugin::NS_CALDAV}}calendar-data")
                  new_props = new_props.merge(elem['value']["{#{Plugin::NS_CALDAV}}calendar-data"])
                end
              when '{DAV:}href'
                new_props['hrefs'] << Uri.resolve(reader.context_uri, elem['value'])
              end
            end

            obj = new
            new_props.each do |key, value|
              key = key.underscore
              next unless %w(properties hrefs expand content_type version).include?(key)
              obj.send("#{key}=".to_sym, value)
            end

            obj
          end
        end
      end
    end
  end
end
