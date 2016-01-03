module Tilia
  module CalDav
    module Xml
      module Property
        # email-address-set property
        #
        # This property represents the email-address-set property in the
        # http://calendarserver.org/ns/ namespace.
        #
        # It's a list of email addresses associated with a user.
        class EmailAddressSet
          include Tilia::Xml::XmlSerializable

          # @!attribute [r] emails
          #   @!visibility private
          #   emails
          #
          #   @var array

          # __construct
          #
          # @param array emails
          def initialize(emails)
            @emails = emails
          end

          # Returns the email addresses
          #
          # @return array
          def value
            @emails
          end

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
            @emails.each do |email|
              writer.write_element('{http://calendarserver.org/ns/}email-address', email)
            end
          end
        end
      end
    end
  end
end
