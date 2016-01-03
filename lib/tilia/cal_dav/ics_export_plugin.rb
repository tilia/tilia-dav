module Tilia
  module CalDav
    # ICS Exporter
    #
    # This plugin adds the ability to export entire calendars as .ics files.
    # This is useful for clients that don't support CalDAV yet. They often do
    # support ics files.
    #
    # To use this, point a http client to a caldav calendar, and add ?expand to
    # the url.
    #
    # Further options that can be added to the url:
    #   start=123456789 - Only return events after the given unix timestamp
    #   end=123245679   - Only return events from before the given unix timestamp
    #   expand=1        - Strip timezone information and expand recurring events.
    #                     If you'd like to expand, you _must_ also specify start
    #                     and end.
    #
    # By default this plugin returns data in the text/calendar format (iCalendar
    # 2.0). If you'd like to receive jCal data instead, you can use an Accept
    # header:
    #
    # Accept: application/calendar+json
    #
    # Alternatively, you can also specify this in the url using
    # accept=application/calendar+json, or accept=jcal for short. If the url
    # parameter and Accept header is specified, the url parameter wins.
    #
    # Note that specifying a start or end data implies that only events will be
    # returned. VTODO and VJOURNAL will be stripped.
    class IcsExportPlugin < Dav::ServerPlugin
      # @!attribute [r] server
      #   @!visibility private
      #   Reference to Server class
      #
      #   @var \Sabre\DAV\Server

      # Initializes the plugin and registers event handlers
      #
      # @param \Sabre\DAV\Server server
      # @return void
      def setup(server)
        @server = server
        @server.on('method:GET', method(:http_get), 90)
        @server.on(
          'browserButtonActions',
          lambda do |path, node, actions|
            if node.is_a?(ICalendar)
              actions.value += '<a href="'
              actions.value += CGI.escapeHTML(path)
              actions.value += '?export"><span class="oi" data-glyph="calendar"></span></a>'
            end
          end
        )
      end

      # Intercepts GET requests on calendar urls ending with ?export.
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_get(request, response)
        query_params = request.query_parameters
        return true unless query_params.key?('export')

        path = request.path

        node = @server.properties(
          path,
          [
            '{DAV:}resourcetype',
            '{DAV:}displayname',
            '{http://sabredav.org/ns}sync-token',
            '{DAV:}sync-token',
            '{http://apple.com/ns/ical/}calendar-color'
          ]
        )

        return true unless node.key?('{DAV:}resourcetype') && node['{DAV:}resourcetype'].is("{#{Plugin::NS_CALDAV}}calendar")

        # Marking the transactionType, for logging purposes.
        @server.transaction_type = 'get-calendar-export'

        properties = node

        start = nil
        ending = nil
        expand = false
        component_type = ''

        if query_params.key?('start')
          fail Dav::Exception::BadRequest, 'The start= parameter must contain a unix timestamp' unless query_params['start'] =~ /^\d+$/

          start = Time.zone.at(query_params['start'].to_i)
        end

        if query_params.key?('end')
          fail Dav::Exception::BadRequest, 'The end= parameter must contain a unix timestamp' unless query_params['end'] =~ /^\d+$/

          ending = Time.zone.at(query_params['end'].to_i)
        end

        unless query_params['expand'].blank?
          fail Dav::Exception::BadRequest, 'If you\'d like to expand recurrences, you must specify both a start= and end= parameter.' unless start && ending

          expand = true
          component_type = 'VEVENT'
        end

        if query_params.key?('componentType')
          unless %w(VEVENT VTODO VJOURNAL).include?(query_params['componentType'])
            fail Dav::Exception::BadRequest, "You are not allowed to search for components of type: #{query_params['componentType']} here"
          end

          component_type = query_params['componentType']
        end

        format = Http::Util.negotiate(
          request.header('Accept'),
          [
            'text/calendar',
            'application/calendar+json'
          ]
        )

        if query_params.key?('accept')
          if query_params['accept'] == 'application/calendar+json' || query_params['accept'] == 'jcal'
            format = 'application/calendar+json'
          end
        end

        format = 'text/calendar' if format.blank?

        generate_response(path, start, ending, expand, component_type, format, properties, response)

        # Returning false to break the event chain
        false
      end

      protected

      # This method is responsible for generating the actual, full response.
      #
      # @param string path
      # @param DateTime|null start
      # @param DateTime|null end
      # @param bool expand
      # @param string component_type
      # @param string format
      # @param array properties
      # @param ResponseInterface response
      def generate_response(path, start, ending, expand, component_type, format, properties, response)
        cal_data_prop = "{#{Plugin::NS_CALDAV}}calendar-data"

        blobs = {}
        if start || ending || component_type.present?
          # If there was a start or end filter, we need to enlist
          # calendarQuery for speed.
          calendar_node = @server.tree.node_for_path(path)

          query_result = calendar_node.calendar_query(
            'name'         => 'VCALENDAR',
            'comp-filters' => [
              {
                'name'           => component_type,
                'comp-filters'   => [],
                'prop-filters'   => [],
                'is-not-defined' => false,
                'time-range'     => {
                  'start' => start,
                  'end'   => ending
                }
              }
            ],
            'prop-filters'   => [],
            'is-not-defined' => false,
            'time-range'     => nil
          )

          # queryResult is just a list of base urls. We need to prefix the
          # calendar path.
          query_result = query_result.map { |item| path + '/' + item }

          nodes = @server.properties_for_multiple_paths(query_result, [cal_data_prop])
          query_result = nil
        else
          nodes = @server.properties_for_path(path, [cal_data_prop], 1)
        end

        # Flattening the arrays
        nodes = nodes.values if nodes.is_a?(Hash)
        nodes.each do |node|
          if node[200].key?(cal_data_prop)
            blobs[node['href']] = node[200][cal_data_prop]
          end
        end
        nodes = nil

        merged_calendar = merge_objects(
          properties,
          blobs
        )

        if expand
          calendar_time_zone = nil

          # We're expanding, and for that we need to figure out the
          # calendar's timezone.
          tz_prop = "{#{Plugin::NS_CALDAV}}calendar-timezone"
          tz_result = @server.properties(path, [tz_prop])

          if tz_result.key?(tz_prop)
            # This property contains a VCALENDAR with a single
            # VTIMEZONE.
            vtimezone_obj = VObject::Reader.read(tz_result[tz_prop])
            calendar_time_zone = vtimezone_obj['VTIMEZONE'].time_zone

            # Destroy circular references to PHP will GC the object.
            vtimezone_obj.destroy
            vtimezone_obj = nil
          else
            # Defaulting to UTC.
            calendar_time_zone = ActiveSupport::TimeZone.new('UTC')
          end

          merged_calendar.expand(start, ending, calendar_time_zone)
        end

        response.update_header('Content-Type', format)

        case format
        when 'text/calendar'
          merged_calendar = merged_calendar.serialize
        when 'application/calendar+json'
          merged_calendar = merged_calendar.json_serialize.to_json
        end

        response.status = 200
        response.body = merged_calendar
      end

      public

      # Merges all calendar objects, and builds one big iCalendar blob.
      #
      # @param array properties Some CalDAV properties
      # @param array input_objects
      # @return VObject\Component\VCalendar
      def merge_objects(properties, input_objects)
        calendar = VObject::Component::VCalendar.new
        calendar['VERSION'] = '2.0'

        if Dav::Server.expose_version
          calendar['PRODID'] = "-//TiliaDAV//TiliaDAV #{Dav::Version::VERSION}//EN"
        else
          calendar['PRODID'] = '-//SabreDAV//SabreDAV//EN'
        end

        if properties.key?('{DAV:}displayname')
          calendar['X-WR-CALNAME'] = properties['{DAV:}displayname']
        end
        if properties.key?('{http://apple.com/ns/ical/}calendar-color')
          calendar['X-APPLE-CALENDAR-COLOR'] = properties['{http://apple.com/ns/ical/}calendar-color']
        end

        collected_timezones = []

        timezones = []
        objects = []

        input_objects.each do |_href, input_object|
          node_comp = VObject::Reader.read(input_object)

          node_comp.children.each do |child|
            case child.name
            when 'VEVENT', 'VTODO', 'VJOURNAL'
              objects << child.clone
            # VTIMEZONE is special, because we need to filter out the duplicates
            when 'VTIMEZONE'
              # Naively just checking tzid.
              next if collected_timezones.include?(child['TZID'].to_s)

              timezones << child.clone
              collected_timezones << child['TZID'].to_s
            end
          end

          # Destroy circular references to PHP will GC the object.
          node_comp.destroy
          node_comp = nil
        end

        timezones.each { |tz| calendar.add(tz) }
        objects.each { |obj| calendar.add(obj) }

        calendar
      end

      # Returns a plugin name.
      #
      # Using this name other plugins will be able to access other plugins
      # using \Sabre\DAV\Server::getPlugin
      #
      # @return string
      def plugin_name
        'ics-export'
      end

      # Returns a bunch of meta-data about the plugin.
      #
      # Providing this information is optional, and is mainly displayed by the
      # Browser plugin.
      #
      # The description key in the returned array may contain html and will not
      # be sanitized.
      #
      # @return array
      def plugin_info
        {
          'name'        => plugin_name,
          'description' => 'Adds the ability to export CalDAV calendars as a single iCalendar file.',
          'link'        => 'http://sabre.io/dav/ics-export-plugin/'
        }
      end
    end
  end
end
