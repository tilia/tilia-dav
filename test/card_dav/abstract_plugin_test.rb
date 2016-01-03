require 'test_helper'

module Tilia
  module CardDav
    class AbstractPluginTest < Minitest::Test
      def setup
        @backend = Backend::Mock.new
        principal_backend = DavAcl::PrincipalBackend::Mock.new

        tree = [
          AddressBookRoot.new(principal_backend, @backend),
          DavAcl::PrincipalCollection.new(principal_backend)
        ]

        @plugin = Plugin.new
        @plugin.directories = ['directory']
        @server = Dav::ServerMock.new(tree)
        @server.sapi = Http::SapiMock.new
        @server.add_plugin(@plugin)
        @server.debug_exceptions = true
      end
    end
  end
end
