module Tilia
  module Dav
    class Exception
      # Forbidden
      #
      # This exception is thrown whenever a user tries to do an operation he's not
      # allowed to
      class Forbidden < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          403
        end
      end
    end
  end
end
