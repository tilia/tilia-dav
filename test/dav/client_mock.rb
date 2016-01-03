module Tilia
  module Dav
    class ClientMock < Client
      attr_accessor :request
      attr_accessor :response

      attr_accessor :url
      attr_accessor :curl_settings

      # Just making this method public
      #
      # @param string url
      # @return string
      def absolute_url(url)
        super
      end

      def do_request(request)
        @request = request
        @response
      end
    end
  end
end
