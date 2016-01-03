module Tilia
  module Dav
    class Exception
      # NotFound
      #
      # This Exception is thrown when a Node couldn't be found. It returns HTTP error
      # code 404
      class NotFound < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          404
        end
      end
    end
  end
end
