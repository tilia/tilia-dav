require 'test_helper'

module Tilia
  module CalDav
    module Principal
      class ProxyWriteTest < Minitest::Test
        def setup
          @backend = DavAcl::PrincipalBackend::Mock.new
          @principal = ProxyWrite.new(
            @backend,
            'uri' => 'principal/user'
          )
        end

        def test_get_name
          assert_equal('calendar-proxy-write', @principal.name)
        end

        def test_get_display_name
          assert_equal('calendar-proxy-write', @principal.display_name)
        end

        def test_get_principal_uri
          assert_equal('principal/user/calendar-proxy-write', @principal.principal_url)
        end
      end
    end
  end
end
