module Tilia
  module CalDav
    # This object represents a CalDAV calendar that is shared by a different user.
    class SharedCalendar < Calendar
      include ISharedCalendar

      # Constructor
      #
      # @param Backend\BackendInterface caldav_backend
      # @param array calendar_info
      def initialize(caldav_backend, calendar_info)
        required = [
          '{http://calendarserver.org/ns/}shared-url',
          '{http://sabredav.org/ns}owner-principal',
          '{http://sabredav.org/ns}read-only'
        ]

        required.each do |r|
          unless calendar_info.key?(r)
            fail ArgumentError, "The #{r} property must be specified for SharedCalendar(s)"
          end
        end

        super
      end

      # This method should return the url of the owners' copy of the shared
      # calendar.
      #
      # @return string
      def shared_url
        @calendar_info['{http://calendarserver.org/ns/}shared-url']
      end

      # Returns the owner principal
      #
      # This must be a url to a principal, or null if there's no owner
      #
      # @return string|null
      def owner
        @calendar_info['{http://sabredav.org/ns}owner-principal']
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
        # The top-level ACL only contains access information for the true
        # owner of the calendar, so we need to add the information for the
        # sharee.
        acl = super
        acl << {
          'privilege' => '{DAV:}read',
          'principal' => @calendar_info['principaluri'],
          'protected' => true
        }
        if @calendar_info['{http://sabredav.org/ns}read-only']
          acl << {
            'privilege' => '{DAV:}write-properties',
            'principal' => @calendar_info['principaluri'],
            'protected' => true
          }
        else
          acl << {
            'privilege' => '{DAV:}write',
            'principal' => @calendar_info['principaluri'],
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
        acl = super
        acl << {
          'privilege' => '{DAV:}read',
          'principal' => @calendar_info['principaluri'],
          'protected' => true
        }

        unless @calendar_info['{http://sabredav.org/ns}read-only']
          acl << {
            'privilege' => '{DAV:}write',
            'principal' => @calendar_info['principaluri'],
            'protected' => true
          }
        end

        acl
      end

      # Returns the list of people whom this calendar is shared with.
      #
      # Every element in this array should have the following properties:
      #   * href - Often a mailto: address
      #   * commonName - Optional, for example a first + last name
      #   * status - See the Sabre\CalDAV\SharingPlugin::STATUS_ constants.
      #   * readOnly - boolean
      #   * summary - Optional, a description for the share
      #
      # @return array
      def shares
        @caldav_backend.shares(@calendar_info['id'])
      end
    end
  end
end
