module Tilia
  module CalDav
    module Notifications
      # This node represents a single notification.
      #
      # The signature is mostly identical to that of Sabre\DAV\IFile, but the get method
      # MUST return an xml document that matches the requirements of the
      # 'caldav-notifications.txt' spec.
      class Node < Dav::File
        include INode
        include DavAcl::IAcl

        # @!attribute [r] caldav_backend
        #   @!visibility private
        #   The notification backend
        #
        #   @var Sabre\CalDAV\Backend\NotificationSupport

        # @!attribute [r] notification
        #   @!visibility private
        #   The actual notification
        #
        #   @var Sabre\CalDAV\Notifications\INotificationType

        # @!attribute [r] principal_uri
        #   @!visibility private
        #   Owner principal of the notification
        #
        #   @var string

        # Constructor
        #
        # @param CalDAV\Backend\NotificationSupport caldav_backend
        # @param string principal_uri
        # @param NotificationInterface notification
        def initialize(caldav_backend, principal_uri, notification)
          @caldav_backend = caldav_backend
          @principal_uri = principal_uri
          @notification = notification
        end

        # Returns the path name for this notification
        #
        # @return id
        def name
          @notification.id.to_s + '.xml'
        end

        # Returns the etag for the notification.
        #
        # The etag must be surrounded by litteral double-quotes.
        #
        # @return string
        def etag
          @notification.etag
        end

        # This method must return an xml element, using the
        # Sabre\CalDAV\Notifications\INotificationType classes.
        #
        # @return INotificationType
        def notification_type
          @notification
        end

        # Deletes this notification
        #
        # @return void
        def delete
          @caldav_backend.delete_notification(owner, @notification)
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
