module Tilia
  module CalDav
    module Notifications
      # This node represents a single notification.
      #
      # The signature is mostly identical to that of Sabre\DAV\IFile, but the get method
      # MUST return an xml document that matches the requirements of the
      # 'caldav-notifications.txt' spec.
      #
      # For a complete example, check out the Notification class, which contains
      # some helper functions.
      module INode
        # This method must return an xml element, using the
        # Sabre\CalDAV\Notifications\INotificationType classes.
        #
        # @return INotificationType
        def notification_type
        end

        # Returns the etag for the notification.
        #
        # The etag must be surrounded by litteral double-quotes.
        #
        # @return string
        def etag
        end
      end
    end
  end
end
