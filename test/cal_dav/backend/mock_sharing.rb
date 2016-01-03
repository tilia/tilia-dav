module Tilia
  module CalDav
    module Backend
      class MockSharing < Mock
        include NotificationSupport
        include SharingSupport

        def initialize(calendars = [], calendar_data = {}, notifications = {})
          super(calendars, calendar_data)
          @shares = {}
          @notifications = notifications
        end

        # Returns a list of notifications for a given principal url.
        #
        # The returned array should only consist of implementations of
        # Notifications\INotificationType.
        #
        # @param string principal_uri
        # @return array
        def notifications_for_principal(principal_uri)
          @notifications[principal_uri] || []
        end

        # This deletes a specific notifcation.
        #
        # This may be called by a client once it deems a notification handled.
        #
        # @param string principal_uri
        # @param NotificationInterface notification
        # @return void
        def delete_notification(principal_uri, notification)
          @notifications[principal_uri].delete_if do |value|
            notification == value
          end
        end

        # Updates the list of shares.
        #
        # The first array is a list of people that are to be added to the
        # calendar.
        #
        # Every element in the add array has the following properties:
        #   * href - A url. Usually a mailto: address
        #   * commonName - Usually a first and last name, or false
        #   * summary - A description of the share, can also be false
        #   * readOnly - A boolean value
        #
        # Every element in the remove array is just the address string.
        #
        # Note that if the calendar is currently marked as 'not shared' by and
        # this method is called, the calendar should be 'upgraded' to a shared
        # calendar.
        #
        # @param mixed calendar_id
        # @param array add
        # @param array remove
        # @return void
        def update_shares(calendar_id, add, remove)
          @shares[calendar_id] ||= []

          add.each do |val|
            val['status'] = SharingPlugin::STATUS_NORESPONSE
            @shares[calendar_id] << val
          end

          @shares[calendar_id].delete_if do |share|
            remove.include?(share['href'])
          end
        end

        # Returns the list of people whom this calendar is shared with.
        #
        # Every element in this array should have the following properties:
        #   * href - Often a mailto: address
        #   * commonName - Optional, for example a first + last name
        #   * status - See the SharingPlugin::STATUS_ constants.
        #   * readOnly - boolean
        #   * summary - Optional, a description for the share
        #
        # @param mixed calendar_id
        # @return array
        def shares(calendar_id)
          @shares[calendar_id] || []
        end

        # This method is called when a user replied to a request to share.
        #
        # @param string href The sharee who is replying (often a mailto: address)
        # @param int status One of the SharingPlugin::STATUS_* constants
        # @param string calendar_uri The url to the calendar thats being shared
        # @param string in_reply_to The unique id this message is a response to
        # @param string summary A description of the reply
        # @return void
        def share_reply(_href, status, _calendar_uri, _in_reply_to, _summary = nil)
          # This operation basically doesn't do anything yet
          if status == SharingPlugin::STATUS_ACCEPTED
            return 'calendars/blabla/calendar'
          end
          nil
        end

        # Publishes a calendar
        #
        # @param mixed calendar_id
        # @param bool value
        # @return void
        def set_publish_status(calendar_id, value)
          @calendars.each do |_k, cal|
            next unless cal['id'] == calendar_id
            if !value
              cal.delete('{http://calendarserver.org/ns/}publish-url')
            else
              cal['{http://calendarserver.org/ns/}publish-url'] = 'http://example.org/public/ ' + calendar_id + '.ics'
                          end
            return nil
          end

          fail Dav::Exception, "Calendar with id '#{calendar_id}' not found"
        end
      end
    end
  end
end
