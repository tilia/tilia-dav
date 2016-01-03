module Tilia
  module CalDav
    module Backend
      # Implementing this interface adds CalDAV Scheduling support to your caldav
      # server, as defined in rfc6638.
      module SchedulingSupport
        include BackendInterface

        # Returns a single scheduling object for the inbox collection.
        #
        # The returned array should contain the following elements:
        #   * uri - A unique basename for the object. This will be used to
        #           construct a full uri.
        #   * calendardata - The iCalendar object
        #   * lastmodified - The last modification date. Can be an int for a unix
        #                    timestamp, or a PHP DateTime object.
        #   * etag - A unique token that must change if the object changed.
        #   * size - The size of the object, in bytes.
        #
        # @param string principal_uri
        # @param string object_uri
        # @return array
        def scheduling_object(principal_uri, object_uri)
        end

        # Returns all scheduling objects for the inbox collection.
        #
        # These objects should be returned as an array. Every item in the array
        # should follow the same structure as returned from getSchedulingObject.
        #
        # The main difference is that 'calendardata' is optional.
        #
        # @param string principal_uri
        # @return array
        def scheduling_objects(principal_uri)
        end

        # Deletes a scheduling object from the inbox collection.
        #
        # @param string principal_uri
        # @param string object_uri
        # @return void
        def delete_scheduling_object(principal_uri, object_uri)
        end

        # Creates a new scheduling object. This should land in a users' inbox.
        #
        # @param string principal_uri
        # @param string object_uri
        # @param string object_data
        # @return void
        def create_scheduling_object(principal_uri, object_uri, object_data)
        end
      end
    end
  end
end
