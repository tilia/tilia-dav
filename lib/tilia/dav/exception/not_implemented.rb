module Tilia
  module Dav
    class Exception
      # NotImplemented
      #
      # This exception is thrown when the client tried to call an unsupported HTTP
      # method or other feature
      class NotImplemented < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          501
        end
      end
    end
  end
end
