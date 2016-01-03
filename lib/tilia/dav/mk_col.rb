module Tilia
  module Dav
    # This class represents a MKCOL operation.
    #
    # MKCOL creates a new collection. MKCOL comes in two flavours:
    #
    # 1. MKCOL with no body, signifies the creation of a simple collection.
    # 2. MKCOL with a request body. This can create a collection with a specific
    #    resource type, and a set of properties that should be set on the new
    #    collection. This can be used to create caldav calendars, carddav address
    #    books, etc.
    #
    # Property updates must always be atomic. This means that a property update
    # must either completely succeed, or completely fail.
    class MkCol < PropPatch
      # A list of resource-types in clark-notation.
      #
      # @var array
      attr_accessor :resource_type

      # Creates the MKCOL object.
      #
      # @param string[] resource_type List of resourcetype values.
      # @param array mutations List of new properties values.
      def initialize(resource_type, mutations)
        @resource_type = resource_type
        super(mutations)
      end

      # Returns the resourcetype of the new collection.
      #
      # @return string[]
      attr_reader :resource_type

      # Returns true or false if the MKCOL operation has at least the specified
      # resource type.
      #
      # If the resourcetype is specified as an array, all resourcetypes are
      # checked.
      #
      # @param string|string[] resource_type
      def resource_type?(resource_type)
        ([resource_type].flatten - @resource_type).size == 0
      end
    end
  end
end
