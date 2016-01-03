module Tilia
  module CalDav
    module Schedule
      # The SchedulingObject represents a scheduling object in the Inbox collection
      class SchedulingObject < CalendarObject
        include ISchedulingObject

        # @!attribute [r] caldav_backend
        #   @!visibility private
        #   The CalDAV backend
        #
        #   @var Backend\SchedulingSupport

        # @!attribute [r] object_data
        #   @!visibility private
        #   Array with information about this SchedulingObject
        #
        #   @var array

        # Constructor
        #
        # The following properties may be passed within object_data:
        #
        #   * uri - A unique uri. Only the 'basename' must be passed.
        #   * principaluri - the principal that owns the object.
        #   * calendardata (optional) - The iCalendar data
        #   * etag - (optional) The etag for this object, MUST be encloded with
        #            double-quotes.
        #   * size - (optional) The size of the data in bytes.
        #   * lastmodified - (optional) format as a unix timestamp.
        #   * acl - (optional) Use this to override the default ACL for the node.
        #
        # @param Backend\BackendInterface caldav_backend
        # @param array object_data
        def initialize(caldav_backend, object_data)
          @caldav_backend = caldav_backend

          fail ArgumentError, 'The objectData argument must contain an \'uri\' property' unless object_data.key?('uri')

          @object_data = object_data
        end

        # Returns the ICalendar-formatted object
        #
        # @return string
        def get
          # Pre-populating the 'calendardata' is optional, if we don't have it
          # already we fetch it from the backend.
          unless @object_data.key?('calendardata')
            @object_data = @caldav_backend.scheduling_object(@object_data['principaluri'], @object_data['uri'])
          end
          @object_data['calendardata']
        end

        # Updates the ICalendar-formatted object
        #
        # @param string|resource calendar_data
        # @return string
        def put(_calendar_data)
          fail Dav::Exception::MethodNotAllowed, 'Updating scheduling objects is not supported'
        end

        # Deletes the scheduling message
        #
        # @return void
        def delete
          @caldav_backend.delete_scheduling_object(@object_data['principaluri'], @object_data['uri'])
        end

        # Returns the owner principal
        #
        # This must be a url to a principal, or null if there's no owner
        #
        # @return string|null
        def owner
          @object_data['principaluri']
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
          #
          return @object_data['acl'] if @object_data.key?('acl')

          # The default ACL
          [
            {
              'privilege' => '{DAV:}read',
              'principal' => @object_data['principaluri'],
              'protected' => true
            },
            {
              'privilege' => '{DAV:}write',
              'principal' => @object_data['principaluri'],
              'protected' => true
            },
            {
              'privilege' => '{DAV:}read',
              'principal' => @object_data['principaluri'] + '/calendar-proxy-write',
              'protected' => true
            },
            {
              'privilege' => '{DAV:}write',
              'principal' => @object_data['principaluri'] + '/calendar-proxy-write',
              'protected' => true
            },
            {
              'privilege' => '{DAV:}read',
              'principal' => @object_data['principaluri'] + '/calendar-proxy-read',
              'protected' => true
            }
          ]
        end
      end
    end
  end
end
