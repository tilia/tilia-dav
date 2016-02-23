module Tilia
  module Dav
    module Xml
      module Element
        # WebDAV {DAV:}response parser
        #
        # This class parses the {DAV:}response element, as defined in:
        #
        # https://tools.ietf.org/html/rfc4918#section-14.24
        class Response
          include Tilia::Xml::Element

          # Url for the response
          #
          # @var string
          # RUBY: attr_accessor :href

          # Propertylist, ordered by HTTP status code
          #
          # @var array
          # RUBY: attr_accessor :response_properties

          # The HTTP status for an entire response.
          #
          # This is currently only used in WebDAV-Sync
          #
          # @var string
          # RUBY: attr_accessor :http_status

          # The href argument is a url relative to the root of the server. This
          # class will calculate the full path.
          #
          # The responseProperties argument is a list of properties
          # within an array with keys representing HTTP status codes
          #
          # Besides specific properties, the entire {DAV:}response element may also
          # have a http status code.
          # In most cases you don't need it.
          #
          # This is currently used by the Sync extension to indicate that a node is
          # deleted.
          #
          # @param string href
          # @param array response_properties
          # @param string http_status
          def initialize(href, response_properties, http_status = nil)
            @href = href
            @response_properties = response_properties
            @http_status = http_status
          end

          # Returns the url
          #
          # @return string
          attr_reader :href

          # Returns the httpStatus value
          #
          # @return string
          attr_reader :http_status

          # Returns the property list
          #
          # @return array
          attr_reader :response_properties

          # The serialize method is called during xml writing.
          #
          # It should use the writer argument to encode this object into XML.
          #
          # Important note: it is not needed to create the parent element. The
          # parent element is already created, and we only have to worry about
          # attributes, child elements and text (if any).
          #
          # Important note 2: If you are writing any new elements, you are also
          # responsible for closing them.
          #
          # @param Writer writer
          # @return void
          def xml_serialize(writer)
            if @http_status
              writer.write_element('{DAV:}status', "HTTP/1.1 #{@http_status} #{Tilia::Http::Response.status_codes[@http_status]}")
            end
            writer.write_element('{DAV:}href', writer.context_uri + Http::encode_path(href))

            empty = true

            @response_properties.each do |status, properties|
              # Skipping empty lists
              # TODO: this code is slightly extended, wait for Evert if the original PHP code was correct
              next if properties.is_a?(Hash) && properties.empty?
              next if properties.blank?
              next if status.to_i.to_s != status.to_s

              empty = false

              writer.start_element('{DAV:}propstat')
              writer.write_element('{DAV:}prop', properties)
              writer.write_element('{DAV:}status', "HTTP/1.1 #{status} #{Tilia::Http::Response.status_codes[status]}")
              writer.end_element # {DAV:}propstat
            end

            if empty
              # The WebDAV spec _requires_ at least one DAV:propstat to appear for
              # every DAV:response. In some circumstances however, there are no
              # properties to encode.
              #
              # In those cases we MUST specify at least one DAV:propstat anyway, with
              # no properties.
              writer.write_element(
                '{DAV:}propstat',
                '{DAV:}prop'   => [],
                '{DAV:}status' => "HTTP/1.1 418 #{Http::Response.status_codes[418]}"
              )
            end
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
            reader.push_context

            reader.element_map['{DAV:}propstat'] = Tilia::Xml::Element::KeyValue

            # We are overriding the parser for {DAV:}prop. This deserializer is
            # almost identical to the one for Sabre\Xml\Element\KeyValue.
            #
            # The difference is that if there are any child-elements inside of
            # {DAV:}prop, that have no value, normally any deserializers are
            # called. But we don't want this, because a singular element without
            # child-elements implies 'no value' in {DAV:}prop, so we want to skip
            # deserializers and just set null for those.
            reader.element_map['{DAV:}prop'] = lambda do |reader|
              if reader.empty_element?
                reader.next
                return {}
              end

              values = {}

              reader.read
              loop do
                if reader.node_type == ::LibXML::XML::Reader::TYPE_ELEMENT
                  clark = reader.clark
                  if reader.empty_element?
                    values[clark] = nil
                    reader.next
                  else
                    values[clark] = reader.parse_current_element['value']
                  end
                else
                  reader.read
                end
                break unless reader.node_type != ::LibXML::XML::Reader::TYPE_END_ELEMENT
              end

              reader.read

              values
            end

            elems = reader.parse_inner_tree
            reader.pop_context

            href = nil
            property_lists = {}
            status_code = nil

            elems.each do |elem|
              case elem['name']
              when '{DAV:}href'
                href = elem['value']
              when '{DAV:}propstat'
                status = elem['value']['{DAV:}status']
                status = status.split(' ')[1]
                properties = elem['value'].key?('{DAV:}prop') ? elem['value']['{DAV:}prop'] : []
                property_lists[status] = properties if properties.any?
              when '{DAV:}status'
                status_code = elem['value'].split(' ')[1]
              end
            end

            new(href, property_lists, status_code)
          end
        end
      end
    end
  end
end
