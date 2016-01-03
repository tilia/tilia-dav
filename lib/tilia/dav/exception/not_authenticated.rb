module Tilia
  module Dav
    class Exception
      # NotAuthenticated
      #
      # This exception is thrown when the client did not provide valid
      # authentication credentials.
      class NotAuthenticated < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          401
        end
      end
    end
  end
end
