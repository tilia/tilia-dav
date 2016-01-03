module Tilia
  module Dav
    class Exception
      # ServiceUnavailable
      #
      # This exception is thrown in case the service
      # is currently not available (e.g. down for maintenance).
      class ServiceUnavailable < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          503
        end
      end
    end
  end
end
