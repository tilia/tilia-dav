module Tilia
  module CalDav
    module Backend
      # Adds caldav notification support to a backend.
      #
      # Note: This feature is experimental, and may change in between different
      # SabreDAV versions.
      #
      # Notifications are defined at:
      # http://svn.calendarserver.org/repository/calendarserver/CalendarServer/trunk/doc/Extensions/caldav-notifications.txt
      #
      # These notifications are basically a list of server-generated notifications
      # displayed to the user. Users can dismiss notifications by deleting them.
      #
      # The primary usecase is to allow for calendar-sharing.
      module NotificationSupport
        include BackendInterface

        # Returns a list of notifications for a given principal url.
        #
        # @param string principal_uri
        # @return NotificationInterface[]
        def notifications_for_principal(principal_uri)
        end

        # This deletes a specific notifcation.
        #
        # This may be called by a client once it deems a notification handled.
        #
        # @param string principal_uri
        # @param NotificationInterface notification
        # @return void
        def delete_notification(principal_uri, notification)
        end
      end
    end
  end
end
