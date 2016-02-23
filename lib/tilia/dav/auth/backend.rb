module Tilia
  module Dav
    module Auth
      module Backend
        require 'tilia/dav/auth/backend/backend_interface'
        require 'tilia/dav/auth/backend/abstract_basic'
        require 'tilia/dav/auth/backend/abstract_bearer'
        require 'tilia/dav/auth/backend/abstract_digest'
        require 'tilia/dav/auth/backend/apache'
        require 'tilia/dav/auth/backend/basic_call_back'
        require 'tilia/dav/auth/backend/file'
        require 'tilia/dav/auth/backend/sequel'
      end
    end
  end
end
