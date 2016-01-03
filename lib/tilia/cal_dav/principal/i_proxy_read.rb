module Tilia
  module CalDav
    module Principal
      # ProxyRead principal interface
      #
      # Any principal node implementing this interface will be picked up as a 'proxy
      # principal group'.
      module IProxyRead
        include DavAcl::IPrincipal
      end
    end
  end
end
