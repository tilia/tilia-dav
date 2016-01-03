module Tilia
  module CalDav
    # This interface represents a Calendar that can be shared with other users.
    module IShareableCalendar
      include ICalendar

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
      end
    end
  end
end
