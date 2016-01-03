module Tilia
  module DavAcl
    module Xml
      module Property
        # Principal property
        #
        # The principal property represents a principal from RFC3744 (ACL).
        # The property can be used to specify a principal or pseudo principals.
        class Principal < Dav::Xml::Property::Href
          # To specify a not-logged-in user, use the UNAUTHENTICATED principal
          UNAUTHENTICATED = 1

          # To specify any principal that is logged in, use AUTHENTICATED
          AUTHENTICATED = 2

          # Specific principals can be specified with the HREF
          HREF = 3

          # Everybody, basically
          ALL = 4

          protected

          # Principal-type
          #
          # Must be one of the UNAUTHENTICATED, AUTHENTICATED or HREF constants.
          #
          # @var int
          attr_accessor :type

          public

          # Creates the property.
          #
          # The 'type' argument must be one of the type constants defined in this class.
          #
          # 'href' is only required for the HREF type.
          #
          # @param int type
          # @param string|null href
          def initialize(type, href = nil)
            @type = type

            fail Dav::Exception, 'The href argument must be specified for the HREF principal type.' if type == HREF && href.nil?

            href = href.gsub(%r{/+$}, '') + '/' if href
            super(href)
          end

          # Returns the principal type
          #
          # @return int
          attr_reader :type

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
            case @type
            when UNAUTHENTICATED
              writer.write_element('{DAV:}unauthenticated')
            when AUTHENTICATED
              writer.write_element('{DAV:}authenticated')
            when HREF
              super(writer)
            when ALL
              writer.write_element('{DAV:}all')
            end
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
            case @type
            when UNAUTHENTICATED
              return '<em>unauthenticated</em>'
            when AUTHENTICATED
              return '<em>authenticated</em>'
            when HREF
              return super(html)
            when ALL
              return '<em>all</em>'
            end
          end

          # The deserialize method is called during xml parsing.
          #
          # This method is called staticly, this is because in theory this method
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
            tree = reader.parse_inner_tree[0]

            case tree['name']
            when '{DAV:}unauthenticated'
              return new(UNAUTHENTICATED)
            when '{DAV:}authenticated'
              return new(AUTHENTICATED)
            when '{DAV:}href'
              return new(HREF, tree['value'])
            when '{DAV:}all'
              return new(ALL)
            else
              fail Dav::Exception::BadRequest, "Unknown or unsupported principal type: #{tree['name']}"
            end
          end
        end
      end
    end
  end
end
