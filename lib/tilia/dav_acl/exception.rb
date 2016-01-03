module Tilia
  module DavAcl
    module Exception
      require 'tilia/dav_acl/exception/ace_conflict'
      require 'tilia/dav_acl/exception/need_privileges'
      require 'tilia/dav_acl/exception/no_abstract'
      require 'tilia/dav_acl/exception/not_recognized_principal'
      require 'tilia/dav_acl/exception/not_supported_privilege'
    end
  end
end
