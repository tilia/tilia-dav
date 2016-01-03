module Tilia
  module Dav
    module Xml
      module Request
        # WebDAV PROPFIND request parser.
        #
        # This class parses the {DAV:}propfind request, as defined in:
        #
        # https://tools.ietf.org/html/rfc4918#section-14.20
        class PropFind
          include Tilia::Xml::XmlDeserializable

          # If this is set to true, this was an 'allprop' request.
          #
          # @var bool
          attr_accessor :all_prop

          # The property list
          #
          # @var null|array
          attr_accessor :properties

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

            reader.push_context
            reader.element_map['{DAV:}prop'] = Tilia::Xml::Element::Elements

            Tilia::Xml::Element::KeyValue.xml_deserialize(reader).each do |k, v|
              case k
              when '{DAV:}prop'
                instance.properties = v
              when '{DAV:}allprop'
                instance.all_prop = true
              end
            end

            reader.pop_context

            instance
          end

          # TODO: document
          def initialize
            @all_prop = false
          end
        end
      end
    end
  end
end
