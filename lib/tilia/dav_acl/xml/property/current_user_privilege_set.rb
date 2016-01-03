module Tilia
  module DavAcl
    module Xml
      module Property
        # CurrentUserPrivilegeSet
        #
        # This class represents the current-user-privilege-set property. When
        # requested, it contain all the privileges a user has on a specific node.
        class CurrentUserPrivilegeSet
          include Tilia::Xml::Element
          include Dav::Browser::HtmlOutput

          protected

          # List of privileges
          #
          # @var array
          attr_accessor :privileges

          public

          # Creates the object
          #
          # Pass the privileges in clark-notation
          #
          # @param array privileges
          def initialize(privileges)
            @privileges = privileges
          end

          # The xmlSerialize metod is called during xml writing.
          #
          # Use the writer argument to write its own xml serialization.
          #
          # An important note: do _not_ create a parent element. Any element
          # implementing XmlSerializble should only ever write what's considered
          # its 'inner xml'.
          #
          # The parent of the current element is responsible for writing a
          # containing element.
          #
          # This allows serializers to be re-used for different element names.
          #
          # If you are opening new elements, you must also close them again.
          #
          # @param Writer writer
          # @return void
          def xml_serialize(writer)
            @privileges.each do |priv_name|
              writer.start_element('{DAV:}privilege')
              writer.write_element(priv_name)
              writer.end_element
            end
          end

          # Returns true or false, whether the specified principal appears in the
          # list.
          #
          # @param string privilege_name
          # @return bool
          def has(privilege_name)
            @privileges.include?(privilege_name)
          end

          # Returns the list of privileges.
          #
          # @return array
          def value
            @privileges
          end

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
            result = []

            tree = reader.parse_inner_tree('{DAV:}privilege' => Tilia::Xml::Element::Elements)
            tree.each do |element|
              next unless element['name'] == '{DAV:}privilege'

              result << element['value'][0]
            end
            new(result)
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
            props = @privileges.map do |property|
              html.xml_name(property)
            end
            props.join(', ')
          end
        end
      end
    end
  end
end
