require 'yaml'

module Tilia
  module Dav
    module Locks
      module Backend
        # This Locks backend stores all locking information in a single file.
        #
        # Note that this is not nearly as robust as a database. If you are considering
        # using this backend, keep in mind that the PDO backend can work with SqLite,
        # which is designed to be a good file-based database.
        #
        # It literally solves the problem this class solves as well, but much better.
        class File < AbstractBackend
          # The storage file
          #
          # @var string
          # RUBY: attr_accessor :locks_file

          # Constructor
          #
          # @param string locks_file path to file
          def initialize(locks_file)
            @locks_file = locks_file
          end

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

            locks = data

            locks.each do |lock|
              next unless lock.uri == uri ||
                          # deep locks on parents
                          (lock.depth != 0 && uri.index("#{lock.uri}/") == 0) ||
                          # locks on children
                          (return_child_locks && lock.uri.index("#{uri}/") == 0)
              new_locks << lock
            end

            # Checking if we can remove any of these locks
            new_locks.each_with_index do |lock, k|
              new_locks.delete_at(k) if Time.now.to_i > lock.timeout + lock.created
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

            locks = data

            locks.each_with_index do |lock, k|
              if lock.token == lock_info.token ||
                 Time.now.to_i > lock.timeout + lock.created
                locks.delete_at(k)
              end
            end

            locks << lock_info
            put_data(locks)
            true
          end

          # Removes a lock from a uri
          #
          # @param string uri
          # @param LockInfo lock_info
          # @return bool
          def unlock(_uri, lock_info)
            locks = data
            locks.each_with_index do |lock, k|
              next unless lock.token == lock_info.token
              locks.delete_at(k)
              put_data(locks)
              return true
            end

            false
          end

          protected

          # Loads the lockdata from the filesystem.
          #
          # @return array
          def data
            return [] unless ::File.exist?(@locks_file)

            # opening up the file, and creating a shared lock
            handle = ::File.open(@locks_file, 'r')
            handle.flock(::File::LOCK_SH)

            # Reading data until the eof
            data = handle.read

            # We're all good
            handle.flock(::File::LOCK_UN)
            handle.close

            # Unserializing and checking if the resource file contains data for this file
            data = YAML.load(data)
            data || []
          end

          # Saves the lockdata
          #
          # @param array new_data
          # @return void
          def put_data(new_data)
            # opening up the file, and creating an exclusive lock
            handle = ::File.open(@locks_file, 'a+')
            handle.flock(::File::LOCK_EX)

            # We can only truncate and rewind once the lock is acquired.
            handle.truncate(0)
            handle.rewind

            handle.write(YAML.dump(new_data))
            handle.flock(::File::LOCK_UN)
            handle.close
          end
        end
      end
    end
  end
end
