module Tilia
  module DavAcl
    module Xml
      module Request
        # PrincipalSearchPropertySetReport request parser.
        #
        # This class parses the {DAV:}principal-property-search REPORT, as defined
        # in:
        #
        # https://tools.ietf.org/html/rfc3744#section-9.4
        #
        # @copyright Copyright (C) 2007-2015 fruux GmbH (https://fruux.com/).
        # @author Evert Pot (http://evertpot.com/)
        # @license http://sabre.io/license/ Modified BSD License
        class PrincipalPropertySearchReport
          include Tilia::Xml::XmlDeserializable

          # The requested properties.
          #
          # @var array|null
          attr_accessor :properties

          # searchProperties
          #
          # @var array
          attr_accessor :search_properties

          # By default the property search will be conducted on the url of the http
          # request. If this is set to true, it will be applied to the principal
          # collection set instead.
          #
          # @var bool
          attr_accessor :apply_to_principal_collection_set

          # Search for principals matching ANY of the properties (OR) or a ALL of
          # the properties (AND).
          #
          # This property is either "anyof" or "allof".
          #
          # @var string
          attr_accessor :test

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
            instance = new

            found_search_prop = false
            instance.test = 'allof'
            instance.test = 'anyof' if reader.get_attribute('test') == 'anyof'

            elem_map = {
              '{DAV:}property-search' => Tilia::Xml::Element::KeyValue,
              '{DAV:}prop'            => Tilia::Xml::Element::KeyValue
            }

            reader.parse_inner_tree(elem_map).each do |elem|
              case elem['name']
              when '{DAV:}prop'
                instance.properties = elem['value'].keys
              when '{DAV:}property-search'
                found_search_prop = true
                # This property has two sub-elements:
                #   {DAV:}prop - The property to be searched on. This may
                #                also be more than one
                #   {DAV:}match - The value to match with
                if !elem['value'].key?('{DAV:}prop') || !elem['value'].key?('{DAV:}match')
                  fail Dav::Exception::BadRequest, 'The {DAV:}property-search element must contain one {DAV:}match and one {DAV:}prop element'
                end
                elem['value']['{DAV:}prop'].each do |prop_name, _discard|
                  instance.search_properties[prop_name] = elem['value']['{DAV:}match']
                end
              when '{DAV:}apply-to-principal-collection-set'
                instance.apply_to_principal_collection_set = true
              end
            end

            unless found_search_prop
              fail Dav::Exception::BadRequest, 'The {DAV:}principal-property-search report must contain at least 1 {DAV:}property-search element'
            end

            instance
          end

          # TODO: document
          def initialize
            @search_properties = {}
            @apply_to_principal_collection_set = false
          end
        end
      end
    end
  end
end
