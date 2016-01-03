module Tilia
  module Dav
    class TestPlugin < ServerPlugin
      attr_accessor :saved_before_method

      def features
        %w(drinking)
      end

      def http_methods(_uri)
        %w(BEER WINE)
      end

      def setup(server)
        server.on('beforeMethod', method(:before_method))
      end

      def before_method(request, _response)
        @saved_before_method = request.method
        true
      end
    end
  end
end
