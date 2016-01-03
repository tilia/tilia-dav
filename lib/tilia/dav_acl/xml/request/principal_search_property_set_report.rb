module Tilia
  module DavAcl
    module Xml
      module Request
        # PrincipalSearchPropertySetReport request parser.
        #
        # This class parses the {DAV:}principal-search-property-set REPORT, as defined
        # in:
        #
        # https://tools.ietf.org/html/rfc3744#section-9.5
        #
        # @copyright Copyright (C) 2007-2015 fruux GmbH (https://fruux.com/).
        # @author Evert Pot (http://evertpot.com/)
        # @license http://sabre.io/license/ Modified BSD License
        class PrincipalSearchPropertySetReport
          include Tilia::Xml::XmlDeserializable

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
            fail Dav::Exception::BadRequest, 'The {DAV:}principal-search-property-set element must be empty' unless reader.empty_element?

            # The element is actually empty, so there's not much to do.
            reader.next

            new
          end
        end
      end
    end
  end
end
