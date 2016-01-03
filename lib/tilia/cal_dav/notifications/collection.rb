module Tilia
  module CalDav
    module Notifications
      # This node represents a list of notifications.
      #
      # It provides no additional functionality, but you must implement this
      # interface to allow the Notifications plugin to mark the collection
      # as a notifications collection.
      #
      # This collection should only return Sabre\CalDAV\Notifications\INode nodes as
      # its children.
      class Collection < Dav::Collection
        include ICollection
        include DavAcl::IAcl

        # @!attribute [r] caldav_backend
        #   @!visibility private
        #   The notification backend
        #
        #   @var Sabre\CalDAV\Backend\NotificationSupport

        # @!attribute [r] principal_uri
        #   @!visibility private
        #   Principal uri
        #
        #   @var string

        # Constructor
        #
        # @param CalDAV\Backend\NotificationSupport caldav_backend
        # @param string principal_uri
        def initialize(caldav_backend, principal_uri)
          @caldav_backend = caldav_backend
          @principal_uri = principal_uri
        end

        # Returns all notifications for a principal
        #
        # @return array
        def children
          children = []
          notifications = @caldav_backend.notifications_for_principal(@principal_uri)

          notifications.each do |notification|
            children << Node.new(
              @caldav_backend,
              @principal_uri,
              notification
            )
          end

          children
        end

        # Returns the name of this object
        #
        # @return string
        def name
          'notifications'
        end

        # Returns the owner principal
        #
        # This must be a url to a principal, or null if there's no owner
        #
        # @return string|null
        def owner
          @principal_uri
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
              'principal' => owner,
              'privilege' => '{DAV:}read',
              'protected' => true
            },
            {
              'principal' => owner,
              'privilege' => '{DAV:}write',
              'protected' => true
            }
          ]
        end

        # Updates the ACL
        #
        # This method will receive a list of new ACE's as an array argument.
        #
        # @param array acl
        # @return void
        def acl=(_acl)
          fail Dav::Exception::NotImplemented, 'Updating ACLs is not implemented here'
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
end
