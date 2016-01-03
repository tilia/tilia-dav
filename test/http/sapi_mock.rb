module Tilia
  module Http
    # HTTP Response Mock object
    #
    # This class exists to make the transition to sabre/http easier.
    #
    # @copyright Copyright (C) 2007-2015 fruux GmbH (https://fruux.com/).
    # @author Evert Pot (http://evertpot.com/)
    # @license http://sabre.io/license/ Modified BSD License
    class SapiMock < Sapi
      @sent = 0
      class << self
        attr_accessor :sent
      end

      def initialize(env = {})
        env = Rack::MockRequest.env_for.merge env
        super(env)
      end

      # Overriding this so nothing is ever echo'd.
      #
      # @return void
      def self.send_response(_response)
        self.sent += 1
      end
    end
  end
end
