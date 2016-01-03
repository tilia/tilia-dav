module Tilia
  module Dav
    class Exception
      # BadRequest
      #
      # The BadRequest is thrown when the user submitted an invalid HTTP request
      # BadRequest
      class BadRequest < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          400
        end
      end
    end
  end
end
