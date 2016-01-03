module Tilia
  module Dav
    module Xml
      module Property
        # This property represents the {DAV:}getlastmodified property.
        #
        # Defined in:
        # http://tools.ietf.org/html/rfc4918#section-15.7
        class GetLastModified
          include Tilia::Xml::Element

          # time
          #
          # @var DateTime
          attr_accessor :time

          # Constructor
          #
          # @param int|DateTime time
          def initialize(time)
            tz = ActiveSupport::TimeZone.new('UTC')
            if time.is_a?(Time)
              @time = time.in_time_zone(tz)
            else
              @time = tz.at time
            end
          end

          # getTime
          #
          # @return DateTime
          attr_reader :time

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
            writer.write(
              Tilia::Http::Util.to_http_date(@time)
            )
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
            new(Time.zone.parse(reader.parse_inner_tree))
          end
        end
      end
    end
  end
end
