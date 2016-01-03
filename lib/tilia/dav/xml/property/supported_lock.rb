module Tilia
  module Dav
    module Xml
      module Property
        # This class represents the {DAV:}supportedlock property.
        #
        # This property is defined here:
        # http://tools.ietf.org/html/rfc4918#section-15.10
        #
        # This property contains information about what kind of locks
        # this server supports.
        class SupportedLock
          include Tilia::Xml::XmlSerializable

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
            writer.write_element(
              '{DAV:}lockentry',
              '{DAV:}lockscope' => { '{DAV:}exclusive' => nil },
              '{DAV:}locktype'  => { '{DAV:}write'     => nil }
            )
            writer.write_element(
              '{DAV:}lockentry',
              '{DAV:}lockscope' => { '{DAV:}shared' => nil },
              '{DAV:}locktype'  => { '{DAV:}write'  => nil }
            )
          end
        end
      end
    end
  end
end
