module Tilia
  module CalDav
    # The CalendarObject represents a single VEVENT or VTODO within a Calendar.
    class CalendarObject < Dav::File
      include ICalendarObject
      include DavAcl::IAcl

      # @!attribute [r] caldav_backend
      #   @!visibility private
      #   Sabre\CalDAV\Backend\BackendInterface
      #
      #   @var Sabre\CalDAV\Backend\AbstractBackend

      # @!attribute [r] object_data
      #   @!visibility private
      #   Array with information about this CalendarObject
      #
      #   @var array

      # @!attribute [r] calendar_info
      #   @!visibility private
      #   Array with information about the containing calendar
      #
      #   @var array

      # Constructor
      #
      # The following properties may be passed within object_data:
      #
      #   * calendarid - This must refer to a calendarid from a caldavBackend
      #   * uri - A unique uri. Only the 'basename' must be passed.
      #   * calendardata (optional) - The iCalendar data
      #   * etag - (optional) The etag for this object, MUST be encloded with
      #            double-quotes.
      #   * size - (optional) The size of the data in bytes.
      #   * lastmodified - (optional) format as a unix timestamp.
      #   * acl - (optional) Use this to override the default ACL for the node.
      #
      # @param Backend\BackendInterface caldav_backend
      # @param array calendar_info
      # @param array object_data
      def initialize(caldav_backend, calendar_info, object_data)
        @caldav_backend = caldav_backend

        fail ArgumentError, 'The objectData argument must contain an \'uri\' property' unless object_data.key?('uri')

        @calendar_info = calendar_info
        @object_data = object_data
      end

      # Returns the uri for this object
      #
      # @return string
      def name
        @object_data['uri']
      end

      # Returns the ICalendar-formatted object
      #
      # @return string
      def get
        # Pre-populating the 'calendardata' is optional, if we don't have it
        # already we fetch it from the backend.
        unless @object_data.key?('calendardata')
          @object_data = @caldav_backend.calendar_object(@calendar_info['id'], @object_data['uri'])
        end

        @object_data['calendardata']
      end

      # Updates the ICalendar-formatted object
      #
      # @param string|resource calendar_data
      # @return string
      def put(calendar_data)
        calendar_data = calendar_data.read unless calendar_data.is_a?(String)

        etag = @caldav_backend.update_calendar_object(@calendar_info['id'], @object_data['uri'], calendar_data)
        @object_data['calendardata'] = calendar_data
        @object_data['etag'] = etag

        etag
      end

      # Deletes the calendar object
      #
      # @return void
      def delete
        @caldav_backend.delete_calendar_object(@calendar_info['id'], @object_data['uri'])
      end

      # Returns the mime content-type
      #
      # @return string
      def content_type
        mime = 'text/calendar; charset=utf-8'
        mime += '; component=' + @object_data['component'] unless @object_data['component'].blank?
        mime
      end

      # Returns an ETag for this object.
      #
      # The ETag is an arbitrary string, but MUST be surrounded by double-quotes.
      #
      # @return string
      def etag
        if @object_data.key?('etag')
          return @object_data['etag']
        else
          return "\"#{Digest::MD5.hexdigest(get)}\""
        end
      end

      # Returns the last modification date as a unix timestamp
      #
      # @return int
      def last_modified
        @object_data['lastmodified']
      end

      # Returns the size of this object in bytes
      #
      # @return int
      def size
        if @object_data.key?('size')
          return @object_data['size']
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
        # An alternative acl may be specified in the object data.
        return @object_data['acl'] if @object_data.key?('acl')

        # The default ACL
        [
          {
            'privilege' => '{DAV:}read',
            'principal' => @calendar_info['principaluri'],
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => @calendar_info['principaluri'],
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => @calendar_info['principaluri'] + '/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => @calendar_info['principaluri'] + '/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => @calendar_info['principaluri'] + '/calendar-proxy-read',
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
