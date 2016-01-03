module Tilia
  module Dav
    module Auth
      module Backend
        # Extremely simply HTTP Basic auth backend.
        #
        # This backend basically works by calling a callback, which receives a
        # username and password.
        # The callback must return true or false depending on if authentication was
        # correct.
        class BasicCallBack < AbstractBasic
          # Callback
          #
          # @var callable
          # RUBY: attr_accessor :call_back

          # Creates the backend.
          #
          # A callback must be provided to handle checking the username and
          # password.
          #
          # @param callable call_back
          # @return void
          def initialize(call_back)
            super()
            @call_back = call_back
          end

          protected

          # Validates a username and password
          #
          # This method should return true or false depending on if login
          # succeeded.
          #
          # @param string username
          # @param string password
          # @return bool
          def validate_user_pass(username, password)
            @call_back.call(username, password)
          end
        end
      end
    end
  end
end
