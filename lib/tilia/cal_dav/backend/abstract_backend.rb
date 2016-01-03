module Tilia
  module CalDav
    module Backend
      # Abstract Calendaring backend. Extend this class to create your own backends.
      #
      # Checkout the BackendInterface for all the methods that must be implemented.
      class AbstractBackend
        include BackendInterface

        # Updates properties for a calendar.
        #
        # The list of mutations is stored in a Sabre\DAV\PropPatch object.
        # To do the actual updates, you must tell this object which properties
        # you're going to process with the handle method.
        #
        # Calling the handle method is like telling the PropPatch object "I
        # promise I can handle updating this property".
        #
        # Read the PropPatch documenation for more info and examples.
        #
        # @param string path
        # @param \Sabre\DAV\PropPatch prop_patch
        # @return void
        def update_calendar(calendar_id, prop_patch)
        end

        # Returns a list of calendar objects.
        #
        # This method should work identical to getCalendarObject, but instead
        # return all the calendar objects in the list as an array.
        #
        # If the backend supports this, it may allow for some speed-ups.
        #
        # @param mixed calendar_id
        # @param array uris
        # @return array
        def multiple_calendar_objects(calendar_id, uris)
          uris.map do |uri|
            calendar_object(calendar_id, uri)
          end
        end

        # Performs a calendar-query on the contents of this calendar.
        #
        # The calendar-query is defined in RFC4791 : CalDAV. Using the
        # calendar-query it is possible for a client to request a specific set of
        # object, based on contents of iCalendar properties, date-ranges and
        # iCalendar component types (VTODO, VEVENT).
        #
        # This method should just return a list of (relative) urls that match this
        # query.
        #
        # The list of filters are specified as an array. The exact array is
        # documented by \Sabre\CalDAV\CalendarQueryParser.
        #
        # Note that it is extremely likely that getCalendarObject for every path
        # returned from this method will be called almost immediately after. You
        # may want to anticipate this to speed up these requests.
        #
        # This method provides a default implementation, which parses *all* the
        # iCalendar objects in the specified calendar.
        #
        # This default may well be good enough for personal use, and calendars
        # that aren't very large. But if you anticipate high usage, big calendars
        # or high loads, you are strongly adviced to optimize certain paths.
        #
        # The best way to do so is override this method and to optimize
        # specifically for 'common filters'.
        #
        # Requests that are extremely common are:
        #   * requests for just VEVENTS
        #   * requests for just VTODO
        #   * requests with a time-range-filter on either VEVENT or VTODO.
        #
        # ..and combinations of these requests. It may not be worth it to try to
        # handle every possible situation and just rely on the (relatively
        # easy to use) CalendarQueryValidator to handle the rest.
        #
        # Note that especially time-range-filters may be difficult to parse. A
        # time-range filter specified on a VEVENT must for instance also handle
        # recurrence rules correctly.
        # A good example of how to interprete all these filters can also simply
        # be found in \Sabre\CalDAV\CalendarQueryFilter. This class is as correct
        # as possible, so it gives you a good idea on what type of stuff you need
        # to think of.
        #
        # @param mixed calendar_id
        # @param array filters
        # @return array
        def calendar_query(calendar_id, filters)
          result = []
          objects = calendar_objects(calendar_id)

          objects.each do |object|
            result << object['uri'] if validate_filter_for_object(object, filters)
          end

          result
        end

        protected

        # This method validates if a filter (as passed to calendarQuery) matches
        # the given object.
        #
        # @param array object
        # @param array filters
        # @return bool
        def validate_filter_for_object(object, filters)
          # Unfortunately, setting the 'calendardata' here is optional. If
          # it was excluded, we actually need another call to get this as
          # well.

          object = calendar_object(object['calendarid'], object['uri']) unless object.key?('calendardata')

          v_object = VObject::Reader.read(object['calendardata'])

          validator = CalendarQueryValidator.new
          result = validator.validate(v_object, filters)

          # Destroy circular references so PHP will GC the object.
          v_object.destroy

          result
        end

        public

        # Searches through all of a users calendars and calendar objects to find
        # an object with a specific UID.
        #
        # This method should return the path to this object, relative to the
        # calendar home, so this path usually only contains two parts:
        #
        # calendarpath/objectpath.ics
        #
        # If the uid is not found, return null.
        #
        # This method should only consider * objects that the principal owns, so
        # any calendars owned by other principals that also appear in this
        # collection should be ignored.
        #
        # @param string principal_uri
        # @param string uid
        # @return string|null
        def calendar_object_by_uid(principal_uri, uid)
          # Note: this is a super slow naive implementation of this method. You
          # are highly recommended to optimize it, if your backend allows it.
          calendars_for_user(principal_uri).each do |calendar|
            # We must ignore calendars owned by other principals.
            next if calendar['principaluri'] != principal_uri

            # Ignore calendars that are shared.
            next if calendar.key?('{http://sabredav.org/ns}owner-principal') && calendar['{http://sabredav.org/ns}owner-principal'] != principal_uri

            results = calendar_query(
              calendar['id'],
              'name'         => 'VCALENDAR',
              'prop-filters' => [],
              'comp-filters' => [
                {
                  'name'           => 'VEVENT',
                  'is-not-defined' => false,
                  'time-range'     => nil,
                  'comp-filters'   => [],
                  'prop-filters'   => [
                    {
                      'name'           => 'UID',
                      'is-not-defined' => false,
                      'time-range'     => nil,
                      'text-match'     => {
                        'value'            => uid,
                        'negate-condition' => false,
                        'collation'        => 'i;octet'
                      },
                      'param-filters' => []
                    }
                  ]
                }
              ]
            )

            if results.any?
              # We have a match
              return calendar['uri'] + '/' + results[0]
            end
          end

          nil
        end
      end
    end
  end
end
