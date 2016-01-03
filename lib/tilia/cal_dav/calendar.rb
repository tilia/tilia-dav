module Tilia
  module CalDav
    # This object represents a CalDAV calendar.
    #
    # A calendar can contain multiple TODO and or Events. These are represented
    # as \Sabre\CalDAV\CalendarObject objects.
    class Calendar
      include ICalendar
      include Dav::IProperties
      include Dav::Sync::ISyncCollection
      include Dav::IMultiGet

      # @!attribute [r] calendar_info
      #   @!visibility private
      #   This is an array with calendar information
      #
      #   @var array

      # @!attribute [r] caldav_backend
      #   @!visibility private
      #   CalDAV backend
      #
      #   @var Backend\BackendInterface

      # Constructor
      #
      # @param Backend\BackendInterface caldav_backend
      # @param array calendar_info
      def initialize(caldav_backend, calendar_info)
        @caldav_backend = caldav_backend
        @calendar_info = calendar_info
      end

      # Returns the name of the calendar
      #
      # @return string
      def name
        @calendar_info['uri']
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
        @caldav_backend.update_calendar(@calendar_info['id'], prop_patch)
      end

      # Returns the list of properties
      #
      # @param array requested_properties
      # @return array
      def properties(_requested_properties)
        response = {}

        @calendar_info.each do |prop_name, _prop_value|
          response[prop_name] = @calendar_info[prop_name] if prop_name[0] == '{'
        end

        response
      end

      # Returns a calendar object
      #
      # The contained calendar objects are for example Events or Todo's.
      #
      # @param string name
      # @return \Sabre\CalDAV\ICalendarObject
      def child(name)
        obj = @caldav_backend.calendar_object(@calendar_info['id'], name)

        fail Dav::Exception::NotFound, 'Calendar object not found' unless obj

        obj['acl'] = child_acl

        CalendarObject.new(@caldav_backend, @calendar_info, obj)
      end

      # Returns the full list of calendar objects
      #
      # @return array
      def children
        objs = @caldav_backend.calendar_objects(@calendar_info['id'])

        children = []
        objs.each do |obj|
          obj['acl'] = child_acl
          children << CalendarObject.new(@caldav_backend, @calendar_info, obj)
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
        objs = @caldav_backend.multiple_calendar_objects(@calendar_info['id'], paths)

        children = []
        objs.each do |obj|
          obj['acl'] = child_acl
          children << CalendarObject.new(@caldav_backend, @calendar_info, obj)
        end

        children
      end

      # Checks if a child-node exists.
      #
      # @param string name
      # @return bool
      def child_exists(name)
        obj = @caldav_backend.calendar_object(@calendar_info['id'], name)

        if !obj
          return false
        else
          return true
        end
      end

      # Creates a new directory
      #
      # We actually block this, as subdirectories are not allowed in calendars.
      #
      # @param string name
      # @return void
      def create_directory(_name)
        fail Dav::Exception::MethodNotAllowed, 'Creating collections in calendar objects is not allowed'
      end

      # Creates a new file
      #
      # The contents of the new file must be a valid ICalendar string.
      #
      # @param string name
      # @param resource calendar_data
      # @return string|null
      def create_file(name, calendar_data = nil)
        calendar_data = calendar_data.read unless calendar_data.is_a?(String)

        @caldav_backend.create_calendar_object(@calendar_info['id'], name, calendar_data)
      end

      # Deletes the calendar.
      #
      # @return void
      def delete
        @caldav_backend.delete_calendar(@calendar_info['id'])
      end

      # Renames the calendar. Note that most calendars use the
      # {DAV:}displayname to display a name to display a name.
      #
      # @param string new_name
      # @return void
      def name=(_new_name)
        fail Dav::Exception::MethodNotAllowed, 'Renaming calendars is not yet supported'
      end

      # Returns the last modification date as a unix timestamp.
      #
      # @return void
      def last_modified
        nil
      end

      # Returns the owner principal
      #
      # This must be a url to a principal, or null if there's no owner
      #
      # @return string|null
      def owner
        @calendar_info['principaluri']
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
        acl = [
          {
            'privilege' => '{DAV:}read',
            'principal' => owner,
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => owner + '/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => owner + '/calendar-proxy-read',
            'protected' => true
          },
          {
            'privilege' => "{#{Plugin::NS_CALDAV}}read-free-busy",
            'principal' => '{DAV:}authenticated',
            'protected' => true
          }

        ]
        unless @calendar_info['{http://sabredav.org/ns}read-only']
          acl << {
            'privilege' => '{DAV:}write',
            'principal' => owner,
            'protected' => true
          }
          acl << {
            'privilege' => '{DAV:}write',
            'principal' => owner + '/calendar-proxy-write',
            'protected' => true
          }
        end

        acl
      end

      # This method returns the ACL's for calendar objects in this calendar.
      # The result of this method automatically gets passed to the
      # calendar-object nodes in the calendar.
      #
      # @return array
      def child_acl
        acl = [
          {
            'privilege' => '{DAV:}read',
            'principal' => owner,
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => owner + '/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => owner + '/calendar-proxy-read',
            'protected' => true
          }

        ]
        unless @calendar_info['{http://sabredav.org/ns}read-only']
          acl << {
            'privilege' => '{DAV:}write',
            'principal' => owner,
            'protected' => true
          }
          acl << {
            'privilege' => '{DAV:}write',
            'principal' => owner + '/calendar-proxy-write',
            'protected' => true
          }
        end

        acl
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
      # See \Sabre\DAVACL\Plugin::getDefaultSupportedPrivilegeSet for a simple
      # standard structure.
      #
      # If null is returned from this method, the default privilege set is used,
      # which is fine for most common usecases.
      #
      # @return array|null
      def supported_privilege_set
        default = DavAcl::Plugin.default_supported_privilege_set

        # We need to inject 'read-free-busy' in the tree, aggregated under
        # {DAV:}read.
        default['aggregates'].each do |agg|
          next unless agg['privilege'] == '{DAV:}read'

          agg['aggregates'] << {
            'privilege' => "{#{Plugin::NS_CALDAV}}read-free-busy"
          }
        end

        default
      end

      # Performs a calendar-query on the contents of this calendar.
      #
      # The calendar-query is defined in RFC4791 : CalDAV. Using the
      # calendar-query it is possible for a client to request a specific set of
      # object, based on contents of iCalendar properties, date-ranges and
      # iCalendar component types (VTODO, VEVENT).
      #
      # This method should just return a list of (relative) urls that match this
      # query.
      #
      # The list of filters are specified as an array. The exact array is
      # documented by Sabre\CalDAV\CalendarQueryParser.
      #
      # @param array filters
      # @return array
      def calendar_query(filters)
        @caldav_backend.calendar_query(@calendar_info['id'], filters)
      end

      # This method returns the current sync-token for this collection.
      # This can be any string.
      #
      # If null is returned from this function, the plugin assumes there's no
      # sync information available.
      #
      # @return string|null
      def sync_token
        if @caldav_backend.is_a?(Backend::SyncSupport) &&
           @calendar_info.key?('{DAV:}sync-token')
          return @calendar_info['{DAV:}sync-token']
        end

        if @caldav_backend.is_a?(Backend::SyncSupport) &&
           @calendar_info.key?('{http://sabredav.org/ns}sync-token')
          return @calendar_info['{http://sabredav.org/ns}sync-token']
        end
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
      # you should throw a Sabre\DAV\Exception\TooMuchMatches exception.
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
        return nil unless @caldav_backend.is_a?(Backend::SyncSupport)

        @caldav_backend.changes_for_calendar(
          @calendar_info['id'],
          sync_token,
          sync_level,
          limit
        )
      end
    end
  end
end
