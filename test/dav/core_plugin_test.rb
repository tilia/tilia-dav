require 'test_helper'

module Tilia
  module Dav
    class CorePluginTest < Minitest::Test
      def test_get_info
        core_plugin = CorePlugin.new
        assert_equal('core', core_plugin.plugin_info['name'])
      end
    end
  end
end
