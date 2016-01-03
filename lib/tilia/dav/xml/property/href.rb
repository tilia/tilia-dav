module Tilia
  module Dav
    module Xml
      module Property
        # Href property
        #
        # This class represents any WebDAV property that contains a {DAV:}href
        # element, and there are many.
        #
        # It can support either 1 or more hrefs. If while unserializing no valid
        # {DAV:}href elements were found, this property will unserialize itself as
        # null.
        class Href
          include Tilia::Xml::Element
          include Browser::HtmlOutput

          # List of uris
          #
          # @var array
          # RUBY: attr_accessor :hrefs

          # Automatically prefix the url with the server base directory
          #
          # @var bool
          # RUBY: attr_accessor :auto_prefix

          # Constructor
          #
          # You must either pass a string for a single href, or an array of hrefs.
          #
          # If auto-prefix is set to false, the hrefs will be treated as absolute
          # and not relative to the servers base uri.
          #
          # @param string|string[] href
          # @param bool auto_prefix
          def initialize(hrefs, auto_prefix = true)
            hrefs = [] if hrefs.nil?
            hrefs = [hrefs] unless hrefs.is_a?(Array)
            @hrefs = hrefs
            @auto_prefix = auto_prefix
          end

          # Returns the first Href.
          #
          # @return string
          def href
            @hrefs[0]
          end

          # Returns the hrefs as an array
          #
          # @return array
          attr_reader :hrefs

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
            hrefs.each do |href|
              href = writer.context_uri + href if @auto_prefix
              writer.write_element('{DAV:}href', href)
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
            links = []
            hrefs.each do |href|
              links << html.link(href)
            end
            links.join('<br />')
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
            hrefs = []

            list = reader.parse_inner_tree
            list = [] if list.nil?
            list = [list] unless list.is_a?(Array)

            list.each do |elem|
              next if elem['name'] != '{DAV:}href'

              hrefs << elem['value']
            end

            new(hrefs, false) if hrefs.any?
          end
        end
      end
    end
  end
end
