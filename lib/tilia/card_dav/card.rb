module Tilia
  module CardDav
    # The Card object represents a single Card from an addressbook
    class Card < Dav::File
      include ICard
      include DavAcl::IAcl

      protected

      # CardDAV backend
      #
      # @var Backend\BackendInterface
      attr_accessor :carddav_backend

      # Array with information about this Card
      #
      # @var array
      attr_accessor :card_data

      # Array with information about the containing addressbook
      #
      # @var array
      attr_accessor :address_book_info

      public

      # Constructor
      #
      # @param Backend\BackendInterface carddav_backend
      # @param array address_book_info
      # @param array card_data
      def initialize(carddav_backend, address_book_info, card_data)
        @carddav_backend = carddav_backend
        @address_book_info = address_book_info
        @card_data = card_data
      end

      # Returns the uri for this object
      #
      # @return string
      def name
        @card_data['uri']
      end

      # Returns the VCard-formatted object
      #
      # @return string
      def get
        # Pre-populating 'carddata' is optional. If we don't yet have it
        # already, we fetch it from the backend.
        @card_data = @carddav_backend.card(@address_book_info['id'], @card_data['uri']) unless @card_data.key?('carddata')

        @card_data['carddata']
      end

      # Updates the VCard-formatted object
      #
      # @param string card_data
      # @return string|null
      def put(card_data)
        card_data = card_data.read unless card_data.is_a?(String)

        # Converting to UTF-8, if needed
        card_data = Dav::StringUtil.ensure_utf8(card_data)

        etag = @carddav_backend.update_card(@address_book_info['id'], @card_data['uri'], card_data)
        @card_data['carddata'] = card_data
        @card_data['etag'] = etag

        etag
      end

      # Deletes the card
      #
      # @return void
      def delete
        @carddav_backend.delete_card(@address_book_info['id'], @card_data['uri'])
      end

      # Returns the mime content-type
      #
      # @return string
      def content_type
        'text/vcard; charset=utf-8'
      end

      # Returns an ETag for this object
      #
      # @return string
      def etag
        if @card_data.key?('etag')
          return @card_data['etag']
        else
          data = get
          if data.is_a?(String)
            return "\"#{Digest::MD5.hexdigest(data)}\""
          else
            # We refuse to calculate the md5 if it's a stream.
            return nil
          end
        end
      end

      # Returns the last modification date as a unix timestamp
      #
      # @return int
      def last_modified
        @card_data.key?('lastmodified') ? @card_data['lastmodified'] : nil
      end

      # Returns the size of this object in bytes
      #
      # @return int
      def size
        if @card_data.key?('size')
          return @card_data['size']
        else
          return get.size
        end
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
        # An alternative acl may be specified through the cardData array.
        return @card_data['acl'] if @card_data.key?('acl')

        [
          {
            'privilege' => '{DAV:}read',
            'principal' => @address_book_info['principaluri'],
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => @address_book_info['principaluri'],
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
    end
  end
end
