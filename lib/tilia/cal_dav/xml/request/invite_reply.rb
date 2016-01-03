module Tilia
  module CalDav
    module Xml
      module Request
        # Invite-reply POST request parser
        #
        # This class parses the invite-reply POST request, as defined in:
        #
        # http://svn.calendarserver.org/repository/calendarserver/CalendarServer/trunk/doc/Extensions/caldav-sharing.txt
        class InviteReply
          include Tilia::Xml::XmlDeserializable

          # The sharee calendar user address.
          #
          # This is the address that the original invite was set to
          #
          # @var string
          attr_accessor :href

          # The uri to the calendar that was being shared.
          #
          # @var string
          attr_accessor :calendar_uri

          # The id of the invite message that's being responded to
          #
          # @var string
          attr_accessor :in_reply_to

          # An optional message
          #
          # @var string
          attr_accessor :summary

          # Either SharingPlugin::STATUS_ACCEPTED or SharingPlugin::STATUS_DECLINED.
          #
          # @var int
          attr_accessor :status

          # Constructor
          #
          # @param string href
          # @param string calendar_uri
          # @param string in_reply_to
          # @param string summary
          # @param int status
          def initialize(href, calendar_uri, in_reply_to, summary, status)
            @href = href
            @calendar_uri = calendar_uri
            @in_reply_to = in_reply_to
            @summary = summary
            @status = status
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
            elems = Tilia::Xml::Element::KeyValue.xml_deserialize(reader)

            href = nil
            calendar_uri = nil
            in_reply_to = nil
            summary = nil
            status = nil

            elems.each do |name, value|
              case name
              when "{#{Plugin::NS_CALENDARSERVER}}hosturl"
                value.each do |bla|
                  calendar_uri = bla['value'] if bla['name'] == '{DAV:}href'
                end
              when "{#{Plugin::NS_CALENDARSERVER}}invite-accepted"
                status = SharingPlugin::STATUS_ACCEPTED
              when "{#{Plugin::NS_CALENDARSERVER}}invite-declined"
                status = SharingPlugin::STATUS_DECLINED
              when "{#{Plugin::NS_CALENDARSERVER}}in-reply-to"
                in_reply_to = value
              when "{#{Plugin::NS_CALENDARSERVER}}summary"
                summary = value
              when '{DAV:}href'
                href = value
              end
            end

            fail Dav::Exception::BadRequest, 'The {http://calendarserver.org/ns/}hosturl/{DAV:}href element must exist' unless calendar_uri

            new(href, calendar_uri, in_reply_to, summary, status)
          end
        end
      end
    end
  end
end
