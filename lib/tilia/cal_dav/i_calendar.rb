module Tilia
  module CalDav
    # Calendar interface
    #
    # Implement this interface to allow a node to be recognized as an calendar.
    module ICalendar
      include ICalendarObjectContainer
      include DavAcl::IAcl
    end
  end
end
