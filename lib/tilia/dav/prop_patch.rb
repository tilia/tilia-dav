module Tilia
  module Dav
    # This class represents a set of properties that are going to be updated.
    #
    # Usually this is simply a PROPPATCH request, but it can also be used for
    # internal updates.
    #
    # Property updates must always be atomic. This means that a property update
    # must either completely succeed, or completely fail.
    class PropPatch
      # Properties that are being updated.
      #
      # This is a key-value list. If the value is null, the property is supposed
      # to be deleted.
      #
      # @var array
      attr_accessor :mutations

      # A list of properties and the result of the update. The result is in the
      # form of a HTTP status code.
      #
      # @var array
      attr_accessor :result

      # This is the list of callbacks when we're performing the actual update.
      #
      # @var array
      attr_accessor :property_update_callbacks

      # This property will be set to true if the operation failed.
      #
      # @var bool
      attr_accessor :failed

      # Constructor
      #
      # @param array mutations A list of updates
      def initialize(mutations)
        self.mutations = mutations
        self.result = {}
        self.failed = false
        self.property_update_callbacks = []
      end

      # Call this function if you wish to handle updating certain properties.
      # For instance, your class may be responsible for handling updates for the
      # {DAV:}displayname property.
      #
      # In that case, call this method with the first argument
      # "{DAV:}displayname" and a second argument that's a method that does the
      # actual updating.
      #
      # It's possible to specify more than one property as an array.
      #
      # The callback must return a boolean or an it. If the result is true, the
      # operation was considered successful. If it's false, it's consided
      # failed.
      #
      # If the result is an integer, we'll use that integer as the http status
      # code associated with the operation.
      #
      # @param string|string[] properties
      # @param callable callback
      # @return void
      def handle(properties, callback)
        used_properties = []
        [properties].flatten.each do |property_name|
          next unless mutations.key?(property_name) && !result.key?(property_name)
          used_properties << property_name
          # HTTP Accepted
          result[property_name] = 202
        end

        # Only registering if there's any unhandled properties.
        return nil unless used_properties.any?

        property_update_callbacks << [
          # If the original argument to this method was a string, we need
          # to also make sure that it stays that way, so the commit function
          # knows how to format the arguments to the callback.
          properties.is_a?(String) ? properties : used_properties,
          callback]
      end

      # Call this function if you wish to handle _all_ properties that haven't
      # been handled by anything else yet. Note that you effectively claim with
      # this that you promise to process _all_ properties that are coming in.
      #
      # @param callable callback
      # @return void
      def handle_remaining(callback)
        properties = remaining_mutations
        unless properties.any?
          # Nothing to do, don't register callback
          return
        end

        properties.each do |property_name|
          # HTTP Accepted
          result[property_name] = 202

          property_update_callbacks << [
            properties,
            callback]
        end
      end

      # Sets the result code for one or more properties.
      #
      # @param string|string[] properties
      # @param int result_code
      # @return void
      def update_result_code(properties, result_code)
        [properties].flatten.each do |property_name|
          result[property_name] = result_code
        end

        self.failed = true if result_code >= 400
      end

      # Sets the result code for all properties that did not have a result yet.
      #
      # @param int result_code
      # @return void
      def remaining_result_code=(result_code)
        update_result_code(
          remaining_mutations,
          result_code
        )
      end

      # Returns the list of properties that don't have a result code yet.
      #
      # This method returns a list of property names, but not its values.
      #
      # @return string[]
      def remaining_mutations
        remaining = []
        mutations.keys.each do |property_name|
          remaining << property_name unless result.key? property_name
        end
        remaining
      end

      # Returns the list of properties that don't have a result code yet.
      #
      # This method returns list of properties and their values.
      #
      # @return array
      def remaining_values
        remaining = {}
        mutations.each do |property_name, prop_value|
          remaining[property_name] = prop_value unless result.key? property_name
        end
        remaining
      end

      # Performs the actual update, and calls all callbacks.
      #
      # This method returns true or false depending on if the operation was
      # successful.
      #
      # @return bool
      def commit
        # First we validate if every property has a handler
        mutations.keys.each do |property_name|
          unless result.key? property_name
            self.failed = true
            result[property_name] = 403
          end
        end

        property_update_callbacks.each do |callbackInfo|
          break if failed
          if callbackInfo[0].is_a? String
            do_callback_single_prop(callbackInfo[0], callbackInfo[1])
          else
            do_callback_multi_prop(callbackInfo[0], callbackInfo[1])
          end
        end

        # If anywhere in this operation updating a property failed, we must
        # update all other properties accordingly.
        if failed
          result.each do |property_name, status|
            if status == 202
              # Failed dependency
              result[property_name] = 424
            end
          end
        end

        !failed
      end

      # Returns the result of the operation.
      #
      # @return array
      attr_reader :result

      # Returns the full list of mutations
      #
      # @return array
      attr_reader :mutations

      private

      # Executes a property callback with the single-property syntax.
      #
      # @param string property_name
      # @param callable callback
      # @return void
      def do_callback_single_prop(property_name, callback)
        result = callback.call(mutations[property_name])
        if result.is_a?(TrueClass) || result.is_a?(FalseClass)
          if result
            if mutations[property_name].nil?
              # Delete
              result = 204
            else
              # Update
              result = 200
            end
          else
            # Fail
            result = 403
          end
        end

        unless result.is_a? Integer
          fail 'A callback sent to handle() did not return an int or a bool'
        end
        self.result[property_name] = result
        self.failed = true if result >= 400
      end

      # Executes a property callback with the multi-property syntax.
      #
      # @param array property_list
      # @param callable callback
      # @return void
      def do_callback_multi_prop(property_list, callback)
        argument = {}
        property_list.each do |property_name|
          argument[property_name] = mutations[property_name]
        end

        result = callback.call(argument)

        if result.is_a? Hash
          property_list.each do |property_name|
            unless result.key? property_name
              result_code = 500
            else
              result_code = result[property_name]
            end
            self.failed = true if result_code >= 400

            self.result[property_name] = result_code
          end
        elsif result == true
          # Success
          argument.each do |property_name, property_value|
            self.result[property_name] = property_value.nil? ? 204 : 200
          end
        elsif result == false
          # Fail :(
          self.failed = true
          property_list.each do |property_name|
            self.result[property_name] = 403
          end
        else
          fail 'A callback sent to handle() did not return an array or a bool'
        end
      end
    end
  end
end
