module Tilia
  module Dav
    class Exception
      # UnsupportedMediaType
      #
      # The 415 Unsupported Media Type status code is generally sent back when the client
      # tried to call an HTTP method, with a body the server didn't understand
      class UnsupportedMediaType < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          415
        end
      end
    end
  end
end
