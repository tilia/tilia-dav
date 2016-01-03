module Tilia
  module Dav
    # Loads the default env for rack
    class ServerMock < Server
      def initialize(tree_or_node = nil)
        super(TestUtil.mock_rack_env, tree_or_node)
      end
    end
  end
end
