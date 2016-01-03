module Tilia
  module Dav
    module Xml
      module Request
        # WebDAV LOCK request parser.
        #
        # This class parses the {DAV:}lockinfo request, as defined in:
        #
        # http://tools.ietf.org/html/rfc4918#section-9.10
        class Lock
          include Tilia::Xml::XmlDeserializable

          # Owner of the lock
          #
          # @var string
          attr_accessor :owner

          # Scope of the lock.
          #
          # Either LockInfo::SHARED or LockInfo::EXCLUSIVE
          # @var int
          attr_accessor :scope

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
            reader.element_map['{DAV:}owner'] = Tilia::Xml::Element::XmlFragment

            values = Tilia::Xml::Element::KeyValue.xml_deserialize(reader)

            reader.pop_context

            instance = new
            instance.owner = values['{DAV:}owner'] ? values['{DAV:}owner'].xml : nil
            instance.scope = Locks::LockInfo::SHARED

            if values.key?('{DAV:}lockscope')
              values['{DAV:}lockscope'].each do |elem|
                instance.scope = Locks::LockInfo::EXCLUSIVE if elem['name'] == '{DAV:}exclusive'
              end
            end

            instance
          end
        end
      end
    end
  end
end
