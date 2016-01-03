module Tilia
  module Dav
    module Locks
      module Backend
        # This is an Abstract clas for lock backends.
        #
        # Currently this backend has no function, but it exists for consistency, and
        # to ensure that if default code is required in the backend, there will be a
        # non-bc-breaking way to do so.
        class AbstractBackend
          include BackendInterface
        end
      end
    end
  end
end
