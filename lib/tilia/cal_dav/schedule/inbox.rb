module Tilia
  module CalDav
    module Schedule
      # The CalDAV scheduling inbox
      class Inbox < Dav::Collection
        include IInbox

        # @!attribute [r] caldav_backend
        #   @!visibility private
        #   CalDAV backend
        #
        #   @var Backend\BackendInterface

        # @!attribute [r] principal_uri
        #   @!visibility private
        #   The principal Uri
        #
        #   @var string

        # Constructor
        #
        # @param Backend\SchedulingSupport caldav_backend
        # @param string principal_uri
        def initialize(caldav_backend, principal_uri)
          @caldav_backend = caldav_backend
          @principal_uri = principal_uri
        end

        # Returns the name of the node.
        #
        # This is used to generate the url.
        #
        # @return string
        def name
          'inbox'
        end

        # Returns an array with all the child nodes
        #
        # @return \Sabre\DAV\INode[]
        def children
          objs = @caldav_backend.scheduling_objects(@principal_uri)
          children = []
          objs.each do |obj|
            # obj['acl'] = self.get_acl
            obj['principaluri'] = @principal_uri
            children << SchedulingObject.new(@caldav_backend, obj)
          end

          children
        end

        # Creates a new file in the directory
        #
        # Data will either be supplied as a stream resource, or in certain cases
        # as a string. Keep in mind that you may have to support either.
        #
        # After succesful creation of the file, you may choose to return the ETag
        # of the new file here.
        #
        # The returned ETag must be surrounded by double-quotes (The quotes should
        # be part of the actual string).
        #
        # If you cannot accurately determine the ETag, you should not return it.
        # If you don't store the file exactly as-is (you're transforming it
        # somehow) you should also not return an ETag.
        #
        # This means that if a subsequent GET to this new file does not exactly
        # return the same contents of what was submitted here, you are strongly
        # recommended to omit the ETag.
        #
        # @param string name Name of the file
        # @param resource|string data Initial payload
        # @return null|string
        def create_file(name, data = nil)
          @caldav_backend.create_scheduling_object(@principal_uri, name, data)
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
              'privilege' => '{DAV:}read',
              'principal' => '{DAV:}authenticated',
              'protected' => true
            },
            {
              'privilege' => '{DAV:}write-properties',
              'principal' => owner,
              'protected' => true
            },
            {
              'privilege' => '{DAV:}unbind',
              'principal' => owner,
              'protected' => true
            },
            {
              'privilege' => '{DAV:}unbind',
              'principal' => owner + '/calendar-proxy-write',
              'protected' => true
            },
            {
              'privilege' => "{#{Plugin::NS_CALDAV}}schedule-deliver-invite",
              'principal' => '{DAV:}authenticated',
              'protected' => true
            },
            {
              'privilege' => "{#{Plugin::NS_CALDAV}}schedule-deliver-reply",
              'principal' => '{DAV:}authenticated',
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
          ns = "{#{Plugin::NS_CALDAV}}"

          default = DavAcl::Plugin.default_supported_privilege_set
          default['aggregates'] << {
            'privilege'  => "#{ns}schedule-deliver",
            'aggregates' => [
              { 'privilege' => "#{ns}schedule-deliver-invite" },
              { 'privilege' => "#{ns}schedule-deliver-reply" }
            ]
          }

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
        # documented by \Sabre\CalDAV\CalendarQueryParser.
        #
        # @param array filters
        # @return array
        def calendar_query(filters)
          result = []
          validator = CalendarQueryValidator.new

          objects = @caldav_backend.scheduling_objects(@principal_uri)
          objects.each do |object|
            v_object = VObject::Reader.read(object['calendardata'])

            result << object['uri'] if validator.validate(v_object, filters)

            # Destroy circular references to PHP will GC the object.
            v_object.destroy
          end

          result
        end
      end
    end
  end
end
