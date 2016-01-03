module Tilia
  module CalDav
    module Principal
      # ProxyWrite principal interface
      #
      # Any principal node implementing this interface will be picked up as a 'proxy
      # principal group'.
      module IProxyWrite
        include DavAcl::IPrincipal
      end
    end
  end
end
