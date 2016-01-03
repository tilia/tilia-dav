module Tilia
  module CalDav
    module Backend
      class Mock < AbstractBackend
        def initialize(calendars = [], calendar_data = {})
          calendars.each do |calendar|
            calendar['id'] = Dav::UuidUtil.uuid unless calendar.key?('id')
          end

          @calendars = calendars
          @calendar_data = calendar_data
        end

        # Returns a list of calendars for a principal.
        #
        # Every project is an array with the following keys:
        #  * id, a unique id that will be used by other functions to modify the
        #    calendar. This can be the same as the uri or a database key.
        #  * uri, which the basename of the uri with which the calendar is
        #    accessed.
        #  * principalUri. The owner of the calendar. Almost always the same as
        #    principalUri passed to this method.
        #
        # Furthermore it can contain webdav properties in clark notation. A very
        # common one is '{DAV:}displayname'.
        #
        # @param string principal_uri
        # @return array
        def calendars_for_user(principal_uri)
          @calendars.select do |row|
            row['principaluri'] == principal_uri
          end
        end

        # Creates a new calendar for a principal.
        #
        # If the creation was a success, an id must be returned that can be used to reference
        # this calendar in other methods, such as updateCalendar.
        #
        # This function must return a server-wide unique id that can be used
        # later to reference the calendar.
        #
        # @param string principal_uri
        # @param string calendar_uri
        # @param array properties
        # @return string|int
        def create_calendar(principal_uri, calendar_uri, properties)
          id = Dav::UuidUtil.uuid

          @calendars << {
            'id' => id,
            'principaluri' => principal_uri,
            'uri' => calendar_uri,
            "{#{Plugin::NS_CALDAV}}supported-calendar-component-set" => Xml::Property::SupportedCalendarComponentSet.new(['VEVENT', 'VTODO'])
          }.merge(properties)

          id
        end

        # Delete a calendar and all it's objects
        #
        # @param string calendar_id
        # @return void
        def delete_calendar(calendar_id)
          @calendars.delete_if do |calendar|
            calendar['id'] == calendar_id
          end
        end

        # Returns all calendar objects within a calendar object.
        #
        # Every item contains an array with the following keys:
        #   * id - unique identifier which will be used for subsequent updates
        #   * calendardata - The iCalendar-compatible calendar data
        #   * uri - a unique key which will be used to construct the uri. This can be any arbitrary string.
        #   * lastmodified - a timestamp of the last modification time
        #   * etag - An arbitrary string, surrounded by double-quotes. (e.g.:
        #   '  "abcdef"')
        #   * calendarid - The calendarid as it was passed to this function.
        #
        # Note that the etag is optional, but it's highly encouraged to return for
        # speed reasons.
        #
        # The calendardata is also optional. If it's not returned
        # 'getCalendarObject' will be called later, which *is* expected to return
        # calendardata.
        #
        # @param string calendar_id
        # @return array
        def calendar_objects(calendar_id)
          return [] unless @calendar_data.key?(calendar_id)

          objects = @calendar_data[calendar_id]

          objects.each do |uri, object|
            object['calendarid'] = calendar_id
            object['uri'] = uri
            object['lastmodified'] = nil
          end

          objects.values
        end

        # Returns information from a single calendar object, based on it's object
        # uri.
        #
        # The returned array must have the same keys as getCalendarObjects. The
        # 'calendardata' object is required here though, while it's not required
        # for getCalendarObjects.
        #
        # @param string calendar_id
        # @param string object_uri
        # @return array
        def calendar_object(calendar_id, object_uri)
          unless @calendar_data.key?(calendar_id) &&
                 @calendar_data[calendar_id].key?(object_uri)
            fail Dav::Exception::NotFound, 'Object could not be found'
          end

          object = @calendar_data[calendar_id][object_uri]
          object['calendarid'] = calendar_id
          object['uri'] = object_uri
          object['lastmodified'] = nil
          object
        end

        # Creates a new calendar object.
        #
        # @param string calendar_id
        # @param string object_uri
        # @param string calendar_data
        # @return void
        def create_calendar_object(calendar_id, object_uri, calendar_data)
          @calendar_data[calendar_id] ||= {}
          @calendar_data[calendar_id][object_uri] = {
            'calendardata' => calendar_data,
            'calendarid' => calendar_id,
            'uri' => object_uri
          }
          "\"#{Digest::MD5.hexdigest(calendar_data)}\""
        end

        # Updates an existing calendarobject, based on it's uri.
        #
        # @param string calendar_id
        # @param string object_uri
        # @param string calendar_data
        # @return void
        def update_calendar_object(calendar_id, object_uri, calendar_data)
          @calendar_data[calendar_id][object_uri] = {
            'calendardata' => calendar_data,
            'calendarid' => calendar_id,
            'uri' => object_uri
          }
          "\"#{Digest::MD5.hexdigest(calendar_data)}\""
        end

        # Deletes an existing calendar object.
        #
        # @param string calendar_id
        # @param string object_uri
        # @return void
        def delete_calendar_object(_calendar_id, _object_uri)
          fail NotImplementedErrorthrow Exception.new('Not implemented')
        end
      end
    end
  end
end
