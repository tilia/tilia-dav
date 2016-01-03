module Tilia
  module CalDav
    module Schedule
      # CalDAV scheduling plugin.
      # =================
      #
      # This plugin provides the functionality added by the "Scheduling Extensions
      # to CalDAV" standard, as defined in RFC6638.
      #
      # calendar-auto-schedule largely works by intercepting a users request to
      # update their local calendar. If a user creates a new event with attendees,
      # this plugin is supposed to grab the information from that event, and notify
      # the attendees of this.
      #
      # There's 3 possible transports for this:
      # * local delivery
      # * delivery through email (iMip)
      # * server-to-server delivery (iSchedule)
      #
      # iMip is simply, because we just need to add the iTip message as an email
      # attachment. Local delivery is harder, because we both need to add this same
      # message to a local DAV inbox, as well as live-update the relevant events.
      #
      # iSchedule is something for later.
      class Plugin < Dav::ServerPlugin
        # This is the official CalDAV namespace
        NS_CALDAV = 'urn:ietf:params:xml:ns:caldav'

        # @!attribute [r] server
        #   @!visibility private
        #   Reference to main Server object.
        #
        #   @var Server

        # Returns a list of features for the DAV: HTTP header.
        #
        # @return array
        def features
          ['calendar-auto-schedule', 'calendar-availability']
        end

        # Returns the name of the plugin.
        #
        # Using this name other plugins will be able to access other plugins
        # using Server::getPlugin
        #
        # @return string
        def plugin_name
          'caldav-schedule'
        end

        # Initializes the plugin
        #
        # @param Server server
        # @return void
        def setup(server)
          @server = server
          @server.on('method:POST',          method(:http_post))
          @server.on('propFind',             method(:prop_find))
          @server.on('propPatch',            method(:prop_patch))
          @server.on('calendarObjectChange', method(:calendar_object_change))
          @server.on('beforeUnbind',         method(:before_unbind))
          @server.on('schedule',             method(:schedule_local_delivery))

          ns = "{#{NS_CALDAV}}"

          # This information ensures that the {DAV:}resourcetype property has
          # the correct values.
          @server.resource_type_mapping[IOutbox] = ns + 'schedule-outbox'
          @server.resource_type_mapping[IInbox] = ns + 'schedule-inbox'

          # Properties we protect are made read-only by the server.
          @server.protected_properties += [
            ns + 'schedule-inbox-URL',
            ns + 'schedule-outbox-URL',
            ns + 'calendar-user-address-set',
            ns + 'calendar-user-type',
            ns + 'schedule-default-calendar-URL'
          ]
        end

        # Use this method to tell the server this plugin defines additional
        # HTTP methods.
        #
        # This method is passed a uri. It should only return HTTP methods that are
        # available for the specified uri.
        #
        # @param string uri
        # @return array
        def http_methods(uri)
          begin
            node = @server.tree.node_for_path(uri)
          rescue Dav::Exception::NotFound
            return []
          end

          return ['POST'] if node.is_a?(IOutbox)

          []
        end

        # This method handles POST request for the outbox.
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return bool
        def http_post(request, response)
          # Checking if this is a text/calendar content type
          content_type = request.header('Content-Type') || ''

          return true if content_type.index('text/calendar') != 0

          path = request.path

          # Checking if we're talking to an outbox
          begin
            node = @server.tree.node_for_path(path)
          rescue Dav::Exception::NotFound
            return true
          end

          return true unless node.is_a?(IOutbox)

          @server.transaction_type = 'post-caldav-outbox'
          outbox_request(node, request, response)

          # Returning false breaks the event chain and tells the server we've
          # handled the request.
          false
        end

        # This method handler is invoked during fetching of properties.
        #
        # We use this event to add calendar-auto-schedule-specific properties.
        #
        # @param PropFind prop_find
        # @param INode node
        # @return void
        def prop_find(prop_find, node)
          if node.is_a?(DavAcl::IPrincipal)
            caldav_plugin = @server.plugin('caldav')
            principal_url = node.principal_url

            # schedule-outbox-URL property
            prop_find.handle(
              "{#{NS_CALDAV}}schedule-outbox-URL",
              lambda do
                calendar_home_path = caldav_plugin.calendar_home_for_principal(principal_url)
                outbox_path = calendar_home_path + '/outbox/'

                return Dav::Xml::Property::Href.new(outbox_path)
              end
            )

            # schedule-inbox-URL property
            prop_find.handle(
              "{#{NS_CALDAV}}schedule-inbox-URL",
              lambda do
                calendar_home_path = caldav_plugin.calendar_home_for_principal(principal_url)
                inbox_path = calendar_home_path + '/inbox/'

                return Dav::Xml::Property::Href.new(inbox_path)
              end
            )

            prop_find.handle(
              "{#{NS_CALDAV}}schedule-default-calendar-URL",
              lambda do
                # We don't support customizing this property yet, so in the
                # meantime we just grab the first calendar in the home-set.
                calendar_home_path = caldav_plugin.calendar_home_for_principal(principal_url)

                sccs = "{#{NS_CALDAV}}supported-calendar-component-set"

                result = @server.properties_for_path(
                  calendar_home_path,
                  [
                    '{DAV:}resourcetype',
                    sccs
                  ],
                  1
                )

                result.each do |child|
                  if !child[200].key?('{DAV:}resourcetype') ||
                      !child[200]['{DAV:}resourcetype'].is("{#{NS_CALDAV}}calendar") ||
                      child[200]['{DAV:}resourcetype'].is('{http://calendarserver.org/ns/}shared')
                    # Node is either not a calendar or a shared instance.
                    next
                  end

                  if !child[200].key?(sccs) ||
                      child[200][sccs].value.include?('VEVENT')
                    # Either there is no supported-calendar-component-set
                    # (which is fine) or we found one that supports VEVENT.
                    return Dav::Xml::Property::Href.new(child['href'])
                  end
                end
              end
            )

            # The server currently reports every principal to be of type
            # 'INDIVIDUAL'
            prop_find.handle(
              "{#{NS_CALDAV}}calendar-user-type",
              -> { 'INDIVIDUAL' }
            )
          end

          # Mapping the old property to the new property.
          prop_find.handle(
            '{http://calendarserver.org/ns/}calendar-availability',
            lambda do
              # In case it wasn't clear, the only difference is that we map the
              # old property to a different namespace.
              avail_prop = "{#{NS_CALDAV}}calendar-availability"
              sub_prop_find = Dav::PropFind.new(
                prop_find.path,
                [avail_prop]
              )

              @server.properties_by_node(
                sub_prop_find,
                node
              )

              prop_find.set(
                '{http://calendarserver.org/ns/}calendar-availability',
                sub_prop_find.get(avail_prop),
                sub_prop_find.status(avail_prop)
              )
              nil
            end
          )
        end

        # This method is called during property updates.
        #
        # @param string path
        # @param PropPatch prop_patch
        # @return void
        def prop_patch(path, prop_patch)
          # Mapping the old property to the new property.
          prop_patch.handle(
            '{http://calendarserver.org/ns/}calendar-availability',
            lambda do |value|
              avail_prop = "{#{NS_CALDAV}}calendar-availability"
              sub_prop_patch = Dav::PropPatch.new(avail_prop => value)
              @server.emit('propPatch', [path, sub_prop_patch])
              sub_prop_patch.commit

              return sub_prop_patch.result[avail_prop]
            end
          )
        end

        # This method is triggered whenever there was a calendar object gets
        # created or updated.
        #
        # @param RequestInterface request HTTP request
        # @param ResponseInterface response HTTP Response
        # @param VCalendar v_cal Parsed iCalendar object
        # @param mixed calendar_path Path to calendar collection
        # @param mixed modified The iCalendar object has been touched.
        # @param mixed is_new Whether this was a new item or we're updating one
        # @return void
        def calendar_object_change(request, _response, v_cal, calendar_path, modified, is_new)
          return nil unless schedule_reply(@server.http_request)

          calendar_node = @server.tree.node_for_path(calendar_path)

          addresses = addresses_for_principal(calendar_node.owner)

          if !is_new
            node = @server.tree.node_for_path(request.path)
            old_obj = VObject::Reader.read(node.get)
          else
            old_obj = nil
          end

          process_i_calendar_change(old_obj, v_cal, addresses, [], modified)

          if old_obj
            # Destroy circular references so PHP will GC the object.
            old_obj.destroy
          end
        end

        # This method is responsible for delivering the ITip message.
        #
        # @param ITip\Message itip_message
        # @return void
        def deliver(i_tip_message)
          @server.emit('schedule', [i_tip_message])

          unless i_tip_message.schedule_status
            i_tip_message.schedule_status = '5.2;There was no system capable of delivering the scheduling message'
          end

          # In case the change was considered 'insignificant', we are going to
          # remove any error statuses, if any. See ticket #525.
          base_code = i_tip_message.schedule_status.split('.').first

          if !i_tip_message.significant_change && ['3', '5'].include?(base_code)
            i_tip_message.schedule_status = nil
          end
        end

        # This method is triggered before a file gets deleted.
        #
        # We use this event to make sure that when this happens, attendees get
        # cancellations, and organizers get 'DECLINED' statuses.
        #
        # @param string path
        # @return void
        def before_unbind(path)
          # FIXME: We shouldn't trigger this functionality when we're issuing a
          # MOVE. This is a hack.
          return nil if @server.http_request.method == 'MOVE'

          node = @server.tree.node_for_path(path)

          return if !node.is_a?(ICalendarObject) || node.is_a?(ISchedulingObject)

          return unless schedule_reply(@server.http_request)

          addresses = addresses_for_principal(node.owner)

          broker = VObject::ITip::Broker.new
          messages = broker.parse_event(nil, addresses, node.get)

          messages.each do |message|
            deliver(message)
          end
        end

        # Event handler for the 'schedule' event.
        #
        # This handler attempts to look at local accounts to deliver the
        # scheduling object.
        #
        # @param ITip\Message i_tip_message
        # @return void
        def schedule_local_delivery(i_tip_message)
          acl_plugin = @server.plugin('acl')

          # Local delivery is not available if the ACL plugin is not loaded.
          return nil unless acl_plugin

          caldav_ns = "{#{NS_CALDAV}}"

          principal_uri = acl_plugin.principal_by_uri(i_tip_message.recipient)
          if principal_uri.blank?
            i_tip_message.schedule_status = '3.7;Could not find principal.'
            return
          end

          # We found a principal URL, now we need to find its inbox.
          # Unfortunately we may not have sufficient privileges to find this, so
          # we are temporarily turning off ACL to let this come through.
          #
          # Once we support PHP 5.5, this should be wrapped in a try..finally
          # block so we can ensure that this privilege gets added again after.
          @server.remove_listener('propFind', acl_plugin.method(:prop_find))

          result = @server.properties(
            principal_uri,
            [
              '{DAV:}principal-URL',
              caldav_ns + 'calendar-home-set',
              caldav_ns + 'schedule-inbox-URL',
              caldav_ns + 'schedule-default-calendar-URL',
              '{http://sabredav.org/ns}email-address'
            ]
          )

          # Re-registering the ACL event
          @server.on('propFind', acl_plugin.method(:prop_find), 20)

          unless result.key?(caldav_ns + 'schedule-inbox-URL')
            i_tip_message.schedule_status = '5.2;Could not find local inbox'
            return
          end
          unless result.key?(caldav_ns + 'calendar-home-set')
            i_tip_message.schedule_status = '5.2;Could not locate a calendar-home-set'
            return
          end
          unless result.key?(caldav_ns + 'schedule-default-calendar-URL')
            i_tip_message.schedule_status = '5.2;Could not find a schedule-default-calendar-URL property'
            return
          end

          calendar_path = result[caldav_ns + 'schedule-default-calendar-URL'].href
          home_path = result[caldav_ns + 'calendar-home-set'].href
          inbox_path = result[caldav_ns + 'schedule-inbox-URL'].href

          if i_tip_message.method == 'REPLY'
            privilege = 'schedule-deliver-reply'
          else
            privilege = 'schedule-deliver-invite'
          end

          unless acl_plugin.check_privileges(inbox_path, caldav_ns + privilege, DavAcl::Plugin::R_PARENT, false)
            i_tip_message.schedule_status = "3.8;organizer did not have the #{privilege} privilege on the attendees inbox"
            return
          end

          # Next, we're going to find out if the item already exits in one of
          # the users' calendars.
          uid = i_tip_message.uid

          new_file_name = 'tiliadav-' + Dav::UuidUtil.uuid + '.ics'

          home = @server.tree.node_for_path(home_path)
          inbox = @server.tree.node_for_path(inbox_path)

          current_object = nil
          object_node = nil
          is_new_node = false

          result = home.calendar_object_by_uid(uid)
          if result
            # There was an existing object, we need to update probably.
            object_path = home_path + '/' + result
            object_node = @server.tree.node_for_path(object_path)
            old_i_calendar_data = object_node.get
            current_object = VObject::Reader.read(old_i_calendar_data)
          else
            is_new_node = true
          end

          broker = VObject::ITip::Broker.new
          new_object = broker.process_message(i_tip_message, current_object)

          inbox.create_file(new_file_name, i_tip_message.message.serialize)

          unless new_object
            # We received an iTip message referring to a UID that we don't
            # have in any calendars yet, and processMessage did not give us a
            # calendarobject back.
            #
            # The implication is that processMessage did not understand the
            # iTip message.
            i_tip_message.schedule_status = '5.0;iTip message was not processed by the server, likely because we didn\'t understand it.'
            return
          end

          # Note that we are bypassing ACL on purpose by calling this directly.
          # We may need to look a bit deeper into this later. Supporting ACL
          # here would be nice.
          if is_new_node
            calendar = @server.tree.node_for_path(calendar_path)
            calendar.create_file(new_file_name, new_object.serialize)
          else
            # If the message was a reply, we may have to inform other
            # attendees of this attendees status. Therefore we're shooting off
            # another itipMessage.
            if i_tip_message.method == 'REPLY'
              process_i_calendar_change(
                old_i_calendar_data,
                new_object,
                [i_tip_message.recipient],
                [i_tip_message.sender]
              )
            end
            object_node.put(new_object.serialize)
          end
          i_tip_message.schedule_status = '1.2;Message delivered locally'
        end

        protected

        # This method looks at an old iCalendar object, a new iCalendar object and
        # starts sending scheduling messages based on the changes.
        #
        # A list of addresses needs to be specified, so the system knows who made
        # the update, because the behavior may be different based on if it's an
        # attendee or an organizer.
        #
        # This method may update new_object to add any status changes.
        #
        # @param VCalendar|string old_object
        # @param VCalendar new_object
        # @param array addresses
        # @param array ignore Any addresses to not send messages to.
        # @param bool modified A marker to indicate that the original object
        #   modified by this process.
        # @return void
        def process_i_calendar_change(old_object, new_object, addresses, ignore = [], modified = Box.new(false))
          broker = VObject::ITip::Broker.new
          messages = broker.parse_event(new_object, addresses, old_object)

          modified.value = true if messages.any?

          messages.each do |message|
            next if ignore.include?(message.recipient)

            deliver(message)

            if new_object['VEVENT'].key?('ORGANIZER') && new_object['VEVENT']['ORGANIZER'].normalized_value == message.recipient
              new_object['VEVENT']['ORGANIZER']['SCHEDULE-STATUS'] = message.schedule_status if message.schedule_status
              new_object['VEVENT']['ORGANIZER'].delete('SCHEDULE-FORCE-SEND')
            else
              if new_object['VEVENT'].key?('ATTENDEE')
                new_object['VEVENT']['ATTENDEE'].each do |attendee|
                  next unless attendee.normalized_value == message.recipient

                  attendee['SCHEDULE-STATUS'] = message.schedule_status if message.schedule_status
                  attendee.delete('SCHEDULE-FORCE-SEND')
                  break
                end
              end
            end
          end
        end

        # Returns a list of addresses that are associated with a principal.
        #
        # @param string principal
        # @return array
        def addresses_for_principal(principal)
          cuas = "{#{NS_CALDAV}}calendar-user-address-set"

          properties = @server.properties(
            principal,
            [cuas]
          )

          # If we can't find this information, we'll stop processing
          return [] unless properties.key?(cuas)

          addresses = properties[cuas].hrefs
          addresses
        end

        public

        # This method handles POST requests to the schedule-outbox.
        #
        # Currently, two types of requests are support:
        #   * FREEBUSY requests from RFC 6638
        #   * Simple iTIP messages from draft-desruisseaux-caldav-sched-04
        #
        # The latter is from an expired early draft of the CalDAV scheduling
        # extensions, but iCal depends on a feature from that spec, so we
        # implement it.
        #
        # @param IOutbox outbox_node
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return void
        def outbox_request(outbox_node, request, response)
          outbox_path = request.path

          # Parsing the request body
          begin
            v_object = VObject::Reader.read(request.body)
          rescue VObject::ParseException => e
            raise Dav::Exception::BadRequest, "The request body must be a valid iCalendar object. Parse error: #{e.message}"
          end

          # The incoming iCalendar object must have a METHOD property, and a
          # component. The combination of both determines what type of request
          # this is.
          component_type = nil
          v_object.components.each do |component|
            if component.name != 'VTIMEZONE'
              component_type = component.name
              break
            end
          end

          fail Dav::Exception::BadRequest, 'We expected at least one VTODO, VJOURNAL, VFREEBUSY or VEVENT component' unless component_type

          # Validating the METHOD
          method = v_object['METHOD'].to_s.upcase
          fail Dav::Exception::BadRequest, 'A METHOD property must be specified in iTIP messages' if method.blank?

          # So we support one type of request:
          #
          # REQUEST with a VFREEBUSY component
          acl = @server.plugin('acl')

          if component_type == 'VFREEBUSY' && method == 'REQUEST'
            acl && acl.check_privileges(outbox_path, "{#{NS_CALDAV}}schedule-query-freebusy")
            handle_free_busy_request(outbox_node, v_object, request, response)

            # Destroy circular references so PHP can GC the object.
            v_object.destroy
            v_object = nil
          else
            fail Dav::Exception::NotImplemented, 'We only support VFREEBUSY (REQUEST) on this endpoint'
          end
        end

        protected

        # This method is responsible for parsing a free-busy query request and
        # returning it's result.
        #
        # @param IOutbox outbox
        # @param VObject\Component v_object
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return string
        def handle_free_busy_request(outbox, v_object, _request, response)
          v_free_busy = v_object['VFREEBUSY']
          organizer = v_free_busy['ORGANIZER'].to_s

          # Validating if the organizer matches the owner of the inbox.
          owner = outbox.owner

          caldav_ns = "{#{NS_CALDAV}}"

          uas = caldav_ns + 'calendar-user-address-set'
          props = @server.properties(owner, [uas])

          if !props.key?(uas) || !props[uas].hrefs.include?(organizer)
            fail Dav::Exception::Forbidden, 'The organizer in the request did not match any of the addresses for the owner of this inbox'
          end

          unless v_free_busy.key?('ATTENDEE')
            fail Dav::Exception::BadRequest, 'You must at least specify 1 attendee'
          end

          attendees = []
          v_free_busy['ATTENDEE'].each do |attendee|
            attendees << attendee.to_s
          end

          unless v_free_busy.key?('DTSTART') && v_free_busy.key?('DTEND')
            fail Dav::Exception::BadRequest, 'DTSTART and DTEND must both be specified'
          end

          start_range = v_free_busy['DTSTART'].date_time
          end_range = v_free_busy['DTEND'].date_time

          results = []
          attendees.each do |attendee|
            results << free_busy_for_email(attendee, start_range, end_range, v_object)
          end

          dom = LibXML::XML::Document.new

          schedule_response = LibXML::XML::Node.new('cal:schedule-response')
          @server.xml.namespace_map.each do |namespace, prefix|
            schedule_response['xmlns:' + prefix] = namespace
          end

          dom.root = schedule_response

          results.each do |result|
            xresponse = LibXML::XML::Node.new('cal:response')

            recipient = LibXML::XML::Node.new('cal:recipient')
            recipient_href = LibXML::XML::Node.new('d:href', result['href'])

            recipient << recipient_href
            xresponse << recipient

            req_status = LibXML::XML::Node.new('cal:request-status', result['request-status'])
            xresponse << req_status

            if result.key?('calendar-data')
              calendardata = LibXML::XML::Node.new('cal:calendar-data', result['calendar-data'].serialize.gsub("\r\n", "\n"))
              xresponse << calendardata
            end

            schedule_response << xresponse
          end

          response.status = 200
          response.update_header('Content-Type', 'application/xml')
          response.body = dom.to_s
        end

        # Returns free-busy information for a specific address. The returned
        # data is an array containing the following properties:
        #
        # calendar-data : A VFREEBUSY VObject
        # request-status : an iTip status code.
        # href: The principal's email address, as requested
        #
        # The following request status codes may be returned:
        #   * 2.0;description
        #   * 3.7;description
        #
        # @param string email address
        # @param DateTimeInterface start
        # @param DateTimeInterface end
        # @param VObject\Component request
        # @return array
        def free_busy_for_email(email, start, ending, request)
          caldav_ns = "{#{NS_CALDAV}}"

          acl_plugin = @server.plugin('acl')
          email = email[7..-1] if email[0, 7] == 'mailto:'

          result = acl_plugin.principal_search(
            { '{http://sabredav.org/ns}email-address' => email },
            [
              '{DAV:}principal-URL',
              caldav_ns + 'calendar-home-set',
              caldav_ns + 'schedule-inbox-URL',
              '{http://sabredav.org/ns}email-address'
            ]
          )

          if result.empty?
            return {
              'request-status' => '3.7;Could not find principal',
              'href'           => 'mailto:' + email
            }
          end

          unless result[0][200].key?(caldav_ns + 'calendar-home-set')
            return {
              'request-status' => '3.7;No calendar-home-set property found',
              'href'           => 'mailto:' + email
            }
          end

          unless result[0][200].key?(caldav_ns + 'schedule-inbox-URL')
            return {
              'request-status' => '3.7;No schedule-inbox-URL property found',
              'href'           => 'mailto:' + email
            }
          end

          home_set = result[0][200][caldav_ns + 'calendar-home-set'].href
          inbox_url = result[0][200][caldav_ns + 'schedule-inbox-URL'].href

          # Grabbing the calendar list
          objects = []
          calendar_time_zone = ActiveSupport::TimeZone.new('UTC')

          @server.tree.node_for_path(home_set).children.each do |node|
            next unless node.is_a?(ICalendar)

            sct = caldav_ns + 'schedule-calendar-transp'
            ctz = caldav_ns + 'calendar-timezone'
            props = node.properties([sct, ctz])

            if props.key?(sct) && props[sct].value == Xml::Property::ScheduleCalendarTransp::TRANSPARENT
              # If a calendar is marked as 'transparent', it means we must
              # ignore it for free-busy purposes.
              next
            end

            acl_plugin.check_privileges(home_set + node.name, caldav_ns + 'read-free-busy')

            if props.key?(ctz)
              vtimezone_obj = VObject::Reader.read(props[ctz])
              calendar_time_zone = vtimezone_obj['VTIMEZONE'].time_zone

              # Destroy circular references so PHP can garbage collect the object.
              vtimezone_obj.destroy
            end

            # Getting the list of object uris within the time-range
            urls = node.calendar_query(
              'name'         => 'VCALENDAR',
              'comp-filters' => [
                {
                  'name'           => 'VEVENT',
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

            cal_objects = urls.map { |url| node.child(url).get }

            objects += cal_objects
          end

          inbox_props = @server.properties(
            inbox_url,
            caldav_ns + 'calendar-availability'
          )

          vcalendar = VObject::Component::VCalendar.new
          vcalendar['METHOD'] = 'REPLY'

          generator = VObject::FreeBusyGenerator.new
          generator.objects = objects
          generator.time_range = start..ending
          generator.base_object = vcalendar
          generator.time_zone = calendar_time_zone

          if inbox_props.any?
            generator.v_availability = VObject::Reader.read(
              inbox_props[caldav_ns + 'calendar-availability']
            )
          end

          result = generator.result

          vcalendar['VFREEBUSY']['ATTENDEE'] = 'mailto:' + email
          vcalendar['VFREEBUSY']['UID'] = request['VFREEBUSY']['UID'].to_s
          vcalendar['VFREEBUSY']['ORGANIZER'] = request['VFREEBUSY']['ORGANIZER'].deep_dup

          {
            'calendar-data'  => result,
            'request-status' => '2.0;Success',
            'href'           => 'mailto:' + email
          }
        end

        private

        # This method checks the 'Schedule-Reply' header
        # and returns false if it's 'F', otherwise true.
        #
        # @param RequestInterface request
        # @return bool
        def schedule_reply(request)
          schedule_reply = request.header('Schedule-Reply')
          schedule_reply != 'F'
        end

        public

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
            'description' => 'Adds calendar-auto-schedule, as defined in rf6868',
            'link'        => 'http://sabre.io/dav/scheduling/'
          }
        end
      end
    end
  end
end
