module Tilia
  module Dav
    module Sync
      # This mocks a ISyncCollection, for unittesting.
      #
      # This object behaves the same as SimpleCollection. Call addChange to update
      # the 'changelog' that this class uses for the collection.
      class MockSyncCollection < SimpleCollection
        include ISyncCollection

        attr_accessor :change_log
        attr_accessor :token

        def initialize(*args)
          super
          @change_log = {}
        end

        # This method returns the current sync-token for this collection.
        # This can be any string.
        #
        # If null is returned from this function, the plugin assumes there's no
        # sync information available.
        #
        # @return string|null
        def sync_token
          # Will be 'null' in the first round, and will increment ever after.
          @token
        end

        def add_change(added, modified, deleted)
          @token ||= 0
          @token += 1
          @change_log[@token] = {
            'added'     => added,
            'modified'  => modified,
            'deleted'   => deleted
          }
        end

        # The getChanges method returns all the changes that have happened, since
        # the specified syncToken and the current collection.
        #
        # This function should return an array, such as the following:
        #
        # array(
        #   'syncToken' => 'The current synctoken',
        #   'modified'   => array(
        #      'new.txt',
        #   ),
        #   'deleted' => array(
        #      'foo.php.bak',
        #      'old.txt'
        #   )
        # )
        #
        # The syncToken property should reflect the *current* syncToken of the
        # collection, as reported sync_token. This is needed here too, to
        # ensure the operation is atomic.
        #
        # If the syncToken is specified as null, this is an initial sync, and all
        # members should be reported.
        #
        # The modified property is an array of nodenames that have changed since
        # the last token.
        #
        # The deleted property is an array with nodenames, that have been deleted
        # from collection.
        #
        # The second argument is basically the 'depth' of the report. If it's 1,
        # you only have to report changes that happened only directly in immediate
        # descendants. If it's 2, it should also include changes from the nodes
        # below the child collections. (grandchildren)
        #
        # The third (optional) argument allows a client to specify how many
        # results should be returned at most. If the limit is not specified, it
        # should be treated as infinite.
        #
        # If the limit (infinite or not) is higher than you're willing to return,
        # you should throw a Sabre\DAV\Exception\Too_much_matches exception.
        #
        # If the syncToken is expired (due to data cleanup) or unknown, you must
        # return null.
        #
        # The limit is 'suggestive'. You are free to ignore it.
        #
        # @param string sync_token
        # @param int sync_level
        # @param int limit
        # @return array
        def changes(sync_token, _sync_level, limit = nil)
          # This is an initial sync
          if sync_token.nil?
            return {
              'added' => children.map(&:name),
              'modified' => [],
              'deleted' => [],
              'syncToken' => self.sync_token
            }
          end

          return nil unless sync_token.to_i.to_s == sync_token.to_s
          sync_token = sync_token.to_i

          return nil if @token.nil?

          added    = []
          modified = []
          deleted  = []

          @change_log.each do |token, change|
            next unless token > sync_token
            added += change['added']
            modified += change['modified']
            deleted += change['deleted']

            next unless limit
            left = limit - (modified.size + deleted.size)

            next if left > 0
            break if left == 0
            modified = modified[0..left - 1] if left < 0

            left = limit - (modified.size + deleted.size)

            break if left == 0
            deleted = deleted[0..left - 1] if left < 0
            break
          end

          {
            'syncToken' => @token,
            'added'     => added,
            'modified'  => modified,
            'deleted'   => deleted
          }
        end
      end
    end
  end
end