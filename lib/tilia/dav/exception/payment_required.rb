module Tilia
  module Dav
    class Exception
      # Payment Required
      #
      # The PaymentRequired exception may be thrown in a case where a user must pay
      # to access a certain resource or operation.
      class PaymentRequired < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          402
        end
      end
    end
  end
end
