module Tilia
  module CalDav
    # This interface represents a Calendar that is shared by a different user.
    module ISharedCalendar
      include ICalendar

      # This method should return the url of the owners' copy of the shared
      # calendar.
      #
      # @return string
      def shared_url
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
