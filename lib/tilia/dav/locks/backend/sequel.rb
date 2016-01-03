module Tilia
  module Dav
    module Locks
      module Backend
        # The Lock manager allows you to handle all file-locks centrally.
        #
        # This Lock Manager stores all its data in a database. You must pass a PDO
        # connection object in the constructor.
        class Sequel < AbstractBackend
          # The PDO tablename this backend uses.
          #
          # @var string
          attr_accessor :table_name

          protected

          # The PDO connection object
          #
          # @var sequel
          attr_accessor :sequel

          public

          # Constructor
          #
          # @param sequel
          def initialize(sequel)
            @sequel = sequel
            @table_name = 'locks'
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
            # NOTE: the following 10 lines or so could be easily replaced by
            # pure sql. MySQL's non-standard string concatenation prevents us
            # from doing this though.
            query = "SELECT owner, token, timeout, created, scope, depth, uri FROM #{@table_name} WHERE (created > (? - timeout)) AND ((uri = ?)"
            params = [Time.now.to_i, uri]

            # We need to check locks for every part in the uri.
            uri_parts = uri.split('/')

            # We already covered the last part of the uri
            uri_parts.pop

            current_path = ''

            uri_parts.each do |part|
              current_path << '/' unless current_path.blank?
              current_path << part

              query << ' OR (depth!=0 AND uri = ?)'
              params << current_path
            end

            if return_child_locks
              query << ' OR (uri LIKE ?)'
              params << "#{uri}/%"
            end

            query << ')'

            lock_list = []
            @sequel.fetch(query, *params) do |row|
              lock_info = LockInfo.new
              lock_info.owner = row[:owner]
              lock_info.token = row[:token]
              lock_info.timeout = row[:timeout]
              lock_info.created = row[:created]
              lock_info.scope = row[:scope]
              lock_info.depth = row[:depth]
              lock_info.uri   = row[:uri]
              lock_list << lock_info
            end

            lock_list
          end

          # Locks a uri
          #
          # @param string uri
          # @param LockInfo lock_info
          # @return bool
          def lock(uri, lock_info)
            # We're making the lock timeout 30 minutes
            lock_info.timeout = 30 * 60
            lock_info.created = Time.now.to_i
            lock_info.uri = uri

            locks = locks(uri, false)
            exists = false
            locks.each do |lock|
              exists = true if lock.token == lock_info.token
            end

            if exists
              update_ds = @sequel[
                "UPDATE #{@table_name} SET owner = ?, timeout = ?, scope = ?, depth = ?, uri = ?, created = ? WHERE token = ?",
                lock_info.owner,
                lock_info.timeout,
                lock_info.scope,
                lock_info.depth,
                uri,
                lock_info.created,
                lock_info.token
              ]
              update_ds.update
            else
              insert_ds = @sequel[
                "INSERT INTO #{@table_name} (owner,timeout,scope,depth,uri,created,token) VALUES (?,?,?,?,?,?,?)",
                lock_info.owner,
                lock_info.timeout,
                lock_info.scope,
                lock_info.depth,
                uri,
                lock_info.created,
                lock_info.token
              ]
              insert_ds.insert
            end

            true
          end

          # Removes a lock from a uri
          #
          # @param string uri
          # @param LockInfo lock_info
          # @return bool
          def unlock(uri, lock_info)
            delete_ds = @sequel[
              "DELETE FROM #{@table_name} WHERE uri = ? AND token = ?",
              uri,
              lock_info.token
            ]
            result = delete_ds.delete

            result == 1
          end
        end
      end
    end
  end
end
