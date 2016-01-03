module Tilia
  module Dav
    module Xml
      module Property
        # {DAV:}resourcetype property
        #
        # This class represents the {DAV:}resourcetype property, as defined in:
        #
        # https://tools.ietf.org/html/rfc4918#section-15.9
        class ResourceType < Tilia::Xml::Element::Elements
          include Browser::HtmlOutput

          # Constructor
          #
          # You can either pass null (for no resourcetype), a string (for a single
          # resourcetype) or an array (for multiple).
          #
          # The resourcetype must be specified in clark-notation
          #
          # @param array|string|null resource_type
          def initialize(resource_types = nil)
            resource_types = [] if resource_types.nil?
            resource_types = [resource_types] unless resource_types.is_a?(Array)
            super(resource_types)
          end

          # Returns the values in clark-notation
          #
          # For example array('{DAV:}collection')
          #
          # @return array
          attr_reader :value

          # Checks if the principal contains a certain value
          #
          # @param string type
          # @return bool
          def is(type)
            @value.include?(type)
          end

          # Adds a resourcetype value to this property
          #
          # @param string type
          # @return void
          def add(type)
            @value << type
            @value = @value.uniq
          end

          # The deserialize method is called during xml parsing.
          #
          # This method is called statictly, this is because in theory this method
          # may be used as a type of constructor, or factory method.
          #
          # Often you want to return an instance of the current class, but you are
          # free to return other data as well.
          #
          # Important note 2: You are responsible for advancing the reader to the
          # next element. Not doing anything will result in a never-ending loop.
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
            new(super(reader))
          end

          # Generate html representation for this value.
          #
          # The html output is 100% trusted, and no effort is being made to sanitize
          # it. It's up to the implementor to sanitize user provided values.
          #
          # The output must be in UTF-8.
          #
          # The baseUri parameter is a url to the root of the application, and can
          # be used to construct local links.
          #
          # @param HtmlOutputHelper html
          # @return string
          def to_html(html)
            tmp = value.map do |value|
              html.xml_name(value)
            end
            tmp.join(', ')
          end
        end
      end
    end
  end
end
