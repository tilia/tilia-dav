require 'test_helper'

module Tilia
  module CalDav
    class CalendarTest < Minitest::Test
      def setup
        @backend = DatabaseUtil.backend

        @calendars = @backend.calendars_for_user('principals/user1')
        assert_equal(2, @calendars.size)
        @calendar = Calendar.new(@backend, @calendars[0])
      end

      def test_simple
        assert_equal(@calendars[0]['uri'], @calendar.name)
      end

      def test_update_properties
        prop_patch = Dav::PropPatch.new('{DAV:}displayname' => 'NewName')

        result = @calendar.prop_patch(prop_patch)
        result = prop_patch.commit

        assert_equal(true, result)

        calendars2 = @backend.calendars_for_user('principals/user1')
        assert_equal('NewName', calendars2[0]['{DAV:}displayname'])
      end

      def test_get_properties
        question = [
          '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set'
        ]

        result = @calendar.properties(question)

        question.each { |q| assert_has_key(q, result) }

        assert_equal(['VEVENT', 'VTODO'], result['{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set'].value)
      end

      def test_get_child_not_found
        assert_raises(Dav::Exception::NotFound) do
          @calendar.child('randomname')
        end
      end

      def test_get_children
        children = @calendar.children
        assert_equal(1, children.size)

        assert_kind_of(CalendarObject, children[0])
      end

      def test_child_exists
        refute(@calendar.child_exists('foo'))

        children = @calendar.children
        assert(@calendar.child_exists(children[0].name))
      end

      def test_create_directory
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @calendar.create_directory('hello')
        end
      end

      def test_set_name
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @calendar.name = 'hello'
        end
      end

      def test_get_last_modified
        assert_nil(@calendar.last_modified)
      end

      def test_create_file
        file = StringIO.new
        file.write(DatabaseUtil.get_test_calendar_data)
        file.rewind

        @calendar.create_file('hello', file)

        file = @calendar.child('hello')
        assert_kind_of(CalendarObject, file)
      end

      def test_create_file_no_supported_components
        file = StringIO.new
        file.write(DatabaseUtil.get_test_calendar_data)
        file.rewind

        calendar = Calendar.new(@backend, @calendars[1])
        calendar.create_file('hello', file)

        file = calendar.child('hello')
        assert_kind_of(CalendarObject, file)
      end

      def test_delete
        @calendar.delete

        calendars = @backend.calendars_for_user('principals/user1')
        assert_equal(1, calendars.size)
      end

      def test_get_owner
        assert_equal('principals/user1', @calendar.owner)
      end

      def test_get_group
        assert_nil(@calendar.group)
      end

      def test_get_acl
        expected = [
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/user1',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/user1/calendar-proxy-write',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}read',
            'principal' => 'principals/user1/calendar-proxy-read',
            'protected' => true
          },
          {
            'privilege' => "{#{Plugin::NS_CALDAV}}read-free-busy",
            'principal' => '{DAV:}authenticated',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => 'principals/user1',
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => 'principals/user1/calendar-proxy-write',
            'protected' => true
          }
        ]

        assert_equal(expected, @calendar.acl)
      end

      def test_set_acl
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @calendar.acl = []
        end
      end

      def test_get_supported_privileges_set
        result = @calendar.supported_privilege_set

        assert_equal(
          "{#{Plugin::NS_CALDAV}}read-free-busy",
          result['aggregates'][0]['aggregates'][2]['privilege']
        )
      end

      def test_get_sync_token
        assert_equal(2, @calendar.sync_token)
      end

      def test_get_sync_token2
        calendar = Calendar.new(
          Backend::Mock.new([], {}),
          '{DAV:}sync-token' => 2
        )
        assert_equal(2, @calendar.sync_token)
      end

      def test_get_sync_token_no_sync_support
        calendar = Calendar.new(Backend::Mock.new([], {}), {})
        assert_nil(calendar.sync_token)
      end

      def test_get_changes
        assert_equal(
          {
            'syncToken' => 2,
            'modified'  => [],
            'deleted'   => [],
            'added'     => ['UUID-2345']
          },
          @calendar.changes(1, 1)
        )
      end

      def test_get_changes_no_sync_support
        calendar = Calendar.new(Backend::Mock.new([], {}), {})
        assert_nil(calendar.changes(1, nil))
      end
    end
  end
end
