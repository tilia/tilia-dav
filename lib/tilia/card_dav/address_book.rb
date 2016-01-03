module Tilia
  module CardDav
    # The AddressBook class represents a CardDAV addressbook, owned by a specific user
    #
    # The AddressBook can contain multiple vcards
    class AddressBook < Dav::Collection
      include IAddressBook
      include Dav::IProperties
      include DavAcl::IAcl
      include Dav::Sync::ISyncCollection
      include Dav::IMultiGet

      protected

      # This is an array with addressbook information
      #
      # @var array
      attr_accessor :address_book_info

      # CardDAV backend
      #
      # @var Backend\BackendInterface
      attr_accessor :carddav_backend

      public

      # Constructor
      #
      # @param Backend\BackendInterface carddav_backend
      # @param array address_book_info
      def initialize(carddav_backend, address_book_info)
        @carddav_backend = carddav_backend
        @address_book_info = address_book_info
      end

      # Returns the name of the addressbook
      #
      # @return string
      def name
        @address_book_info['uri']
      end

      # Returns a card
      #
      # @param string name
      # @return \ICard
      def child(name)
        obj = @carddav_backend.card(@address_book_info['id'], name)
        fail Dav::Exception::NotFound, 'Card not found' unless obj

        Card.new(@carddav_backend, @address_book_info, obj)
      end

      # Returns the full list of cards
      #
      # @return array
      def children
        objs = @carddav_backend.cards(@address_book_info['id'])
        children = []
        objs.each do |obj|
          obj['acl'] = child_acl
          children << Card.new(@carddav_backend, @address_book_info, obj)
        end
        children
      end

      # This method receives a list of paths in it's first argument.
      # It must return an array with Node objects.
      #
      # If any children are not found, you do not have to return them.
      #
      # @param string[] paths
      # @return array
      def multiple_children(paths)
        objs = @carddav_backend.multiple_cards(@address_book_info['id'], paths)

        children = []
        (objs || []).each do |obj|
          obj['acl'] = child_acl
          children << Card.new(@carddav_backend, @address_book_info, obj)
        end

        children
      end

      # Creates a new directory
      #
      # We actually block this, as subdirectories are not allowed in addressbooks.
      #
      # @param string name
      # @return void
      def create_directory(_name)
        fail Dav::Exception::MethodNotAllowed, 'Creating collections in addressbooks is not allowed'
      end

      # Creates a new file
      #
      # The contents of the new file must be a valid VCARD.
      #
      # This method may return an ETag.
      #
      # @param string name
      # @param resource vcard_data
      # @return string|null
      def create_file(name, vcard_data = '')
        vcard_data = vcard_data.read unless vcard_data.is_a?(String)

        # Converting to UTF-8, if needed
        vcard_data = Dav::StringUtil.ensure_utf8(vcard_data)

        @carddav_backend.create_card(@address_book_info['id'], name, vcard_data)
      end

      # Deletes the entire addressbook.
      #
      # @return void
      def delete
        @carddav_backend.delete_address_book(@address_book_info['id'])
      end

      # Renames the addressbook
      #
      # @param string new_name
      # @return void
      def name=(_new_name)
        fail Dav::Exception::MethodNotAllowed, 'Renaming addressbooks is not yet supported'
      end

      # Returns the last modification date as a unix timestamp.
      #
      # @return void
      def last_modified
        nil
      end

      # Updates properties on this node.
      #
      # This method received a PropPatch object, which contains all the
      # information about the update.
      #
      # To update specific properties, call the 'handle' method on this object.
      # Read the PropPatch documentation for more information.
      #
      # @param DAV\PropPatch prop_patch
      # @return void
      def prop_patch(prop_patch)
        @carddav_backend.update_address_book(@address_book_info['id'], prop_patch)
      end

      # Returns a list of properties for this nodes.
      #
      # The properties list is a list of propertynames the client requested,
      # encoded in clark-notation {xmlnamespace}tagname
      #
      # If the array is empty, it means 'all properties' were requested.
      #
      # @param array properties
      # @return array
      def properties(properties)
        response = {}
        properties.each do |property_name|
          if @address_book_info.key?(property_name)
            response[property_name] = @address_book_info[property_name]
          end
        end

        response
      end

      # Returns the owner principal
      #
      # This must be a url to a principal, or null if there's no owner
      #
      # @return string|null
      def owner
        @address_book_info['principaluri']
      end

      # Returns a group principal
      #
      # This must be a url to a principal, or null if there's no owner
      #
      # @return string|null
      def group
        nil
      end

      # Returns a list of ACE's for this node.
      #
      # Each ACE has the following properties:
      #   * 'privilege', a string such as {DAV:}read or {DAV:}write. These are
      #     currently the only supported privileges
      #   * 'principal', a url to the principal who owns the node
      #   * 'protected' (optional), indicating that this ACE is not allowed to
      #      be updated.
      #
      # @return array
      def acl
        [
          {
            'privilege' => '{DAV:}read',
            'principal' => owner,
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => owner,
            'protected' => true
          }
        ]
      end

      # This method returns the ACL's for card nodes in this address book.
      # The result of this method automatically gets passed to the
      # card nodes in this address book.
      #
      # @return array
      def child_acl
        [
          {
            'privilege' => '{DAV:}read',
            'principal' => owner,
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => owner,
            'protected' => true
          }
        ]
      end

      # Updates the ACL
      #
      # This method will receive a list of new ACE's.
      #
      # @param array acl
      # @return void
      def acl=(_acl)
        fail Dav::Exception::MethodNotAllowed, 'Changing ACL is not yet supported'
      end

      # Returns the list of supported privileges for this node.
      #
      # The returned data structure is a list of nested privileges.
      # See Sabre\DAVACL\Plugin::getDefaultSupportedPrivilegeSet for a simple
      # standard structure.
      #
      # If null is returned from this method, the default privilege set is used,
      # which is fine for most common usecases.
      #
      # @return array|null
      def supported_privilege_set
        nil
      end

      # This method returns the current sync-token for this collection.
      # This can be any string.
      #
      # If null is returned from this function, the plugin assumes there's no
      # sync information available.
      #
      # @return string|null
      def sync_token
        if @carddav_backend.is_a?(Backend::SyncSupport)
          return @address_book_info['{DAV:}sync-token'] if @address_book_info.key?('{DAV:}sync-token')
          return @address_book_info['{http://sabredav.org/ns}sync-token'] if @address_book_info.key?('{http://sabredav.org/ns}sync-token')
        end

        nil
      end

      # The getChanges method returns all the changes that have happened, since
      # the specified syncToken and the current collection.
      #
      # This function should return an array, such as the following:
      #
      # [
      #   'syncToken' => 'The current synctoken',
      #   'added'   => [
      #      'new.txt',
      #   ],
      #   'modified'   => [
      #      'modified.txt',
      #   ],
      #   'deleted' => [
      #      'foo.php.bak',
      #      'old.txt'
      #   ]
      # ]
      #
      # The syncToken property should reflect the *current* syncToken of the
      # collection, as reported get_sync_token. This is needed here too, to
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
      def changes(sync_token, sync_level, limit = nil)
        return nil unless @carddav_backend.is_a?(Backend::SyncSupport)

        @carddav_backend.changes_for_address_book(
          @address_book_info['id'],
          sync_token,
          sync_level,
          limit
        )
      end
    end
  end
end
