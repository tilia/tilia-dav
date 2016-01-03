module Tilia
  module Dav
    class Exception
      # InsufficientStorage
      #
      # This Exception can be thrown, when for example a harddisk is full or a quota
      # is exceeded
      class InsufficientStorage < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          507
        end
      end
    end
  end
end
