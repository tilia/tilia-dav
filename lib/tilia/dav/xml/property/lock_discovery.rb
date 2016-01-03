module Tilia
  module Dav
    module Xml
      module Property
        # Represents {DAV:}lockdiscovery property.
        #
        # This property is defined here:
        # http://tools.ietf.org/html/rfc4918#section-15.8
        #
        # This property contains all the open locks on a given resource
        class LockDiscovery
          include Tilia::Xml::XmlSerializable

          # locks
          #
          # @var LockInfo[]
          attr_accessor :locks

          # Hides the {DAV:}lockroot element from the response.
          #
          # It was reported that showing the lockroot in the response can break
          # Office 2000 compatibility.
          #
          # @var bool
          @hide_lock_root = false

          class << self
            attr_accessor :hide_lock_root
          end

          # __construct
          #
          # @param LockInfo[] locks
          def initialize(locks)
            @locks = locks
          end

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
            @locks.each do |lock|
              writer.start_element('{DAV:}activelock')

              writer.start_element('{DAV:}lockscope')
              if lock.scope == Locks::LockInfo::SHARED
                writer.write_element('{DAV:}shared')
              else
                writer.write_element('{DAV:}exclusive')
              end

              writer.end_element # {DAV:}lockscope

              writer.start_element('{DAV:}locktype')
              writer.write_element('{DAV:}write')
              writer.end_element # {DAV:}locktype

              unless self.class.hide_lock_root
                writer.start_element('{DAV:}lockroot')
                writer.write_element('{DAV:}href', "#{writer.context_uri}#{lock.uri}")
                writer.end_element # {DAV:}lockroot
              end

              writer.write_element('{DAV:}depth', (lock.depth == Dav::Server::DEPTH_INFINITY ? 'infinity' : lock.depth))
              writer.write_element('{DAV:}timeout', "Second-#{lock.timeout}")

              writer.start_element('{DAV:}locktoken')
              writer.write_element('{DAV:}href', "opaquelocktoken:#{lock.token}")
              writer.end_element #  {DAV:}locktoken

              writer.write_element('{DAV:}owner', Tilia::Xml::Element::XmlFragment.new(lock.owner))
              writer.end_element # {DAV:}activelock
            end
          end
        end
      end
    end
  end
end
