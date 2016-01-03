require 'test_helper'

module Tilia
  module CalDav
    class SharedCalendarTest < Minitest::Test
      def instance(props = nil)
        unless props
          props = {
            'id' => 1,
            '{http://calendarserver.org/ns/}shared-url' => 'calendars/owner/original',
            '{http://sabredav.org/ns}owner-principal' => 'principals/owner',
            '{http://sabredav.org/ns}read-only' => false,
            'principaluri' => 'principals/sharee'
          }
        end

        @backend = Backend::MockSharing.new(
          [props]
        )
        @backend.update_shares(
          1,
          [ # Hash in Array
            'href' => 'mailto:removeme@example.org',
            'commonName' => 'To be removed',
            'readOnly' => true
          ],
          []
        )

        SharedCalendar.new(@backend, props)
      end

      def test_get_shared_url
        assert_equal('calendars/owner/original', instance.shared_url)
      end

      def test_get_shares
        assert_equal(
          [
            'href' => 'mailto:removeme@example.org',
            'commonName' => 'To be removed',
            'readOnly' => true,
            'status' => SharingPlugin::STATUS_NORESPONSE
          ],
          instance.shares
        )
      end

      def test_get_owner
        assert_equal('principals/owner', instance.owner)
      end

      def test_get_acl
        expected = [
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/owner',
            'protected' => true
          },

          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/owner/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/owner/calendar-proxy-read',
            'protected' => true
          },
          {
            'privilege' => "{#{Plugin::NS_CALDAV}}read-free-busy",
            'principal' => '{DAV:}authenticated',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => 'principals/owner',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => 'principals/owner/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/sharee',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => 'principals/sharee',
            'protected' => true
          }
        ]

        assert_equal(expected, instance.acl)
      end

      def test_get_child_acl
        expected = [
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/owner',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/owner/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/owner/calendar-proxy-read',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => 'principals/owner',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => 'principals/owner/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/sharee',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => 'principals/sharee',
            'protected' => true
          }
        ]

        assert_equal(expected, instance.child_acl)
      end

      def test_get_child_acl_read_only
        expected = [
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/owner',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/owner/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/owner/calendar-proxy-read',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/sharee',
            'protected' => true
          }
        ]

        props = {
          'id' => 1,
          '{http://calendarserver.org/ns/}shared-url' => 'calendars/owner/original',
          '{http://sabredav.org/ns}owner-principal' => 'principals/owner',
          '{http://sabredav.org/ns}read-only' => true,
          'principaluri' => 'principals/sharee'
        }
        assert_equal(expected, instance(props).child_acl)
      end

      def test_create_instance_missing_arg
        assert_raises(ArgumentError) do
          instance(
            'id' => 1,
            '{http://calendarserver.org/ns/}shared-url' => 'calendars/owner/original',
            '{http://sabredav.org/ns}read-only' => false,
            'principaluri' => 'principals/sharee'
          )
        end
      end
    end
  end
end
