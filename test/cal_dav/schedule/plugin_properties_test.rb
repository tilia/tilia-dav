require 'test_helper'

module Tilia
  module CalDav
    module Schedule
      class PluginPropertiesTest < DavServerTest
        def setup
          @setup_cal_dav = true
          @setup_cal_dav_scheduling = true
          @setup_property_storage = true

          super

          @caldav_backend.create_calendar(
            'principals/user1',
            'default',
            {}
          )
          @principal_backend.add_principal(
            'uri' => 'principals/user1/calendar-proxy-read'
          )
        end

        def test_principal_properties
          props = @server.properties_for_path(
            '/principals/user1',
            [
              '{urn:ietf:params:xml:ns:caldav}schedule-inbox-URL',
              '{urn:ietf:params:xml:ns:caldav}schedule-outbox-URL',
              '{urn:ietf:params:xml:ns:caldav}calendar-user-address-set',
              '{urn:ietf:params:xml:ns:caldav}calendar-user-type',
              '{urn:ietf:params:xml:ns:caldav}schedule-default-calendar-URL'
            ]
          )

          assert(props[0])
          assert_has_key(200, props[0])

          assert_has_key('{urn:ietf:params:xml:ns:caldav}schedule-outbox-URL', props[0][200])
          prop = props[0][200]['{urn:ietf:params:xml:ns:caldav}schedule-outbox-URL']
          assert_kind_of(Dav::Xml::Property::Href, prop)
          assert_equal('calendars/user1/outbox/', prop.href)

          assert_has_key('{urn:ietf:params:xml:ns:caldav}schedule-inbox-URL', props[0][200])
          prop = props[0][200]['{urn:ietf:params:xml:ns:caldav}schedule-inbox-URL']
          assert_kind_of(Dav::Xml::Property::Href, prop)
          assert_equal('calendars/user1/inbox/', prop.href)

          assert_has_key('{urn:ietf:params:xml:ns:caldav}calendar-user-address-set', props[0][200])
          prop = props[0][200]['{urn:ietf:params:xml:ns:caldav}calendar-user-address-set']
          assert_kind_of(Dav::Xml::Property::Href, prop)
          assert_equal(['mailto:user1.sabredav@sabredav.org', '/principals/user1/'], prop.hrefs)

          assert_has_key('{urn:ietf:params:xml:ns:caldav}calendar-user-type', props[0][200])
          prop = props[0][200]['{urn:ietf:params:xml:ns:caldav}calendar-user-type']
          assert_equal('INDIVIDUAL', prop)

          assert_has_key('{urn:ietf:params:xml:ns:caldav}schedule-default-calendar-URL', props[0][200])
          prop = props[0][200]['{urn:ietf:params:xml:ns:caldav}schedule-default-calendar-URL']
          assert_equal('calendars/user1/default/', prop.href)
        end

        def test_principal_properties_bad_principal
          props = @server.properties_for_path(
            'principals/user1/calendar-proxy-read',
            [
              '{urn:ietf:params:xml:ns:caldav}schedule-inbox-URL',
              '{urn:ietf:params:xml:ns:caldav}schedule-outbox-URL',
              '{urn:ietf:params:xml:ns:caldav}calendar-user-address-set',
              '{urn:ietf:params:xml:ns:caldav}calendar-user-type',
              '{urn:ietf:params:xml:ns:caldav}schedule-default-calendar-URL',
            ]
          )

          assert(props[0])
          assert_has_key(200, props[0])
          assert_has_key(404, props[0])

          assert_has_key('{urn:ietf:params:xml:ns:caldav}schedule-outbox-URL', props[0][404])
          assert_has_key('{urn:ietf:params:xml:ns:caldav}schedule-inbox-URL', props[0][404])

          prop = props[0][200]['{urn:ietf:params:xml:ns:caldav}calendar-user-address-set']
          assert(prop.is_a?(Dav::Xml::Property::Href))
          assert_equal(['/principals/user1/calendar-proxy-read/'], prop.hrefs)

          assert_has_key('{urn:ietf:params:xml:ns:caldav}calendar-user-type', props[0][200])
          prop = props[0][200]['{urn:ietf:params:xml:ns:caldav}calendar-user-type']
          assert_equal('INDIVIDUAL', prop)

          assert_has_key('{urn:ietf:params:xml:ns:caldav}schedule-default-calendar-URL', props[0][404])
        end

        def test_no_default_calendar
          @caldav_backend.calendars_for_user('principals/user1').each do |calendar|
            @caldav_backend.delete_calendar(calendar['id'])
          end

          props = @server.properties_for_path(
            '/principals/user1',
            [
              '{urn:ietf:params:xml:ns:caldav}schedule-default-calendar-URL'
            ]
          )

          assert(props[0])
          assert_has_key(404, props[0])

          assert_has_key('{urn:ietf:params:xml:ns:caldav}schedule-default-calendar-URL', props[0][404])
        end

        # There are two properties for availability. The server should
        # automatically map the old property to the standard property.
        def test_availability_mapping
          path = 'calendars/user1/inbox'
          old_prop = '{http://calendarserver.org/ns/}calendar-availability'
          new_prop = '{urn:ietf:params:xml:ns:caldav}calendar-availability'
          value1 = 'first value'
          value2 = 'second value'

          # Storing with the old name
          @server.update_properties(
            path,
            old_prop => value1
          )

          # Retrieving with the new name
          assert_equal(
            { new_prop => value1 },
            @server.properties(path, [new_prop])
          )

          # Storing with the new name
          @server.update_properties(
            path,
            new_prop => value2
          )

          # Retrieving with the old name
          assert_equal(
            { old_prop => value2 },
            @server.properties(path, [old_prop])
          )
        end
      end
    end
  end
end
