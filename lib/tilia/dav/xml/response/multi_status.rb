module Tilia
  module Dav
    module Xml
      module Response
        # WebDAV MultiStatus parser
        #
        # This class parses the {DAV:}multistatus response, as defined in:
        # https://tools.ietf.org/html/rfc4918#section-14.16
        #
        # And it also adds the {DAV:}synctoken change from:
        # http://tools.ietf.org/html/rfc6578#section-6.4
        class MultiStatus
          include Tilia::Xml::Element

          # The responses
          #
          # @var \Sabre\DAV\Xml\Element\Response[]
          # RUBY: attr_accessor :responses

          # A sync token (from RFC6578).
          #
          # @var string
          # RUBY: attr_accessor :sync_token

          # Constructor
          #
          # @param \Sabre\DAV\Xml\Element\Response[] responses
          # @param string sync_token
          def initialize(responses, sync_token = nil)
            @responses = responses
            @sync_token = sync_token
          end

          # Returns the response list.
          #
          # @return \Sabre\DAV\Xml\Element\Response[]
          attr_reader :responses

          # Returns the sync-token, if available.
          #
          # @return string|null
          attr_reader :sync_token

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
            responses.each do |response|
              writer.write_element('{DAV:}response', response)
            end

            writer.write_element('{DAV:}sync-token', @sync_token) if @sync_token
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
            element_map = reader.element_map
            element_map['{DAV:}prop'] = Element::Prop
            elements = reader.parse_inner_tree(element_map)

            responses = []
            sync_token = nil

            if elements && elements.any?
              elements.each do |elem|
                if elem['name'] == '{DAV:}response'
                  responses << elem['value']
                elsif elem['name'] == '{DAV:}sync-token'
                  sync_token = elem['value']
                end
              end
            end

            new(responses, sync_token)
          end
        end
      end
    end
  end
end
