module Tilia
  module CalDav
    module Subscriptions
      # Subscription Node
      #
      # This node represents a subscription.
      class Subscription < Dav::Collection
        include ISubscription
        include DavAcl::IAcl

        # @!attribute [r] caldav_backend
        #   @!visibility private
        #   caldavBackend
        #
        #   @var SupportsSubscriptions

        # @!attribute [r] subscription_info
        #   @!visibility private
        #   subscriptionInfo
        #
        #   @var array

        # Constructor
        #
        # @param SubscriptionSupport caldav_backend
        # @param array calendar_info
        def initialize(caldav_backend, subscription_info)
          @caldav_backend = caldav_backend
          @subscription_info = subscription_info

          required = [
            'id',
            'uri',
            'principaluri',
            'source'
          ]

          required.each do |r|
            fail ArgumentError, "The #{r} field is required when creating a subscription node" unless subscription_info.key?(r)
          end
        end

        # Returns the name of the node.
        #
        # This is used to generate the url.
        #
        # @return string
        def name
          @subscription_info['uri']
        end

        # Returns the last modification time
        #
        # @return int
        def last_modified
          return @subscription_info['lastmodified'] if @subscription_info.key?('lastmodified')
          nil
        end

        # Deletes the current node
        #
        # @return void
        def delete
          @caldav_backend.delete_subscription(@subscription_info['id'])
        end

        # Returns an array with all the child nodes
        #
        # @return DAV\INode[]
        def children
          []
        end

        # Updates properties on this node.
        #
        # This method received a PropPatch object, which contains all the
        # information about the update.
        #
        # To update specific properties, call the 'handle' method on this object.
        # Read the PropPatch documentation for more information.
        #
        # @param PropPatch prop_patch
        # @return void
        def prop_patch(prop_patch)
          @caldav_backend.update_subscription(
            @subscription_info['id'],
            prop_patch
          )
        end

        # Returns a list of properties for this nodes.
        #
        # The properties list is a list of propertynames the client requested,
        # encoded in clark-notation {xmlnamespace}tagname.
        #
        # If the array is empty, it means 'all properties' were requested.
        #
        # Note that it's fine to liberally give properties back, instead of
        # conforming to the list of requested properties.
        # The Server class will filter out the extra.
        #
        # @param array properties
        # @return void
        def properties(properties)
          r = {}

          properties.each do |prop|
            case prop
            when '{http://calendarserver.org/ns/}source'
              r[prop] = Dav::Xml::Property:: Href.new(@subscription_info['source'], false)
            else
              if @subscription_info.key?(prop)
                r[prop] = @subscription_info[prop]
              end
            end
          end

          r
        end

        # Returns the owner principal.
        #
        # This must be a url to a principal, or null if there's no owner
        #
        # @return string|null
        def owner
          @subscription_info['principaluri']
        end

        # Returns a group principal.
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
            },
            {
              'privilege' => '{DAV:}read',
              'principal' => owner + '/calendar-proxy-write',
              'protected' => true
            },
            {
              'privilege' => '{DAV:}write',
              'principal' => owner + '/calendar-proxy-write',
              'protected' => true
            },
            {
              'privilege' => '{DAV:}read',
              'principal' => owner + '/calendar-proxy-read',
              'protected' => true
            }
          ]
        end

        # Updates the ACL.
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
        # See \Sabre\DAVACL\Plugin::getDefaultSupportedPrivilegeSet for a simple
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
