module Tilia
  module Dav
    module Locks
      module Backend
        # If you are defining your own Locks backend, you must implement this
        # interface.
        module BackendInterface
          # Returns a list of Sabre\DAV\Locks\LockInfo objects
          #
          # This method should return all the locks for a particular uri, including
          # locks that might be set on a parent uri.
          #
          # If returnChildLocks is set to true, this method should also look for
          # any locks in the subtree of the uri for locks.
          #
          # @param string uri
          # @param bool return_child_locks
          # @return array
          def locks(uri, return_child_locks)
          end

          # Locks a uri
          #
          # @param string uri
          # @param Locks\LockInfo lock_info
          # @return bool
          def lock(uri, lock_info)
          end

          # Removes a lock from a uri
          #
          # @param string uri
          # @param Locks\LockInfo lock_info
          # @return bool
          def unlock(uri, lock_info)
          end
        end
      end
    end
  end
end
