module Tilia
  module CalDav
    module Xml
      module Request
        # MKCALENDAR parser.
        #
        # This class parses the MKCALENDAR request, as defined in:
        #
        # https://tools.ietf.org/html/rfc4791#section-5.3.1
        class MkCalendar
          include Tilia::Xml::XmlDeserializable

          # The list of properties that will be set.
          #
          # @var array
          attr_accessor :properties

          # Returns the list of properties the calendar will be initialized with.
          #
          # @return array
          # attr_reader :properties

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
            instance = new

            element_map = reader.element_map
            element_map['{DAV:}prop']   = Dav::Xml::Element::Prop
            element_map['{DAV:}set']    = Tilia::Xml::Element::KeyValue
            elems = reader.parse_inner_tree(element_map)

            elems.each do |elem|
              if elem['name'] == '{DAV:}set'
                instance.properties = instance.properties.merge(elem['value']['{DAV:}prop'])
              end
            end

            instance
          end

          # initialize instance vars
          def initialize
            @properties = {}
          end
        end
      end
    end
  end
end
