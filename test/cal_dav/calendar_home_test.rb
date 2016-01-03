require 'test_helper'

module Tilia
  module CalDav
    class CalendarHomeTest < Minitest::Test
      def setup
        @backend = DatabaseUtil.backend
        @usercalendars = CalendarHome.new(
          @backend,
          'uri' => 'principals/user1'
        )
      end

      def test_simple
        assert_equal('user1', @usercalendars.name)
      end

      def test_get_child_not_found
        assert_raises(Dav::Exception::NotFound) do
          @usercalendars.child('randomname')
        end
      end

      def test_child_exists
        refute(@usercalendars.child_exists('foo'))
        assert(@usercalendars.child_exists('UUID-123467'))
      end

      def test_get_owner
        assert_equal('principals/user1', @usercalendars.owner)
      end

      def test_get_group
        assert_nil(@usercalendars.group)
      end

      def test_get_acl
        expected = [
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/user1',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => 'principals/user1',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/user1/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => 'principals/user1/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/user1/calendar-proxy-read',
            'protected' => true
          }
        ]
        assert_equal(expected, @usercalendars.acl)
      end

      def test_set_acl
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @usercalendars.acl = []
        end
      end

      def test_set_name
        assert_raises(Dav::Exception::Forbidden) do
          @usercalendars.name = 'bla'
        end
      end

      def test_delete
        assert_raises(Dav::Exception::Forbidden) do
          @usercalendars.delete
        end
      end

      def test_get_last_modified
        assert_nil(@usercalendars.last_modified)
      end

      def test_create_file
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @usercalendars.create_file('bla')
        end
      end

      def test_create_directory
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @usercalendars.create_directory('bla')
        end
      end

      def test_create_extended_collection
        mk_col = Dav::MkCol.new(
          ['{DAV:}collection', '{urn:ietf:params:xml:ns:caldav}calendar'],
          {}
        )
        result = @usercalendars.create_extended_collection('newcalendar', mk_col)
        assert_nil(result)
        cals = @backend.calendars_for_user('principals/user1')
        assert_equal(3, cals.size)
      end

      def test_create_extended_collection_bad_resource_type
        mk_col = Dav::MkCol.new(
          ['{DAV:}collection', '{DAV:}blabla'],
          {}
        )
        assert_raises(Dav::Exception::InvalidResourceType) do
          @usercalendars.create_extended_collection('newcalendar', mk_col)
        end
      end

      def test_create_extended_collection_not_a_calendar
        mk_col = Dav::MkCol.new(
          ['{DAV:}collection'],
          {}
        )
        assert_raises(Dav::Exception::InvalidResourceType) do
          @usercalendars.create_extended_collection('newcalendar', mk_col)
        end
      end

      def test_get_supported_privileges_set
        assert_nil(@usercalendars.supported_privilege_set)
      end

      def test_share_reply_fail
        assert_raises(Dav::Exception::NotImplemented) do
          @usercalendars.share_reply('uri', SharingPlugin::STATUS_DECLINED, 'curi', '1')
        end
      end
    end
  end
end
