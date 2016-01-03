module Tilia
  module Dav
    class Exception
      # RequestedRangeNotSatisfiable
      #
      # This exception is normally thrown when the user
      # request a range that is out of the entity bounds.
      class RequestedRangeNotSatisfiable < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          416
        end
      end
    end
  end
end
