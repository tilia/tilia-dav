module Tilia
  module DavAcl
    module Xml
      module Property
        # SupportedPrivilegeSet property
        #
        # This property encodes the {DAV:}supported-privilege-set property, as defined
        # in rfc3744. Please consult the rfc for details about it's structure.
        #
        # This class expects a structure like the one given from
        # Tilia::DavAcl::Plugin::getSupportedPrivilegeSet as the argument in its
        # constructor.
        #
        # @copyright Copyright (C) 2007-2015 fruux GmbH (https://fruux.com/).
        # @author Evert Pot (http://evertpot.com/)
        # @license http://sabre.io/license/ Modified BSD License
        class SupportedPrivilegeSet
          include Tilia::Xml::XmlSerializable
          include Dav::Browser::HtmlOutput

          protected

          # privileges
          #
          # @var array
          attr_accessor :privileges

          public

          # Constructor
          #
          # @param array privileges
          def initialize(privileges)
            @privileges = privileges
          end

          # Returns the privilege value.
          #
          # @return array
          def value
            @privileges
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
            serialize_priv(writer, @privileges)
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
            traverse = lambda do |priv|
              output = '<li>'
              output << html.xml_name(priv['privilege'])
              output << ' <i>(abstract)</i>' unless priv['abstract'].blank?
              output << " #{html.h(priv['description'])}" if priv.key?('description')

              if priv.key?('aggregates')
                output << "\n<ul>\n"
                priv['aggregates'].each do |sub_priv|
                  output << traverse.call(sub_priv)
                end
                output << '</ul>'
              end
              output << "</li>\n"

              output
            end

            output = "<ul class=\"tree\">"
            output << traverse.call(@privileges)
            output << "</ul>\n"

            output
          end

          private

          # Serializes a property
          #
          # This is a recursive function.
          #
          # @param Writer writer
          # @param array privilege
          # @return void
          def serialize_priv(writer, privilege)
            writer.start_element('{DAV:}supported-privilege')

            writer.start_element('{DAV:}privilege')
            writer.write_element(privilege['privilege'])
            writer.end_element; # privilege

            writer.write_element('{DAV:}abstract') unless privilege['abstract'].blank?

            writer.write_element('{DAV:}description', privilege['description']) unless privilege['description'].blank?

            if privilege.key?('aggregates')
              privilege['aggregates'].each do |sub_privilege|
                serialize_priv(writer, sub_privilege)
              end
            end

            writer.end_element; # supported-privilege
          end
        end
      end
    end
  end
end
