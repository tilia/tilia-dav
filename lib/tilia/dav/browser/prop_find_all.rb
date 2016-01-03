module Tilia
  module Dav
    module Browser
      # This class is used by the browser plugin to trick the system in returning
      # every defined property.
      class PropFindAll < PropFind
        # Creates the PROPFIND object
        #
        # @param string path
        def initialize(path)
          super(path, [])
        end

        # Handles a specific property.
        #
        # This method checks wether the specified property was requested in this
        # PROPFIND request, and if so, it will call the callback and use the
        # return value for it's value.
        #
        # Example:
        #
        # prop_find.handle('{DAV:}displayname', function {
        #      return 'hello'
        # })
        #
        # Note that handle will only work the first time. If null is returned, the
        # value is ignored.
        #
        # It's also possible to not pass a callback, but immediately pass a value
        #
        # @param string property_name
        # @param mixed value_or_call_back
        # @return void
        def handle(property_name, value_or_call_back)
          if value_or_call_back.is_a?(Proc) || value_or_call_back.is_a?(Method)
            value = value_or_call_back.call
          else
            value = value_or_call_back
          end

          result[property_name] = [200, value] unless value.nil?
        end

        # Sets the value of the property
        #
        # If status is not supplied, the status will default to 200 for non-null
        # properties, and 404 for null properties.
        #
        # @param string property_name
        # @param mixed value
        # @param int status
        # @return void
        def set(property_name, value, status = nil)
          status = value.nil? ? 404 : 200 if status.nil?
          result[property_name] = [status, value]
        end

        # Returns the current value for a property.
        #
        # @param string property_name
        # @return mixed
        def get(property_name)
          result.key?(property_name) ? result[property_name][1] : nil
        end

        # Returns the current status code for a property name.
        #
        # If the property does not appear in the list of requested properties,
        # null will be returned.
        #
        # @param string property_name
        # @return int|null
        def status(property_name)
          result.key?(property_name) ? result[property_name][0] : 404
        end

        # Returns all propertynames that have a 404 status, and thus don't have a
        # value yet.
        #
        # @return array
        def get404_properties
          result = []
          self.result.each do |property_name, stuff|
            result << property_name if stuff[0] == 404
          end

          # If there's nothing in this list, we're adding one fictional item.
          result << '{http://sabredav.org/ns}idk' if result.empty?

          result
        end
      end
    end
  end
end
