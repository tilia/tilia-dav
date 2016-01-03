module Tilia
  module DavAcl
    module Xml
      module Request
        # ExpandProperty request parser.
        #
        # This class parses the {DAV:}expand-property REPORT, as defined in:
        #
        # http://tools.ietf.org/html/rfc3253#section-3.8
        #
        # @copyright Copyright (C) 2007-2015 fruux GmbH (https://fruux.com/).
        # @author Evert Pot (http://evertpot.com/)
        # @license http://sabre.io/license/ Modified BSD License
        class ExpandPropertyReport
          include Tilia::Xml::XmlDeserializable

          # An array with requested properties.
          #
          # The requested properties will be used as keys in this array. The value
          # is normally null.
          #
          # If the value is an array though, it means the property must be expanded.
          # Within the array, the sub-properties, which themselves may be null or
          # arrays.
          #
          # @var array
          attr_accessor :properties

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
            elems = reader.parse_inner_tree

            obj = new
            obj.properties = traverse(elems)

            obj
          end

          # This method is used by deserializeXml, to recursively parse the
          # {DAV:}property elements.
          #
          # @param array elems
          # @return void
          def self.traverse(elems)
            result = {}

            elems.each do |elem|
              next unless elem['name'] == '{DAV:}property'

              namespace = elem['attributes'].key?('namespace') ?
                  elem['attributes']['namespace'] :
                  'DAV:'

              prop_name = "{#{namespace}}#{elem['attributes']['name']}"

              value = nil
              value = traverse(elem['value']) if elem['value'].is_a?(Array)

              result[prop_name] = value
            end

            result
          end
        end
      end
    end
  end
end
