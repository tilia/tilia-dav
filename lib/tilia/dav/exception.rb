module Tilia
  module Dav
    # Main Exception class.
    #
    # This class defines a getHTTPCode method, which should return the appropriate HTTP code for the Exception occurred.
    # The default for this is 500.
    #
    # This class also allows you to generate custom xml data for your exceptions. This will be displayed
    # in the 'error' element in the failing response.
    class Exception < StandardError
      # Returns the HTTP statuscode for this exception
      #
      # @return int
      def http_code
        500
      end

      # This method allows the exception to include additional information into the WebDAV error response
      #
      # @param Server server
      # @param \DOMElement error_node
      # @return void
      def serialize(server, error_node)
      end

      # This method allows the exception to return any extra HTTP response headers.
      #
      # The headers must be returned as an array.
      #
      # @param Server $server
      # @return array
      def http_headers(_server)
        {}
      end

      require 'tilia/dav/exception/bad_request'
      require 'tilia/dav/exception/conflict'
      require 'tilia/dav/exception/locked'
      require 'tilia/dav/exception/conflicting_lock'
      require 'tilia/dav/exception/forbidden'
      require 'tilia/dav/exception/insufficient_storage'
      require 'tilia/dav/exception/invalid_resource_type'
      require 'tilia/dav/exception/invalid_sync_token'
      require 'tilia/dav/exception/length_required'
      require 'tilia/dav/exception/lock_token_matches_request_uri'
      require 'tilia/dav/exception/method_not_allowed'
      require 'tilia/dav/exception/not_authenticated'
      require 'tilia/dav/exception/not_found'
      require 'tilia/dav/exception/not_implemented'
      require 'tilia/dav/exception/payment_required'
      require 'tilia/dav/exception/precondition_failed'
      require 'tilia/dav/exception/unsupported_media_type'
      require 'tilia/dav/exception/report_not_supported'
      require 'tilia/dav/exception/requested_range_not_satisfiable'
      require 'tilia/dav/exception/service_unavailable'
      require 'tilia/dav/exception/too_many_matches'
    end
  end
end
