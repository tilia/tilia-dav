module Tilia
  module CalDav
    # This object represents a CalDAV calendar that can be shared with other
    # users.
    class ShareableCalendar < Calendar
      include IShareableCalendar

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
      # @param array add
      # @param array remove
      # @return void
      def update_shares(add, remove)
        @caldav_backend.update_shares(@calendar_info['id'], add, remove)
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

      # Marks this calendar as published.
      #
      # Publishing a calendar should automatically create a read-only, public,
      # subscribable calendar.
      #
      # @param bool value
      # @return void
      def publish_status=(value)
        @caldav_backend.update_publish_status(@calendar_info['id'], value)
      end
    end
  end
end
