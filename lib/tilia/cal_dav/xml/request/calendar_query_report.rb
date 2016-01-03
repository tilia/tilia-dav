module Tilia
  module CalDav
    module Xml
      module Request
        # CalendarQueryReport request parser.
        #
        # This class parses the {urn:ietf:params:xml:ns:caldav}calendar-query
        # REPORT, as defined in:
        #
        # https://tools.ietf.org/html/rfc4791#section-7.9
        class CalendarQueryReport
          include Tilia::Xml::XmlDeserializable

          # An array with requested properties.
          #
          # @var array
          attr_accessor :properties

          # List of property/component filters.
          #
          # @var array
          attr_accessor :filters

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
              '{urn:ietf:params:xml:ns:caldav}comp-filter'   => Filter::CompFilter,
              '{urn:ietf:params:xml:ns:caldav}prop-filter'   => Filter::PropFilter,
              '{urn:ietf:params:xml:ns:caldav}param-filter'  => Filter::ParamFilter,
              '{urn:ietf:params:xml:ns:caldav}calendar-data' => Filter::CalendarData,
              '{DAV:}prop'                                   => Tilia::Xml::Element::KeyValue
            )

            new_props = {
              'filters'    => nil,
              'properties' => []
            }

            elems = [] unless elems.is_a?(Array)

            elems.each do |elem|
              case elem['name']
              when '{DAV:}prop'
                new_props['properties'] = elem['value'].keys
                if elem['value'].key?("{#{Plugin::NS_CALDAV}}calendar-data")
                  new_props = new_props.merge(elem['value']["{#{Plugin::NS_CALDAV}}calendar-data"])
                end
              when "{#{Plugin::NS_CALDAV}}filter"
                elem['value'].each do |sub_elem|
                  next unless sub_elem['name'] == "{#{Plugin::NS_CALDAV}}comp-filter"
                  unless new_props['filters'].nil?
                    fail Dav::Exception::BadRequest, 'Only one top-level comp-filter may be defined'
                  end
                  new_props['filters'] = sub_elem['value']
                end
              end
            end

            fail Dav::Exception::BadRequest, "The {#{Plugin::NS_CALDAV}}filter element is required for this request" unless new_props['filters'] && new_props['filters'].any?

            obj = new
            new_props.each do |key, value|
              key = key.underscore
              next unless %w(properties filters expand content_type version).include?(key)
              obj.send("#{key}=".to_sym, value)
            end

            obj
          end
        end
      end
    end
  end
end
