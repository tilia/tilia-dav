module Tilia
  module Dav
    module Locks
      module Backend
        # Locks Mock backend.
        #
        # This backend stores lock information in memory. Mainly useful for testing.
        class Mock < AbstractBackend
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
            new_locks = []

            @locks.each do |lock|
              next unless lock.uri == uri ||
                          # deep locks on parents
                          (lock.depth != 0 && uri.index("#{lock.uri}/") == 0) ||

                          # locks on children
                          (return_child_locks && (lock.uri.index("#{uri}/") == 0))
              new_locks << lock
            end

            # Checking if we can remove any of these locks
            new_locks.delete_if do |lock|
              Time.now.to_i > lock.timeout + lock.created
            end
            new_locks
          end

          # Locks a uri
          #
          # @param string uri
          # @param LockInfo lock_info
          # @return bool
          def lock(uri, lock_info)
            # We're making the lock timeout 30 minutes
            lock_info.timeout = 1800
            lock_info.created = Time.now.to_i
            lock_info.uri = uri

            @locks.delete_if do |lock|
              (lock.token == lock_info.token) || (Time.now.to_i > lock.timeout + lock.created)
            end

            @locks << lock_info
            true
          end

          # Removes a lock from a uri
          #
          # @param string uri
          # @param LockInfo lock_info
          # @return bool
          def unlock(_uri, lock_info)
            @locks.each_with_index do |lock, k|
              if lock.token == lock_info.token
                @locks.delete_at(k)
                return true
              end
            end

            false
          end

          def initialize
            @locks = []
          end
        end
      end
    end
  end
end
