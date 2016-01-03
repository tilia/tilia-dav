module Tilia
  module Dav
    #  IProperties interface
    #
    #  Implement this interface to support custom WebDAV properties requested and sent from clients.
    module IProperties
      include INode

      # Updates properties on this node.
      #
      # This method received a PropPatch object, which contains all the
      # information about the update.
      #
      # To update specific properties, call the 'handle' method on this object.
      # Read the PropPatch documentation for more information.
      #
      # @param PropPatch propPatch
      # @return void
      def prop_patch(prop_patch)
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
      def properties(properties)
      end
    end
  end
end
