module Tilia
  module DavAcl
    # Principals Collection
    #
    # This is a helper class that easily allows you to create a collection that
    # has a childnode for every principal.
    #
    # To use this class, simply implement the getChildForPrincipal method.
    class AbstractPrincipalCollection < Dav::Collection
      include IPrincipalCollection

      protected

      # Principal backend
      #
      # @var PrincipalBackend\BackendInterface
      attr_accessor :principal_backend

      # The path to the principals we're listing from.
      #
      # @var string
      attr_accessor :principal_prefix

      public

      # If this value is set to true, it effectively disables listing of users
      # it still allows user to find other users if they have an exact url.
      #
      # @var bool
      attr_accessor :disable_listing

      # Creates the object
      #
      # This object must be passed the principal backend. This object will
      # filter all principals from a specified prefix (principal_prefix). The
      # default is 'principals', if your principals are stored in a different
      # collection, override principal_prefix
      #
      #
      # @param PrincipalBackend\BackendInterface principal_backend
      # @param string principal_prefix
      def initialize(principal_backend, principal_prefix = 'principals')
        @disable_listing = false
        @principal_prefix = principal_prefix
        @principal_backend = principal_backend
      end

      # This method returns a node for a principal.
      #
      # The passed array contains principal information, and is guaranteed to
      # at least contain a uri item. Other properties may or may not be
      # supplied by the authentication backend.
      #
      # @param array principal_info
      # @return IPrincipal
      def child_for_principal(principal_info)
      end

      # Returns the name of this collection.
      #
      # @return string
      def name
        name = Http::UrlUtil.split_path(@principal_prefix)[1]
        name
      end

      # Return the list of users
      #
      # @return array
      def children
        fail Dav::Exception::MethodNotAllowed, 'Listing members of this collection is disabled' if @disable_listing

        children = []
        @principal_backend.principals_by_prefix(@principal_prefix).each do |principal_info|
          children << child_for_principal(principal_info)
        end

        children
      end

      # Returns a child object, by its name.
      #
      # @param string name
      # @throws DAV\Exception\NotFound
      # @return IPrincipal
      def child(name)
        principal_info = @principal_backend.principal_by_path("#{@principal_prefix}/#{name}")
        fail Dav::Exception::NotFound, "Principal with name #{name} not found" unless principal_info
        child_for_principal(principal_info)
      end

      # This method is used to search for principals matching a set of
      # properties.
      #
      # This search is specifically used by RFC3744's principal-property-search
      # REPORT. You should at least allow searching on
      # http://sabredav.org/ns}email-address.
      #
      # The actual search should be a unicode-non-case-sensitive search. The
      # keys in searchProperties are the WebDAV property names, while the values
      # are the property values to search on.
      #
      # By default, if multiple properties are submitted to this method, the
      # various properties should be combined with 'AND'. If test is set to
      # 'anyof', it should be combined using 'OR'.
      #
      # This method should simply return a list of 'child names', which may be
      # used to call self.child in the future.
      #
      # @param array search_properties
      # @param string test
      # @return array
      def search_principals(search_properties, test = 'allof')
        result = @principal_backend.search_principals(@principal_prefix, search_properties, test)
        r = []

        result.each do |row|
          r << Http::UrlUtil.split_path(row)[1]
        end

        r
      end

      # Finds a principal by its URI.
      #
      # This method may receive any type of uri, but mailto: addresses will be
      # the most common.
      #
      # Implementation of this API is optional. It is currently used by the
      # CalDAV system to find principals based on their email addresses. If this
      # API is not implemented, some features may not work correctly.
      #
      # This method must return a relative principal path, or null, if the
      # principal was not found or you refuse to find it.
      #
      # @param string uri
      # @return string
      def find_by_uri(uri)
        @principal_backend.find_by_uri(uri, @principal_prefix)
      end
    end
  end
end
