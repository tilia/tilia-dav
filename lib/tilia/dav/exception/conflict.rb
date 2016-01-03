module Tilia
  module Dav
    class Exception
      # Conflict
      #
      # A 409 Conflict is thrown when a user tried to make a directory over an existing
      # file or in a parent directory that doesn't exist.
      class Conflict < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          409
        end
      end
    end
  end
end
