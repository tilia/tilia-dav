require 'test_helper'

module Tilia
  module Dav
    module Auth
      class PluginTest < Minitest::Test
        def test_init
          fake_server = ServerMock.new(SimpleCollection.new('bla'))
          plugin = Auth::Plugin.new(Auth::Backend::Mock.new)
          assert_kind_of(Auth::Plugin, plugin)
          fake_server.add_plugin(plugin)
          assert_equal(plugin, fake_server.plugin('auth'))
          assert_kind_of(Hash, plugin.plugin_info)
        end

        def test_authenticate
          fake_server = ServerMock.new(SimpleCollection.new('bla'))
          plugin = Auth::Plugin.new(Auth::Backend::Mock.new)
          fake_server.add_plugin(plugin)
          assert(fake_server.emit('beforeMethod', [Http::Request.new, Http::Response.new]))
        end

        def test_authenticate_fail
          fake_server = ServerMock.new(SimpleCollection.new('bla'))
          backend = Auth::Backend::Mock.new
          backend.fail = true

          plugin = Auth::Plugin.new(backend)
          fake_server.add_plugin(plugin)
          assert_raises(Exception::NotAuthenticated) do
            fake_server.emit('beforeMethod', [Http::Request.new, Http::Response.new])
          end
        end

        def test_multiple_backend
          fake_server = ServerMock.new(SimpleCollection.new('bla'))
          backend1 = Auth::Backend::Mock.new
          backend2 = Auth::Backend::Mock.new
          backend2.fail = true

          plugin = Auth::Plugin.new
          plugin.add_backend(backend1)
          plugin.add_backend(backend2)

          fake_server.add_plugin(plugin)
          fake_server.emit('beforeMethod', [Http::Request.new, Http::Response.new])

          assert_equal('principals/admin', plugin.current_principal)
        end

        def test_no_auth_backend
          fake_server = ServerMock.new(SimpleCollection.new('bla'))

          plugin = Auth::Plugin.new
          fake_server.add_plugin(plugin)

          assert_raises(Exception) do
            fake_server.emit('beforeMethod', [Http::Request.new, Http::Response.new])
          end
        end

        def test_invalid_check_response
          fake_server = ServerMock.new(SimpleCollection.new('bla'))
          backend = Auth::Backend::Mock.new
          backend.invalid_check_response = true

          plugin = Auth::Plugin.new(backend)
          fake_server.add_plugin(plugin)
          assert_raises(Exception) do
            fake_server.emit('beforeMethod', [Http::Request.new, Http::Response.new])
          end
        end

        def test_current_principal
          fake_server = ServerMock.new(SimpleCollection.new('bla'))
          plugin = Auth::Plugin.new(Auth::Backend::Mock.new)
          fake_server.add_plugin(plugin)
          fake_server.emit('beforeMethod', [Http::Request.new, Http::Response.new])
          assert_equal('principals/admin', plugin.current_principal)
        end

        def test_current_user
          fake_server = ServerMock.new(SimpleCollection.new('bla'))
          plugin = Auth::Plugin.new(Auth::Backend::Mock.new)
          fake_server.add_plugin(plugin)
          fake_server.emit('beforeMethod', [Http::Request.new, Http::Response.new])
          assert_equal('admin', plugin.current_user)
        end
      end
    end
  end
end
