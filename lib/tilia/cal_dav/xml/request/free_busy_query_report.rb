module Tilia
  module CalDav
    module Xml
      module Request
        # FreeBusyQueryReport
        #
        # This class parses the {DAV:}free-busy-query REPORT, as defined in:
        #
        # http://tools.ietf.org/html/rfc3253#section-3.8
        class FreeBusyQueryReport
          include Tilia::Xml::XmlDeserializable

          # Starttime of report
          #
          # @var DateTime|null
          attr_accessor :start

          # End time of report
          #
          # @var DateTime|null
          attr_accessor :end

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
            time_range = "{#{Plugin::NS_CALDAV}}time-range"

            start = nil
            ending = nil

            (reader.parse_inner_tree({}) || []).each do |elem|
              next unless elem['name'] == time_range

              start =  elem['attributes']['start']
              ending = elem['attributes']['end']
            end

            fail Dav::Exception::BadRequest.new('The freebusy report must have a time-range element') if !start && !ending

            start = VObject::DateTimeParser.parse_date_time(start) if start
            ending = VObject::DateTimeParser.parse_date_time(ending) if ending

            result = new
            result.start = start
            result.end = ending

            result
          end
        end
      end
    end
  end
end
