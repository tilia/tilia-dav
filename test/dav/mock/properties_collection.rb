module Tilia
  module Dav
    module Mock
      # A node specifically for testing property-related operations
      class PropertiesCollection < Collection
        include IProperties

        attr_accessor :fail_mode

        attr_accessor :properties

        # Creates the object
        #
        # @param string name
        # @param array children
        # @param array properties
        # @return void
        def initialize(name, children, properties = {})
          @fail_mode = false

          super(name, children, nil)
          @properties = properties
        end

        # Updates properties on this node.
        #
        # This method received a PropPatch object, which contains all the
        # information about the update.
        #
        # To update specific properties, call the 'handle' method on this object.
        # Read the PropPatch documentation for more information.
        #
        # @param array mutations
        # @return bool|array
        def prop_patch(proppatch)
          proppatch.handle_remaining(
            lambda do |update_properties|
              case @fail_mode
              when 'updatepropsfalse'
                return false
              when 'updatepropsarray'
                r = {}
                update_properties.each do |k, _v|
                  r[k] = 402
                end
                return r
              when 'updatepropsobj'
                return Class.new
              end
            end
          )
        end

        # Returns a list of properties for this nodes.
        #
        # The properties list is a list of propertynames the client requested,
        # encoded in clark-notation {xmlnamespace}tagname
        #
        # If the array is empty, it means 'all properties' were requested.
        #
        # Note that it's fine to liberally give properties back, instead of
        # conforming to the list of requested properties.
        # The Server class will filter out the extra.
        #
        # @param array properties
        # @return array
        def properties(requested_properties)
          returned_properties = {}
          requested_properties.each do |requested_property|
            if @properties.key?(requested_property)
              returned_properties[requested_property] = @properties[requested_property]
            end
          end

          returned_properties
        end
      end
    end
  end
end
