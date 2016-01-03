module Tilia
  module CalDav
    # Calendars collection
    #
    # This object is responsible for generating a list of calendar-homes for each
    # user.
    #
    # This is the top-most node for the calendars tree. In most servers this class
    # represents the "/calendars" path.
    class CalendarRoot < DavAcl::AbstractPrincipalCollection
      # @!attribute [r] caldav_backend
      #   @!visibility private
      #   CalDAV backend
      #
      #   @var Sabre\CalDAV\Backend\BackendInterface

      # Constructor
      #
      # This constructor needs both an authentication and a caldav backend.
      #
      # By default this class will show a list of calendar collections for
      # principals in the 'principals' collection. If your main principals are
      # actually located in a different path, use the principal_prefix argument
      # to override this.
      #
      # @param PrincipalBackend\BackendInterface principal_backend
      # @param Backend\BackendInterface caldav_backend
      # @param string principal_prefix
      def initialize(principal_backend, caldav_backend, principal_prefix = 'principals')
        super(principal_backend, principal_prefix)
        @caldav_backend = caldav_backend
      end

      # Returns the nodename
      #
      # We're overriding this, because the default will be the 'principalPrefix',
      # and we want it to be Sabre\CalDAV\Plugin::CALENDAR_ROOT
      #
      # @return string
      def name
        Plugin::CALENDAR_ROOT
      end

      # This method returns a node for a principal.
      #
      # The passed array contains principal information, and is guaranteed to
      # at least contain a uri item. Other properties may or may not be
      # supplied by the authentication backend.
      #
      # @param array principal
      # @return \Sabre\DAV\INode
      def child_for_principal(principal)
        CalendarHome.new(@caldav_backend, principal)
      end
    end
  end
end
