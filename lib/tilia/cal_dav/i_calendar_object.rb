module Tilia
  module CalDav
    # CalendarObject interface
    #
    # Extend the ICalendarObject interface to allow your custom nodes to be picked up as
    # CalendarObjects.
    #
    # Calendar objects are resources such as Events, Todo's or Journals.
    module ICalendarObject
      include Dav::IFile
    end
  end
end
