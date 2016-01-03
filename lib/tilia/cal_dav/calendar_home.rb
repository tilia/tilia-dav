module Tilia
  module CalDav
    # The CalendarHome represents a node that is usually in a users'
    # calendar-homeset.
    #
    # It contains all the users' calendars, and can optionally contain a
    # notifications collection, calendar subscriptions, a users' inbox, and a
    # users' outbox.
    class CalendarHome
      include Dav::IExtendedCollection
      include DavAcl::IAcl

      # @!attribute [r] caldav_backend
      #   @!visibility private
      #   CalDAV backend
      #
      #   @var Sabre\CalDAV\Backend\BackendInterface

      # @!attribute [r] principal_info
      #   @!visibility private
      #   Principal information
      #
      #   @var array

      # Constructor
      #
      # @param Backend\BackendInterface caldav_backend
      # @param mixed user_uri
      def initialize(caldav_backend, principal_info)
        @caldav_backend = caldav_backend
        @principal_info = principal_info
      end

      # Returns the name of this object
      #
      # @return string
      def name
        name = Http::UrlUtil.split_path(@principal_info['uri']).second
        name
      end

      # Updates the name of this object
      #
      # @param string name
      # @return void
      def name=(_name)
        fail Dav::Exception::Forbidden
      end

      # Deletes this object
      #
      # @return void
      def delete
        fail Dav::Exception::Forbidden
      end

      # Returns the last modification date
      #
      # @return int
      def last_modified
        nil
      end

      # Creates a new file under this object.
      #
      # This is currently not allowed
      #
      # @param string filename
      # @param resource data
      # @return void
      def create_file(_filename, _data = nil)
        fail Dav::Exception::MethodNotAllowed, 'Creating new files in this collection is not supported'
      end

      # Creates a new directory under this object.
      #
      # This is currently not allowed.
      #
      # @param string filename
      # @return void
      def create_directory(_filename)
        fail Dav::Exception::MethodNotAllowed, 'Creating new collections in this collection is not supported'
      end

      # Returns a single calendar, by name
      #
      # @param string name
      # @return Calendar
      def child(name)
        # Special nodes
        if name == 'inbox' &&
           @caldav_backend.is_a?(Backend::SchedulingSupport)
          return Schedule::Inbox.new(@caldav_backend, @principal_info['uri'])
        end
        if name == 'outbox' &&
           @caldav_backend.is_a?(Backend::SchedulingSupport)
          return Schedule::Outbox.new(@principal_info['uri'])
        end
        if name == 'notifications' &&
           @caldav_backend.is_a?(Backend::NotificationSupport)
          return Notifications::Collection.new(@caldav_backend, @principal_info['uri'])
        end

        # Calendars
        @caldav_backend.calendars_for_user(@principal_info['uri']).each do |calendar|
          next unless calendar['uri'] == name
          if @caldav_backend.is_a?(Backend::SharingSupport)
            if calendar.key?('{http://calendarserver.org/ns/}shared-url')
              return SharedCalendar.new(@caldav_backend, calendar)
            else
              return ShareableCalendar.new(@caldav_backend, calendar)
            end
          else
            return Calendar.new(@caldav_backend, calendar)
                      end
        end

        if @caldav_backend.is_a?(Backend::SubscriptionSupport)
          @caldav_backend.subscriptions_for_user(@principal_info['uri']).each do |subscription|
            return Subscriptions::Subscription.new(@caldav_backend, subscription) if subscription['uri'] == name
          end
        end

        fail Dav::Exception::NotFound, "'Node with name '#{name}' could not be found"
      end

      # Checks if a calendar exists.
      #
      # @param string name
      # @return bool
      def child_exists(name)
        return !!child(name)
      rescue Dav::Exception::NotFound
        return false
      end

      # Returns a list of calendars
      #
      # @return array
      def children
        calendars = @caldav_backend.calendars_for_user(@principal_info['uri'])

        objs = []
        calendars.each do |calendar|
          if @caldav_backend.is_a?(Backend::SharingSupport)
            if calendar.key?('{http://calendarserver.org/ns/}shared-url')
              objs << SharedCalendar.new(@caldav_backend, calendar)
            else
              objs << ShareableCalendar.new(@caldav_backend, calendar)
            end
          else
            objs << Calendar.new(@caldav_backend, calendar)
          end
        end

        if @caldav_backend.is_a?(Backend::SchedulingSupport)
          objs << Schedule::Inbox.new(@caldav_backend, @principal_info['uri'])
          objs << Schedule::Outbox.new(@principal_info['uri'])
        end

        # We're adding a notifications node, if it's supported by the backend.
        if @caldav_backend.is_a?(Backend::NotificationSupport)
          objs << Notifications::Collection.new(@caldav_backend, @principal_info['uri'])
        end

        # If the backend supports subscriptions, we'll add those as well,
        if @caldav_backend.is_a?(Backend::SubscriptionSupport)
          @caldav_backend.subscriptions_for_user(@principal_info['uri']).each do |subscription|
            objs << Subscriptions::Subscription.new(@caldav_backend, subscription)
          end
        end

        objs
      end

      # Creates a new calendar or subscription.
      #
      # @param string name
      # @param MkCol mk_col
      # @throws DAV\Exception\InvalidResourceType
      # @return void
      def create_extended_collection(name, mk_col)
        is_calendar = false
        is_subscription = false

        mk_col.resource_type.each do |rt|
          case rt
          when '{DAV:}collection', '{http://calendarserver.org/ns/}shared-owner'
            # ignore
          when '{urn:ietf:params:xml:ns:caldav}calendar'
            is_calendar = true
          when '{http://calendarserver.org/ns/}subscribed'
            is_subscription = true
          else
            fail Dav::Exception::InvalidResourceType, "Unknown resourceType: #{rt}"
          end
        end

        properties = mk_col.remaining_values
        mk_col.remaining_result_code = 201

        if is_subscription
          fail Dav::Exception::InvalidResourceType, 'This backend does not support subscriptions' unless @caldav_backend.is_a?(Backend::SubscriptionSupport)

          @caldav_backend.create_subscription(@principal_info['uri'], name, properties)
        elsif is_calendar
          @caldav_backend.create_calendar(@principal_info['uri'], name, properties)
        else
          fail Dav::Exception::InvalidResourceType, 'You can only create calendars and subscriptions in this collection'
        end

        nil
      end

      # Returns the owner principal
      #
      # This must be a url to a principal, or null if there's no owner
      #
      # @return string|null
      def owner
        @principal_info['uri']
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
            'principal' => @principal_info['uri'],
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => @principal_info['uri'],
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => @principal_info['uri'] + '/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => @principal_info['uri'] + '/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => @principal_info['uri'] + '/calendar-proxy-read',
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

      # This method is called when a user replied to a request to share.
      #
      # This method should return the url of the newly created calendar if the
      # share was accepted.
      #
      # @param string href The sharee who is replying (often a mailto: address)
      # @param int status One of the SharingPlugin::STATUS_* constants
      # @param string calendar_uri The url to the calendar thats being shared
      # @param string in_reply_to The unique id this message is a response to
      # @param string summary A description of the reply
      # @return null|string
      def share_reply(href, status, calendar_uri, in_reply_to, summary = nil)
        fail Dav::Exception::NotImplemented, 'Sharing support is not implemented by this backend.' unless @caldav_backend.is_a?(Backend::SharingSupport)

        @caldav_backend.share_reply(href, status, calendar_uri, in_reply_to, summary)
      end

      # Searches through all of a users calendars and calendar objects to find
      # an object with a specific UID.
      #
      # This method should return the path to this object, relative to the
      # calendar home, so this path usually only contains two parts:
      #
      # calendarpath/objectpath.ics
      #
      # If the uid is not found, return null.
      #
      # This method should only consider * objects that the principal owns, so
      # any calendars owned by other principals that also appear in this
      # collection should be ignored.
      #
      # @param string uid
      # @return string|null
      def calendar_object_by_uid(uid)
        @caldav_backend.calendar_object_by_uid(@principal_info['uri'], uid)
      end
    end
  end
end
