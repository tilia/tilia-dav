module Tilia
  module Dav
    module Xml
      module Request
        # SyncCollection request parser.
        #
        # This class parses the {DAV:}sync-collection reprot, as defined in:
        #
        # http://tools.ietf.org/html/rfc6578#section-3.2
        class SyncCollectionReport
          include Tilia::Xml::XmlDeserializable

          # The sync-token the client supplied for the report.
          #
          # @var string|null
          attr_accessor :sync_token

          # The 'depth' of the sync the client is interested in.
          #
          # @var int
          attr_accessor :sync_level

          # Maximum amount of items returned.
          #
          # @var int|null
          attr_accessor :limit

          # The list of properties that are being requested for every change.
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
            elems = Tilia::Xml::Element::KeyValue.xml_deserialize(reader)

            reader.pop_context

            required = [
              '{DAV:}sync-token',
              '{DAV:}prop'
            ]

            required.each do |elem|
              unless elems.include?(elem)
                fail Exception::BadRequest, "The #{elem} element in the {DAV:}sync-collection report is required"
              end
            end

            instance.properties = elems['{DAV:}prop']
            instance.sync_token = elems['{DAV:}sync-token']

            if elems.key?('{DAV:}limit')
              nresults = nil
              elems['{DAV:}limit'].each do |child|
                if child['name'] == '{DAV:}nresults'
                  nresults = child['value'].to_i
                end
              end
              instance.limit = nresults
            end

            if elems.key?('{DAV:}sync-level')
              value = elems['{DAV:}sync-level']
              if value == 'infinity'
                value = Server::DEPTH_INFINITY
              else
                value = value.to_i
              end
              instance.sync_level = value
            end

            instance
          end
        end
      end
    end
  end
end
