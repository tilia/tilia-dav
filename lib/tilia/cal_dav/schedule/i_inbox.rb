module Tilia
  module CalDav
    module Schedule
      # Implement this interface to have a node be recognized as a CalDAV scheduling
      # inbox.
      module IInbox
        include ICalendarObjectContainer
        include DavAcl::IAcl
      end
    end
  end
end
