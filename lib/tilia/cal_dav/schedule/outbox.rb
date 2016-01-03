module Tilia
  module CalDav
    module Schedule
      # The CalDAV scheduling outbox
      #
      # The outbox is mainly used as an endpoint in the tree for a client to do
      # free-busy requests. This functionality is completely handled by the
      # Scheduling plugin, so this object is actually mostly static.
      class Outbox < Dav::Collection
        include IOutbox

        # @!attribute [r] principal_uri
        #   @!visibility private
        #   The principal Uri
        #
        #   @var string

        # Constructor
        #
        # @param string principal_uri
        def initialize(principal_uri)
          @principal_uri = principal_uri
        end

        # Returns the name of the node.
        #
        # This is used to generate the url.
        #
        # @return string
        def name
          'outbox'
        end

        # Returns an array with all the child nodes
        #
        # @return \Sabre\DAV\INode[]
        def children
          []
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
              'privilege' => "{#{Plugin::NS_CALDAV}}schedule-query-freebusy",
              'principal' => owner,
              'protected' => true
            },
            {
              'privilege' => "{#{Plugin::NS_CALDAV}}schedule-post-vevent",
              'principal' => owner,
              'protected' => true
            },
            {
              'privilege' => '{DAV:}read',
              'principal' => owner,
              'protected' => true
            },
            {
              'privilege' => "{#{Plugin::NS_CALDAV}}schedule-query-freebusy",
              'principal' => owner + '/calendar-proxy-write',
              'protected' => true
            },
            {
              'privilege' => "{#{Plugin::NS_CALDAV}}schedule-post-vevent",
              'principal' => owner + '/calendar-proxy-write',
              'protected' => true
            },
            {
              'privilege' => '{DAV:}read',
              'principal' => owner + '/calendar-proxy-read',
              'protected' => true
            },
            {
              'privilege' => '{DAV:}read',
              'principal' => owner + '/calendar-proxy-write',
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
          fail Dav::Exception::MethodNotAllowed, 'You\'re not allowed to update the ACL'
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
          default = DavAcl::Plugin.default_supported_privilege_set
          default['aggregates'] << {
            'privilege' => "{#{Plugin::NS_CALDAV}}schedule-query-freebusy"
          }
          default['aggregates'] << {
            'privilege' => "{#{Plugin::NS_CALDAV}}schedule-post-vevent"
          }

          default
        end
      end
    end
  end
end
