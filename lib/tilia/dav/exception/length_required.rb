module Tilia
  module Dav
    class Exception
      # LengthRequired
      #
      # This exception is thrown when a request was made that required a
      # Content-Length header, but did not contain one.
      class LengthRequired < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          411
        end
      end
    end
  end
end
