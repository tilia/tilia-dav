module Tilia
  module Dav
    module Xml
      # XML service for WebDAV
      class Service < Tilia::Xml::Service
        # This is a list of XML elements that we automatically map to PHP classes.
        #
        # For instance, this list may contain an entry `{DAV:}propfind` that would
        # be mapped to Sabre\DAV\Xml\Request\PropFind
        attr_accessor :element_map

        # This is a default list of namespaces.
        #
        # If you are defining your own custom namespace, add it here to reduce
        # bandwidth and improve legibility of xml bodies.
        #
        # @var array
        attr_accessor :namespace_map

        def initialize
          super
          @element_map = {
            '{DAV:}multistatus' => Tilia::Dav::Xml::Response::MultiStatus,
            '{DAV:}response'    => Tilia::Dav::Xml::Element::Response,

            # Requests
            '{DAV:}propfind'       => Tilia::Dav::Xml::Request::PropFind,
            '{DAV:}propertyupdate' => Tilia::Dav::Xml::Request::PropPatch,
            '{DAV:}mkcol'          => Tilia::Dav::Xml::Request::MkCol,

            # Properties
            '{DAV:}resourcetype' => Tilia::Dav::Xml::Property::ResourceType
          }
          @namespace_map = {
            'DAV:'                   => 'd',
            'http://sabredav.org/ns' => 's'
          }
        end
      end
    end
  end
end
