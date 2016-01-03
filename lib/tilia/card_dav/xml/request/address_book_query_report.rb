module Tilia
  module CardDav
    module Xml
      module Request
        # AddressBookQueryReport request parser.
        #
        # This class parses the {urn:ietf:params:xml:ns:carddav}addressbook-query
        # REPORT, as defined in:
        #
        # http://tools.ietf.org/html/rfc6352#section-8.6
        class AddressBookQueryReport
          include Tilia::Xml::XmlDeserializable

          # An array with requested properties.
          #
          # @var array
          attr_accessor :properties

          # List of property/component filters.
          #
          # This is an array with filters. Every item is a property filter. Every
          # property filter has the following keys:
          #   * name - name of the component to filter on
          #   * test - anyof or allof
          #   * is-not-defined - Test for non-existence
          #   * param-filters - A list of parameter filters on the property
          #   * text-matches - A list of text values the filter needs to match
          #
          # Each param-filter has the following keys:
          #   * name - name of the parameter
          #   * is-not-defined - Test for non-existence
          #   * text-match - Match the parameter value
          #
          # Each text-match in property filters, and the single text-match in
          # param-filters have the following keys:
          #
          #   * value - value to match
          #   * match-type - contains, starts-with, ends-with, equals
          #   * negate-condition - Do the opposite match
          #   * collation - Usually i;unicode-casemap
          #
          # @var array
          attr_accessor :filters

          # The number of results the client wants
          #
          # null means it wasn't specified, which in most cases means 'all results'.
          #
          # @var int|null
          attr_accessor :limit

          # Either 'anyof' or 'allof'
          #
          # @var string
          attr_accessor :test

          # The mimetype of the content that should be returend. Usually
          # text/vcard.
          #
          # @var string
          attr_accessor :content_type

          # The version of vcard data that should be returned. Usually 3.0,
          # referring to vCard 3.0.
          #
          # @var string
          attr_accessor :version

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
            elems = reader.parse_inner_tree(
              '{urn:ietf:params:xml:ns:carddav}prop-filter'  => Filter::PropFilter,
              '{urn:ietf:params:xml:ns:carddav}param-filter' => Filter::ParamFilter,
              '{urn:ietf:params:xml:ns:carddav}address-data' => Filter::AddressData,
              '{DAV:}prop'                                   => Tilia::Xml::Element::KeyValue
            )

            new_props = {
              'filters'    => nil,
              'properties' => [],
              'test'       => 'anyof',
              'limit'      => nil
            }

            (elems || []).each do |elem|
              case elem['name']
              when '{DAV:}prop'
                new_props['properties'] = elem['value'].keys
                if elem['value'].key?("{#{Plugin::NS_CARDDAV}}address-data")
                  new_props = new_props.merge(elem['value']["{#{Plugin::NS_CARDDAV}}address-data"])
                end
              when "{#{Plugin::NS_CARDDAV}}filter"
                fail Dav::Exception::BadRequest, "You can only include 1 {#{Plugin::NS_CARDDAV}}filter element" unless new_props['filters'].nil?

                if elem['attributes'].key?('test')
                  new_props['test'] = elem['attributes']['test']
                  if new_props['test'] != 'allof' && new_props['test'] != 'anyof'
                    fail Dav::Exception::BadRequest, 'The "test" attribute must be one of "allof" or "anyof"'
                  end
                end

                new_props['filters'] = []
                (elem['value'] || []).each do |sub_elem|
                  if sub_elem['name'] == "{#{Plugin::NS_CARDDAV}}prop-filter"
                    new_props['filters'] << sub_elem['value']
                  end
                end
              when "{#{Plugin::NS_CARDDAV}}limit"
                elem['value'].each do |child|
                  if child['name'] == "{#{Plugin::NS_CARDDAV}}nresults"
                    new_props['limit'] = child['value'].to_i
                  end
                end
              end
            end

            if new_props['filters'].nil?
              # We are supposed to throw this error, but KDE sometimes does not
              # include the filter element, and we need to treat it as if no
              # filters are supplied
              # throw new Bad_request('The {#{Plugin::NS_CARDDAV}}filter element is required for this request')
              new_props['filters'] = []
            end

            obj = new
            new_props.each do |key, value|
              key = key.underscore
              next unless %w(version content_type test limit filters properties).include?(key)
              obj.send("#{key}=".to_sym, value)
            end

            obj
          end
        end
      end
    end
  end
end
