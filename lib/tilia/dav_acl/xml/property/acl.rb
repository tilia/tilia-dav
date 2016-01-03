module Tilia
  module DavAcl
    module Xml
      module Property
        # This class represents the {DAV:}acl property.
        #
        # The {DAV:}acl property is a full list of access control entries for a
        # resource.
        #
        # {DAV:}acl is used as a WebDAV property, but it is also used within the body
        # of the ACL request.
        #
        # See:
        # http://tools.ietf.org/html/rfc3744#section-5.5
        class Acl
          include Tilia::Xml::Element
          include Dav::Browser::HtmlOutput

          # @!attribute [w] privileges
          #   @!visibility private
          #   List of privileges
          #
          #   @return [Array]

          # @!attribute [rw] prefix_base_url
          #   @!visibility private
          #   Whether or not the server base url is required to be prefixed when
          #   serializing the property.
          #
          #   @return [Boolean]

          # Constructor
          #
          # This object requires a structure similar to the return value from
          # Tilia::DavAcl::Plugin::get_acl.
          #
          # Each privilege is a an array with at least a 'privilege' property, and a
          # 'principal' property. A privilege may have a 'protected' property as
          # well.
          #
          # The prefixBaseUrl should be set to false, if the supplied principal urls
          # are already full urls. If this is kept to true, the servers base url
          # will automatically be prefixed.
          #
          # @param array privileges
          # @param bool prefix_base_url
          def initialize(privileges, prefix_base_url = true)
            @privileges = privileges
            @prefix_base_url = prefix_base_url
          end

          # Returns the list of privileges for this property
          #
          # @return [Array]
          attr_reader :privileges

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
            @privileges.each do |ace|
              serialize_ace(writer, ace)
            end
          end

          # Generate html representation for this value.
          #
          # The html output is 100% trusted, and no effort is being made to sanitize
          # it. It's up to the implementor to sanitize user provided values.
          #
          # The output must be in UTF-8.
          #
          # The baseUri parameter is a url to the root of the application, and can
          # be used to construct local links.
          #
          # @param HtmlOutputHelper html
          # @return string
          def to_html(html)
            output = '<table>'
            output << '<tr><th>Principal</th><th>Privilege</th><th></th></tr>'
            @privileges.each do |privilege|
              output << '<tr>'

              # if it starts with a {, it's a special principal
              if privilege['principal'][0] == '{'
                output << "<td>#{html.xml_name(privilege['principal'])}</td>"
              else
                output << "<td>#{html.link(privilege['principal'])}</td>"
              end

              output << "<td>#{html.xml_name(privilege['privilege'])}</td>"
              output << '<td>'
              output << '(protected)' unless privilege['protected'].blank?
              output << '</td>'
              output << '</tr>'
            end

            output << '</table>'
            output
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
            element_map = {
              '{DAV:}ace'       => Tilia::Xml::Element::KeyValue,
              '{DAV:}privilege' => Tilia::Xml::Element::Elements,
              '{DAV:}principal' => Tilia::DavAcl::Xml::Property::Principal
            }

            privileges = []

            (reader.parse_inner_tree(element_map) || []).each do |element|
              next unless element['name'] == '{DAV:}ace'

              ace = element['value']

              fail Dav::Exception::BadRequest, 'Each {DAV:}ace element must have one {DAV:}principal element' if ace['{DAV:}principal'].blank?

              principal = ace['{DAV:}principal']

              case principal.type
              when Principal::HREF
                principal = principal.href
              when Principal::AUTHENTICATED
                principal = '{DAV:}authenticated'
              when Principal::UNAUTHENTICATED
                principal = '{DAV:}unauthenticated'
              when Principal::ALL
                principal = '{DAV:}all'
              end

              is_protected = ace.key?('{DAV:}protected')

              fail Dav::Exception::NotImplemented, 'Every {DAV:}ace element must have a {DAV:}grant element. {DAV:}deny is not yet supported' unless ace.key?('{DAV:}grant')

              ace['{DAV:}grant'].each do |elem|
                next unless elem['name'] == '{DAV:}privilege'

                elem['value'].each do |priv|
                  privileges << {
                    'principal' => principal,
                    'protected' => is_protected,
                    'privilege' => priv
                  }
                end
              end
            end

            new(privileges)
          end

          private

          # Serializes a single access control entry.
          #
          # @param Writer writer
          # @param array ace
          # @return void
          def serialize_ace(writer, ace)
            writer.start_element('{DAV:}ace')

            case ace['principal']
            when '{DAV:}authenticated'
              principal = Principal.new(Principal::AUTHENTICATED)
            when '{DAV:}unauthenticated'
              principal = Principal.new(Principal::UNAUTHENTICATED)
            when '{DAV:}all'
              principal = Principal.new(Principal::ALL)
            else
              principal = Principal.new(Principal::HREF, ace['principal'])
            end

            writer.write_element('{DAV:}principal', principal)
            writer.start_element('{DAV:}grant')
            writer.start_element('{DAV:}privilege')

            writer.write_element(ace['privilege'])

            writer.end_element # privilege
            writer.end_element # grant

            writer.write_element('{DAV:}protected') unless ace['protected'].blank?

            writer.end_element # ace
          end
        end
      end
    end
  end
end
