module Tilia
  module CalDav
    module Xml
      module Request
        # Share POST request parser
        #
        # This class parses the share POST request, as defined in:
        #
        # http://svn.calendarserver.org/repository/calendarserver/CalendarServer/trunk/doc/Extensions/caldav-sharing.txt
        class Share
          include Tilia::Xml::XmlDeserializable

          # The list of new people added or updated.
          #
          # Every element has the following keys:
          # 1. href - An email address
          # 2. commonName - Some name
          # 3. summary - An optional description of the share
          # 4. readOnly - true or false
          #
          # @var array
          attr_accessor :set

          # List of people removed from the share list.
          #
          # The list is a flat list of email addresses (including mailto:).
          #
          # @var array
          attr_accessor :remove

          # Constructor
          #
          # @param array set
          # @param array remove
          def initialize(set, remove)
            @set = set
            @remove = remove
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
            elems = reader.parse_inner_tree(
              "{#{Plugin::NS_CALENDARSERVER}}set"    => Tilia::Xml::Element::KeyValue,
              "{#{Plugin::NS_CALENDARSERVER}}remove" => Tilia::Xml::Element::KeyValue
            )

            set = []
            remove = []

            elems.each do |elem|
              case elem['name']
              when "{#{Plugin::NS_CALENDARSERVER}}set"
                sharee = elem['value']

                sum_elem = "{#{Plugin::NS_CALENDARSERVER}}summary"
                common_name = "{#{Plugin::NS_CALENDARSERVER}}common-name"

                set << {
                  'href'       => sharee['{DAV:}href'],
                  'commonName' => sharee[common_name],
                  'summary'    => sharee[sum_elem],
                  'readOnly'   => !sharee.key?("{#{Plugin::NS_CALENDARSERVER}}read-write")
                }
              when "{#{Plugin::NS_CALENDARSERVER}}remove"
                remove << elem['value']['{DAV:}href']
              end
            end

            new(set, remove)
          end
        end
      end
    end
  end
end
