module Tilia
  module Dav
    module Xml
      module Request
        # WebDAV Extended MKCOL request parser.
        #
        # This class parses the {DAV:}mkol request, as defined in:
        #
        # https://tools.ietf.org/html/rfc5689#section-5.1
        class MkCol
          include Tilia::Xml::XmlDeserializable

          # The list of properties that will be set.
          #
          # @var array
          attr_accessor :properties

          # Returns a key=>value array with properties that are supposed to get set
          # during creation of the new collection.
          #
          # @return array
          attr_reader :properties

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
            element_map['{DAV:}prop']   = Element::Prop
            element_map['{DAV:}set']    = Tilia::Xml::Element::KeyValue
            element_map['{DAV:}remove'] = Tilia::Xml::Element::KeyValue

            elems = reader.parse_inner_tree(element_map)

            elems.each do |elem|
              if elem['name'] == '{DAV:}set'
                instance.properties.merge!(elem['value']['{DAV:}prop'])
              end
            end

            instance
          end

          def initialize
            @properties = {}
          end
        end
      end
    end
  end
end
