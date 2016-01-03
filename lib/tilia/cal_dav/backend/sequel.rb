module Tilia
  module CalDav
    module Backend
      # Sequel CalDAV backend
      #
      # This backend is used to store calendar-data in a Sequel database, such as
      # sqlite or MySQL
      class Sequel < AbstractBackend
        include SyncSupport
        include SubscriptionSupport
        include SchedulingSupport

        # We need to specify a max date, because we need to stop *somewhere*
        #
        # On 32 bit system the maximum for a signed integer is 2147483647, so
        # MAX_DATE cannot be higher than date('Y-m-d', 2147483647) which results
        # in 2038-01-19 to avoid problems when the date is converted
        # to a unix timestamp.
        MAX_DATE = '2038-01-01'

        # @!attribute [r] sequel
        #   @!visibility private
        #   sequel
        #
        #   @return [Sequel]

        # The table name that will be used for calendars
        #
        # @var string
        attr_accessor :calendar_table_name

        # The table name that will be used for calendar objects
        #
        # @var string
        attr_accessor :calendar_object_table_name

        # The table name that will be used for tracking changes in calendars.
        #
        # @var string
        attr_accessor :calendar_changes_table_name

        # The table name that will be used inbox items.
        #
        # @var string
        attr_accessor :scheduling_object_table_name

        # The table name that will be used for calendar subscriptions.
        #
        # @var string
        attr_accessor :calendar_subscriptions_table_name

        # List of CalDAV properties, and how they map to database fieldnames
        # Add your own properties by simply adding on to this array.
        #
        # Note that only string-based properties are supported here.
        #
        # @var array
        attr_accessor :property_map

        # List of subscription properties, and how they map to database fieldnames.
        #
        # @var array
        attr_accessor :public

        # Creates the backend
        #
        # @param \Sequel sequel
        def initialize(sequel)
          @sequel = sequel
          @calendar_table_name = 'calendars'
          @calendar_object_table_name = 'calendarobjects'
          @calendar_changes_table_name = 'calendarchanges'
          @scheduling_object_table_name = 'schedulingobjects'
          @calendar_subscriptions_table_name = 'calendarsubscriptions'
          @property_map = {
            '{DAV:}displayname'                                   => 'displayname',
            '{urn:ietf:params:xml:ns:caldav}calendar-description' => 'description',
            '{urn:ietf:params:xml:ns:caldav}calendar-timezone'    => 'timezone',
            '{http://apple.com/ns/ical/}calendar-order'           => 'calendarorder',
            '{http://apple.com/ns/ical/}calendar-color'           => 'calendarcolor'
          }
          @subscription_property_map = {
            '{DAV:}displayname'                                           => 'displayname',
            '{http://apple.com/ns/ical/}refreshrate'                      => 'refreshrate',
            '{http://apple.com/ns/ical/}calendar-order'                   => 'calendarorder',
            '{http://apple.com/ns/ical/}calendar-color'                   => 'calendarcolor',
            '{http://calendarserver.org/ns/}subscribed-strip-todos'       => 'striptodos',
            '{http://calendarserver.org/ns/}subscribed-strip-alarms'      => 'stripalarms',
            '{http://calendarserver.org/ns/}subscribed-strip-attachments' => 'stripattachments'
          }
        end

        # Returns a list of calendars for a principal.
        #
        # Every project is an array with the following keys:
        #  * id, a unique id that will be used by other functions to modify the
        #    calendar. This can be the same as the uri or a database key.
        #  * uri. This is just the 'base uri' or 'filename' of the calendar.
        #  * principaluri. The owner of the calendar. Almost always the same as
        #    principalUri passed to this method.
        #
        # Furthermore it can contain webdav properties in clark notation. A very
        # common one is '{DAV:}displayname'.
        #
        # Many clients also require:
        # {urn:ietf:params:xml:ns:caldav}supported-calendar-component-set
        # For this property, you can just return an instance of
        # Sabre\CalDAV\Xml\Property\SupportedCalendarComponentSet.
        #
        # If you return {http://sabredav.org/ns}read-only and set the value to 1,
        # ACL will automatically be put in read-only mode.
        #
        # @param string principal_uri
        # @return array
        def calendars_for_user(principal_uri)
          fields = @property_map.values
          fields << 'id'
          fields << 'uri'
          fields << 'synctoken'
          fields << 'components'
          fields << 'principaluri'
          fields << 'transparent'

          # Making fields a comma-delimited list
          fields = fields.join(', ')
          calendars = []

          @sequel.fetch("SELECT #{fields} FROM #{@calendar_table_name} WHERE principaluri = ? ORDER BY calendarorder ASC", principal_uri) do |row|
            components = []
            components = row[:components].split(',') unless row[:components].blank?

            calendar = {
              'id'                                                     => row[:id],
              'uri'                                                    => row[:uri],
              'principaluri'                                           => row[:principaluri],
              "{#{Plugin::NS_CALENDARSERVER}}getctag"                  => "http://sabre.io/ns/sync/#{row[:synctoken] ? row[:synctoken] : '0'}",
              '{http://sabredav.org/ns}sync-token'                     => row[:synctoken] ? row[:synctoken] : '0',
              "{#{Plugin::NS_CALDAV}}supported-calendar-component-set" => Xml::Property::SupportedCalendarComponentSet.new(components),
              "{#{Plugin::NS_CALDAV}}schedule-calendar-transp"         => Xml::Property::ScheduleCalendarTransp.new(row[:transparent] ? 'transparent' : 'opaque')
            }

            @property_map.each do |xml_name, db_name|
              calendar[xml_name] = row[db_name.to_sym]
            end

            calendars << calendar
          end

          calendars
        end

        # Creates a new calendar for a principal.
        #
        # If the creation was a success, an id must be returned that can be used
        # to reference this calendar in other methods, such as updateCalendar.
        #
        # @param string principal_uri
        # @param string calendar_uri
        # @param array properties
        # @return string
        def create_calendar(principal_uri, calendar_uri, properties)
          field_names = [
            'principaluri',
            'uri',
            'synctoken',
            'transparent'
          ]
          values = {
            principaluri: principal_uri,
            uri: calendar_uri,
            synctoken: 1,
            transparent: 0
          }

          # Default value
          sccs = '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set'
          field_names << 'components'
          if !properties.key?(sccs)
            values[:components] = 'VEVENT,VTODO'
          else
            unless properties[sccs].is_a?(Xml::Property::SupportedCalendarComponentSet)
              fail Dav::Exception, "The #{sccs} property must be of type: Tilia::CalDAV::Xml::Property::SupportedCalendarComponentSet"
            end

            values[:components] = properties[sccs].value.join(',')
          end

          transp = "{#{Plugin::NS_CALDAV}}schedule-calendar-transp"

          values[:transparent] = properties[transp].value == 'transparent' if properties.key?(transp)

          @property_map.each do |xml_name, db_name|
            if properties.key?(xml_name)
              values[db_name.to_sym] = properties[xml_name]
              field_names << db_name
            end
          end

          ds = @sequel[
            "INSERT INTO #{@calendar_table_name} (#{field_names.join(', ')}) VALUES (#{field_names.map { |k| ":#{k}" }.join(', ')})",
            values
          ]
          ds.insert
        end

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
        # @param string calendar_id
        # @param \Sabre\DAV\PropPatch prop_patch
        # @return void
        def update_calendar(calendar_id, prop_patch)
          supported_properties = @property_map.keys
          supported_properties << "{#{Plugin::NS_CALDAV}}schedule-calendar-transp"

          prop_patch.handle(
            supported_properties,
            lambda do |mutations|
              new_values = {}
              mutations.each do |property_name, property_value|
                case property_name
                when "{#{Plugin::NS_CALDAV}}schedule-calendar-transp"
                  field_name = :transparent
                  new_values[field_name] = property_value.value == 'transparent'
                else
                  field_name = @property_map[property_name].to_sym
                  new_values[field_name] = property_value
                end
              end

              values_sql = []
              new_values.each do |field_name, _value|
                values_sql << "#{field_name} = :#{field_name}"
              end

              new_values[:id] = calendar_id
              ds = @sequel["UPDATE #{@calendar_table_name} SET #{values_sql.join(', ')} WHERE id = :id", new_values]
              ds.update

              add_change(calendar_id, '', 2)

              return true
            end
          )
        end

        # Delete a calendar and all it's objects
        #
        # @param string calendar_id
        # @return void
        def delete_calendar(calendar_id)
          ds = @sequel["DELETE FROM #{@calendar_object_table_name} WHERE calendarid = ?", calendar_id]
          ds.delete

          ds = @sequel["DELETE FROM #{@calendar_table_name} WHERE id = ?", calendar_id]
          ds.delete

          ds = @sequel["DELETE FROM #{@calendar_changes_table_name} WHERE calendarid = ?", calendar_id]
          ds.delete
        end

        # Returns all calendar objects within a calendar.
        #
        # Every item contains an array with the following keys:
        #   * calendardata - The iCalendar-compatible calendar data
        #   * uri - a unique key which will be used to construct the uri. This can
        #     be any arbitrary string, but making sure it ends with '.ics' is a
        #     good idea. This is only the basename, or filename, not the full
        #     path.
        #   * lastmodified - a timestamp of the last modification time
        #   * etag - An arbitrary string, surrounded by double-quotes. (e.g.:
        #   '  "abcdef"')
        #   * size - The size of the calendar objects, in bytes.
        #   * component - optional, a string containing the type of object, such
        #     as 'vevent' or 'vtodo'. If specified, this will be used to populate
        #     the Content-Type header.
        #
        # Note that the etag is optional, but it's highly encouraged to return for
        # speed reasons.
        #
        # The calendardata is also optional. If it's not returned
        # 'getCalendarObject' will be called later, which *is* expected to return
        # calendardata.
        #
        # If neither etag or size are specified, the calendardata will be
        # used/fetched to determine these numbers. If both are specified the
        # amount of times this is needed is reduced by a great degree.
        #
        # @param string calendar_id
        # @return array
        def calendar_objects(calendar_id)
          result = []

          @sequel.fetch("SELECT id, uri, lastmodified, etag, calendarid, size, componenttype FROM #{@calendar_object_table_name} WHERE calendarid = ?", calendar_id) do |row|
            result << {
              'id'           => row[:id],
              'uri'          => row[:uri],
              'lastmodified' => row[:lastmodified],
              'etag'         => "\"#{row[:etag]}\"",
              'calendarid'   => row[:calendarid],
              'size'         => row[:size].to_i,
              'component'    => row[:componenttype].downcase
            }
          end

          result
        end

        # Returns information from a single calendar object, based on it's object
        # uri.
        #
        # The object uri is only the basename, or filename and not a full path.
        #
        # The returned array must have the same keys as getCalendarObjects. The
        # 'calendardata' object is required here though, while it's not required
        # for getCalendarObjects.
        #
        # This method must return null if the object did not exist.
        #
        # @param string calendar_id
        # @param string object_uri
        # @return array|null
        def calendar_object(calendar_id, object_uri)
          ds = @sequel[
            "SELECT id, uri, lastmodified, etag, calendarid, size, calendardata, componenttype FROM #{@calendar_object_table_name} WHERE calendarid = ? AND uri = ?",
            calendar_id,
            object_uri
          ]
          row = ds.all.first

          return nil unless row

          {
            'id'            => row[:id],
            'uri'           => row[:uri],
            'lastmodified'  => row[:lastmodified],
            'etag'          => "\"#{row[:etag]}\"",
            'calendarid'    => row[:calendarid],
            'size'          => row[:size].to_i,
            'calendardata'  => row[:calendardata],
            'component'     => row[:componenttype].downcase
          }
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
          query = "SELECT id, uri, lastmodified, etag, calendarid, size, calendardata, componenttype FROM #{@calendar_object_table_name} WHERE calendarid = ? AND uri IN ("
          # Inserting a whole bunch of question marks
          query << (['?'] * uris.size).join(', ')
          query << ')'

          result = []
          @sequel.fetch(query, calendar_id, *uris) do |row|
            result << {
              'id'           => row[:id],
              'uri'          => row[:uri],
              'lastmodified' => row[:lastmodified],
              'etag'         => "\"#{row[:etag]}\"",
              'calendarid'   => row[:calendarid],
              'size'         => row[:size].to_i,
              'calendardata' => row[:calendardata],
              'component'    => row[:componenttype].downcase
            }
          end

          result
        end

        # Creates a new calendar object.
        #
        # The object uri is only the basename, or filename and not a full path.
        #
        # It is possible return an etag from this function, which will be used in
        # the response to this PUT request. Note that the ETag must be surrounded
        # by double-quotes.
        #
        # However, you should only really return this ETag if you don't mangle the
        # calendar-data. If the result of a subsequent GET to this object is not
        # the exact same as this request body, you should omit the ETag.
        #
        # @param mixed calendar_id
        # @param string object_uri
        # @param string calendar_data
        # @return string|null
        def create_calendar_object(calendar_id, object_uri, calendar_data)
          extra_data = denormalized_data(calendar_data)

          ds = @sequel[
            "INSERT INTO #{@calendar_object_table_name} (calendarid, uri, calendardata, lastmodified, etag, size, componenttype, firstoccurence, lastoccurence, uid) VALUES (?,?,?,?,?,?,?,?,?,?)",
            calendar_id,
            object_uri,
            calendar_data,
            Time.now.to_i,
            extra_data['etag'],
            extra_data['size'],
            extra_data['componentType'],
            extra_data['firstOccurence'],
            extra_data['lastOccurence'],
            extra_data['uid'],
          ]
          ds.insert

          add_change(calendar_id, object_uri, 1)

          "\"#{extra_data['etag']}\""
        end

        # Updates an existing calendarobject, based on it's uri.
        #
        # The object uri is only the basename, or filename and not a full path.
        #
        # It is possible return an etag from this function, which will be used in
        # the response to this PUT request. Note that the ETag must be surrounded
        # by double-quotes.
        #
        # However, you should only really return this ETag if you don't mangle the
        # calendar-data. If the result of a subsequent GET to this object is not
        # the exact same as this request body, you should omit the ETag.
        #
        # @param mixed calendar_id
        # @param string object_uri
        # @param string calendar_data
        # @return string|null
        def update_calendar_object(calendar_id, object_uri, calendar_data)
          extra_data = denormalized_data(calendar_data)

          ds = @sequel[
            "UPDATE #{@calendar_object_table_name} SET calendardata = ?, lastmodified = ?, etag = ?, size = ?, componenttype = ?, firstoccurence = ?, lastoccurence = ?, uid = ? WHERE calendarid = ? AND uri = ?",
            calendar_data,
            Time.now.to_i,
            extra_data['etag'],
            extra_data['size'],
            extra_data['componentType'],
            extra_data['firstOccurence'],
            extra_data['lastOccurence'],
            extra_data['uid'],
            calendar_id,
            object_uri
          ]
          ds.update

          add_change(calendar_id, object_uri, 2)

          "\"#{extra_data['etag']}\""
        end

        protected

        # Parses some information from calendar objects, used for optimized
        # calendar-queries.
        #
        # Returns an array with the following keys:
        #   * etag - An md5 checksum of the object without the quotes.
        #   * size - Size of the object in bytes
        #   * componentType - VEVENT, VTODO or VJOURNAL
        #   * firstOccurence
        #   * lastOccurence
        #   * uid - value of the UID property
        #
        # @param string calendar_data
        # @return array
        def denormalized_data(calendar_data)
          v_object = VObject::Reader.read(calendar_data)

          component_type = nil
          component = nil
          first_occurence = nil
          last_occurence = nil
          uid = nil

          v_object.components.each do |temp_component|
            next unless temp_component.name != 'VTIMEZONE'

            component_type = temp_component.name
            uid = temp_component['UID'].to_s
            component = temp_component
            break
          end

          fail Dav::Exception::BadRequest, 'Calendar objects must have a VJOURNAL, VEVENT or VTODO component' unless component_type

          if component_type == 'VEVENT'
            first_occurence = component['DTSTART'].date_time.to_i

            # Finding the last occurence is a bit harder
            if !component.key?('RRULE')
              if component.key?('DTEND')
                last_occurence = component['DTEND'].date_time.to_i
              elsif component.key?('DURATION')
                end_date = component['DTSTART'].date_time + VObject::DateTimeParser.parse(component['DURATION'].value)
                last_occurence = end_date.to_i
              elsif !component['DTSTART'].time?
                end_date = component['DTSTART'].date_time + 1.day
                last_occurence = end_date.to_i
              else
                last_occurence = first_occurence
              end
            else
              it = VObject::Recur::EventIterator.new(v_object, component['UID'].to_s)

              max_date = Time.zone.parse(MAX_DATE)

              if it.infinite?
                last_occurence = max_date.to_i
              else
                ending = it.dt_end
                while it.valid && ending < max_date
                  ending = it.dt_end
                  it.next
                end

                last_occurence = ending.to_i
              end
            end
          end

          # Destroy circular references to PHP will GC the object.
          v_object.destroy

          {
            'etag'           => Digest::MD5.hexdigest(calendar_data),
            'size'           => calendar_data.size,
            'componentType'  => component_type,
            'firstOccurence' => first_occurence,
            'lastOccurence'  => last_occurence,
            'uid'            => uid
          }
        end

        public

        # Deletes an existing calendar object.
        #
        # The object uri is only the basename, or filename and not a full path.
        #
        # @param string calendar_id
        # @param string object_uri
        # @return void
        def delete_calendar_object(calendar_id, object_uri)
          ds = @sequel[
            "DELETE FROM #{@calendar_object_table_name} WHERE calendarid = ? AND uri = ?",
            calendar_id,
            object_uri
          ]
          ds.delete

          add_change(calendar_id, object_uri, 3)
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
        #   * requests with a time-range-filter on a VEVENT.
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
        # This specific implementation (for the Sequel) backend optimizes filters on
        # specific components, and VEVENT time-ranges.
        #
        # @param string calendar_id
        # @param array filters
        # @return array
        def calendar_query(calendar_id, filters)
          component_type = nil
          require_post_filter = true
          time_range = nil

          # if no filters were specified, we don't need to filter after a query
          if !(filters['prop-filters'] || filters['prop-filters'].empty?) &&
             !(filters['comp-filters'] || filters['comp-filters'].empty?)
            require_post_filter = false
          end

          # Figuring out if there's a component filter
          if filters['comp-filters'].size > 0 && !filters['comp-filters'][0]['is-not-defined']
            component_type = filters['comp-filters'][0]['name']

            # Checking if we need post-filters
            if !filters['prop-filters'] &&
               !filters['comp-filters'][0]['comp-filters'] &&
               !filters['comp-filters'][0]['time-range'] &&
               !filters['comp-filters'][0]['prop-filters']
              require_post_filter = false
            end

            # There was a time-range filter
            if component_type == 'VEVENT' &&
               filters['comp-filters'][0].key?('time-range')
              time_range = filters['comp-filters'][0]['time-range']

              # If start time OR the end time is not specified, we can do a
              # 100% accurate mysql query.
              if !filters['prop-filters'] &&
                 !filters['comp-filters'][0]['comp-filters'] &&
                 !filters['comp-filters'][0]['prop-filters'] &&
                 (!time_range['start'] || !time_range['end'])
                require_post_filter = false
              end
            end
          end

          if require_post_filter
            query = "SELECT uri, calendardata FROM #{@calendar_object_table_name} WHERE calendarid = :calendarid"
          else
            query = "SELECT uri FROM #{@calendar_object_table_name} WHERE calendarid = :calendarid"
          end

          values = {
            calendarid: calendar_id
          }

          if component_type
            query << ' AND componenttype = :componenttype'
            values[:componenttype] = component_type
          end

          if time_range && time_range['start']
            query << ' AND lastoccurence > :startdate'
            values[:startdate] = time_range['start'].to_i
          end

          if time_range && time_range['end']
            query << ' AND firstoccurence < :enddate'
            values[:enddate] = time_range['end'].to_i
          end

          result = []
          @sequel.fetch(query, values) do |row|
            # TODO: ATM we use string hashes :-/
            string_hash = {}
            row.each { |k, v| string_hash[k.to_s] = v }

            if require_post_filter
              next unless validate_filter_for_object(string_hash, filters)
            end

            result << row[:uri]
          end

          result
        end

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
          query = <<SQL
SELECT
calendars.uri AS calendaruri, calendarobjects.uri as objecturi
FROM
#{@calendar_object_table_name} AS calendarobjects
LEFT JOIN
#{@calendar_table_name} AS calendars
ON calendarobjects.calendarid = calendars.id
WHERE
calendars.principaluri = ?
AND
calendarobjects.uid = ?
SQL

          @sequel.fetch(query, principal_uri, uid) do |row|
            return row[:calendaruri] + '/' + row[:objecturi]
          end
          nil
        end

        # The getChanges method returns all the changes that have happened, since
        # the specified syncToken in the specified calendar.
        #
        # This function should return an array, such as the following:
        #
        # [
        #   'syncToken' => 'The current synctoken',
        #   'added'   => [
        #      'new.txt',
        #   ],
        #   'modified'   => [
        #      'modified.txt',
        #   ],
        #   'deleted' => [
        #      'foo.php.bak',
        #      'old.txt'
        #   ]
        # ]
        #
        # The returned syncToken property should reflect the *current* syncToken
        # of the calendar, as reported in the {http://sabredav.org/ns}sync-token
        # property this is needed here too, to ensure the operation is atomic.
        #
        # If the sync_token argument is specified as null, this is an initial
        # sync, and all members should be reported.
        #
        # The modified property is an array of nodenames that have changed since
        # the last token.
        #
        # The deleted property is an array with nodenames, that have been deleted
        # from collection.
        #
        # The sync_level argument is basically the 'depth' of the report. If it's
        # 1, you only have to report changes that happened only directly in
        # immediate descendants. If it's 2, it should also include changes from
        # the nodes below the child collections. (grandchildren)
        #
        # The limit argument allows a client to specify how many results should
        # be returned at most. If the limit is not specified, it should be treated
        # as infinite.
        #
        # If the limit (infinite or not) is higher than you're willing to return,
        # you should throw a Sabre\DAV\Exception\TooMuchMatches exception.
        #
        # If the syncToken is expired (due to data cleanup) or unknown, you must
        # return null.
        #
        # The limit is 'suggestive'. You are free to ignore it.
        #
        # @param string calendar_id
        # @param string sync_token
        # @param int sync_level
        # @param int limit
        # @return array
        def changes_for_calendar(calendar_id, sync_token, _sync_level, limit = nil)
          # Current synctoken
          ds = @sequel["SELECT synctoken FROM #{@calendar_table_name} WHERE id = ?", calendar_id]
          result = ds.all.first

          return nil unless result

          current_token = result[:synctoken]

          return nil unless current_token

          result = {
            'syncToken' => current_token,
            'added'     => [],
            'modified'  => [],
            'deleted'   => []
          }

          if sync_token
            query = "SELECT uri, operation FROM #{@calendar_changes_table_name} WHERE synctoken >= ? AND synctoken < ? AND calendarid = ? ORDER BY synctoken"
            query << " LIMIT #{limit}" if limit && limit > 0

            # Fetching all changes

            changes = {}

            # This loop ensures that any duplicates are overwritten, only the
            # last change on a node is relevant.
            @sequel.fetch(query, sync_token, current_token, calendar_id) do |row|
              changes[row[:uri]] = row[:operation]
            end

            changes.each do |uri, operation|
              case operation
              when 1
                result['added'] << uri.to_s
              when 2
                result['modified'] << uri.to_s
              when 3
                result['deleted'] << uri.to_s
              end
            end
          else
            # No synctoken supplied, this is the initial sync.
            ds = @sequel["SELECT uri FROM #{@calendar_object_table_name} WHERE calendarid = ?", calendar_id]

            # RUBY: concert symbols to strings
            result['added'] = ds.all.map { |e| e[:uri] }
          end

          result
        end

        protected

        # Adds a change record to the calendarchanges table.
        #
        # @param mixed calendar_id
        # @param string object_uri
        # @param int operation 1 = add, 2 = modify, 3 = delete.
        # @return void
        def add_change(calendar_id, object_uri, operation)
          ds = @sequel[
            "INSERT INTO #{@calendar_changes_table_name} (uri, synctoken, calendarid, operation) SELECT ?, synctoken, ?, ? FROM #{@calendar_table_name} WHERE id = ?",
            object_uri,
            calendar_id,
            operation,
            calendar_id
          ]
          ds.insert
          ds = @sequel[
            "UPDATE #{@calendar_table_name} SET synctoken = synctoken + 1 WHERE id = ?",
            calendar_id
          ]
          ds.update
        end

        public

        # Returns a list of subscriptions for a principal.
        #
        # Every subscription is an array with the following keys:
        #  * id, a unique id that will be used by other functions to modify the
        #    subscription. This can be the same as the uri or a database key.
        #  * uri. This is just the 'base uri' or 'filename' of the subscription.
        #  * principaluri. The owner of the subscription. Almost always the same as
        #    principalUri passed to this method.
        #  * source. Url to the actual feed
        #
        # Furthermore, all the subscription info must be returned too:
        #
        # 1. {DAV:}displayname
        # 2. {http://apple.com/ns/ical/}refreshrate
        # 3. {http://calendarserver.org/ns/}subscribed-strip-todos (omit if todos
        #    should not be stripped).
        # 4. {http://calendarserver.org/ns/}subscribed-strip-alarms (omit if alarms
        #    should not be stripped).
        # 5. {http://calendarserver.org/ns/}subscribed-strip-attachments (omit if
        #    attachments should not be stripped).
        # 7. {http://apple.com/ns/ical/}calendar-color
        # 8. {http://apple.com/ns/ical/}calendar-order
        # 9. {urn:ietf:params:xml:ns:caldav}supported-calendar-component-set
        #    (should just be an instance of
        #    Sabre\CalDAV\Property\SupportedCalendarComponentSet, with a bunch of
        #    default components).
        #
        # @param string principal_uri
        # @return array
        def subscriptions_for_user(principal_uri)
          fields = @subscription_property_map.values
          fields << 'id'
          fields << 'uri'
          fields << 'source'
          fields << 'principaluri'
          fields << 'lastmodified'

          # Making fields a comma-delimited list
          fields = fields.join(', ')

          subscriptions = []
          @sequel.fetch("SELECT #{fields} FROM #{@calendar_subscriptions_table_name} WHERE principaluri = ? ORDER BY calendarorder ASC", principal_uri) do |row|
            subscription = {
              'id'           => row[:id],
              'uri'          => row[:uri],
              'principaluri' => row[:principaluri],
              'source'       => row[:source],
              'lastmodified' => row[:lastmodified],

              "{#{Plugin::NS_CALDAV}}supported-calendar-component-set" => Xml::Property::SupportedCalendarComponentSet.new(['VTODO', 'VEVENT'])
            }

            @subscription_property_map.each do |xml_name, db_name|
              subscription[xml_name] = row[db_name.to_sym] unless row[db_name.to_sym].nil?
            end

            subscriptions << subscription
          end

          subscriptions
        end

        # Creates a new subscription for a principal.
        #
        # If the creation was a success, an id must be returned that can be used to reference
        # this subscription in other methods, such as updateSubscription.
        #
        # @param string principal_uri
        # @param string uri
        # @param array properties
        # @return mixed
        def create_subscription(principal_uri, uri, properties)
          field_names = [
            'principaluri',
            'uri',
            'source',
            'lastmodified'
          ]

          fail Dav::Exception::Forbidden, 'The {http://calendarserver.org/ns/}source property is required when creating subscriptions' unless properties.key?('{http://calendarserver.org/ns/}source')

          values = {
            principaluri: principal_uri,
            uri: uri,
            source: properties['{http://calendarserver.org/ns/}source'].href,
            lastmodified: Time.now.to_i
          }

          @subscription_property_map.each do |xml_name, db_name|
            if properties.key?(xml_name)
              values[db_name.to_sym] = properties[xml_name]
              field_names << db_name
            end
          end

          ds = @sequel[
            "INSERT INTO #{@calendar_subscriptions_table_name} (#{field_names.join(', ')}) VALUES (#{field_names.map { |k| ":#{k}" }.join(', ')})",
            values
          ]
          ds.insert
        end

        # Updates a subscription
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
        # @param mixed subscription_id
        # @param \Sabre\DAV\PropPatch prop_patch
        # @return void
        def update_subscription(subscription_id, prop_patch)
          supported_properties = @subscription_property_map.keys
          supported_properties << '{http://calendarserver.org/ns/}source'

          prop_patch.handle(
            supported_properties,
            lambda do |mutations|
              new_values = {}

              mutations.each do |property_name, property_value|
                if property_name == '{http://calendarserver.org/ns/}source'
                  new_values[:source] = property_value.href
                else
                  field_name = @subscription_property_map[property_name]
                  new_values[field_name.to_sym] = property_value
                end
              end

              # Now we're generating the sql query.
              values_sql = []
              new_values.each do |field_name, _value|
                values_sql << "#{field_name} = :#{field_name}"
              end
              new_values[:lastmodified] = Time.now.to_i
              new_values[:id] = subscription_id

              ds = @sequel[
                "UPDATE #{@calendar_subscriptions_table_name} SET #{values_sql.join(', ')}, lastmodified = :lastmodified WHERE id = :id",
                new_values
              ]
              ds.update

              return true
            end
          )
        end

        # Deletes a subscription
        #
        # @param mixed subscription_id
        # @return void
        def delete_subscription(subscription_id)
          ds = @sequel["DELETE FROM #{@calendar_subscriptions_table_name} WHERE id = ?", subscription_id]
          ds.delete
        end

        # Returns a single scheduling object.
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
          ds = @sequel[
            "SELECT uri, calendardata, lastmodified, etag, size FROM #{@scheduling_object_table_name} WHERE principaluri = ? AND uri = ?",
            principal_uri,
            object_uri
          ]
          row = ds.all.first

          return nil unless row

          {
            'uri'          => row[:uri],
            'calendardata' => row[:calendardata],
            'lastmodified' => row[:lastmodified],
            'etag'         => "\"#{row[:etag]}\"",
            'size'         => row[:size].to_i
          }
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
          result = []
          stmt = @sequel.fetch("SELECT id, calendardata, uri, lastmodified, etag, size FROM #{@scheduling_object_table_name} WHERE principaluri = ?", principal_uri) do |row|
            result << {
              'calendardata' => row[:calendardata],
              'uri'          => row[:uri],
              'lastmodified' => row[:lastmodified],
              'etag'         => "\"#{row[:etag]}\"",
              'size'         => row[:size].to_i
            }
          end

          result
        end

        # Deletes a scheduling object
        #
        # @param string principal_uri
        # @param string object_uri
        # @return void
        def delete_scheduling_object(principal_uri, object_uri)
          ds = @sequel["DELETE FROM #{@scheduling_object_table_name} WHERE principaluri = ? AND uri = ?", principal_uri, object_uri]
          ds.delete
        end

        # Creates a new scheduling object. This should land in a users' inbox.
        #
        # @param string principal_uri
        # @param string object_uri
        # @param string object_data
        # @return void
        def create_scheduling_object(principal_uri, object_uri, object_data)
          ds = @sequel[
            "INSERT INTO #{@scheduling_object_table_name} (principaluri, calendardata, uri, lastmodified, etag, size) VALUES (?, ?, ?, ?, ?, ?)",
            principal_uri,
            object_data,
            object_uri,
            Time.now.to_i,
            Digest::MD5.hexdigest(object_data),
            object_data.size
          ]
          ds.insert
        end
      end
    end
  end
end
