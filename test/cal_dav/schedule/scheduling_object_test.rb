require 'test_helper'

module Tilia
  module CalDav
    module Schedule
      class SchedulingObjectTest < Minitest::Test
        def setup
          @backend = Backend::MockScheduling.new

          @data = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VEVENT
SEQUENCE:1
END:VEVENT
END:VCALENDAR
ICS
          @data = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VEVENT
SEQUENCE:2
END:VEVENT
END:VCALENDAR
ICS

          @inbox = Inbox.new(@backend, 'principals/user1')
          @inbox.create_file('item1.ics', @data)
        end

        def test_setup
          children = @inbox.children
          assert_kind_of(SchedulingObject, children[0])

          assert_kind_of(String,children[0].name)
          assert_kind_of(String,children[0].get)
          assert_kind_of(String,children[0].etag)
          assert_equal('text/calendar; charset=utf-8', children[0].content_type)
        end

        # @expectedException InvalidArgumentException
        def test_invalid_arg1
          assert_raises(ArgumentError) do
            SchedulingObject.new(
              Backend::MockScheduling.new([],{}),
              {}
            )
          end
        end

        def test_invalid_arg2
          assert_raises(ArgumentError) do
            SchedulingObject.new(
              Backend::MockScheduling.new([],{}),
              'calendarid' => '1'
            )
          end
        end

        def test_put
          children = @inbox.children
          assert_kind_of(SchedulingObject, children[0])

          assert_raises(Dav::Exception::MethodNotAllowed) do
            children[0].put('')
          end
        end

        def test_delete
          children = @inbox.children
          assert_kind_of(SchedulingObject, children[0])

          obj = children[0]
          obj.delete

          children2 =  @inbox.children
          assert_equal(children.size-1, children2.size)
        end

        def test_get_last_modified
          children = @inbox.children
          assert_kind_of(SchedulingObject, children[0])

          obj = children[0]

          last_mod = obj.last_modified
          assert_nil(last_mod)
        end

        def test_get_size
          children = @inbox.children
          assert_kind_of(SchedulingObject, children[0])

          obj = children[0]

          size = obj.size
          assert_kind_of(Integer, size)
        end

        def test_get_owner
          children = @inbox.children
          assert_kind_of(SchedulingObject, children[0])

          obj = children[0]
          assert_equal('principals/user1', obj.owner)
        end

        def test_get_group
          children = @inbox.children
          assert_kind_of(SchedulingObject, children[0])

          obj = children[0]
          assert_nil(obj.group)
        end

        def test_get_acl
          expected = [
              {
                  'privilege' => '{DAV:}read',
                  'principal' => 'principals/user1',
                  'protected' => true,
              },
              {
                  'privilege' => '{DAV:}write',
                  'principal' => 'principals/user1',
                  'protected' => true,
              },
              {
                  'privilege' => '{DAV:}read',
                  'principal' => 'principals/user1/calendar-proxy-write',
                  'protected' => true,
              },
              {
                  'privilege' => '{DAV:}write',
                  'principal' => 'principals/user1/calendar-proxy-write',
                  'protected' => true,
              },
              {
                  'privilege' => '{DAV:}read',
                  'principal' => 'principals/user1/calendar-proxy-read',
                  'protected' => true,
              }
          ]

          children = @inbox.children
          assert_kind_of(SchedulingObject, children[0])

          obj = children[0]
          assert_equal(expected, obj.acl)
        end

        def test_default_acl
          backend = Backend::MockScheduling.new([], {})
          calendar_object = SchedulingObject.new(
            backend,
            'calendarid' => 1,
            'uri' => 'foo',
            'principaluri' => 'principals/user1'
          )

          expected = [
              {
                  'privilege' => '{DAV:}read',
                  'principal' => 'principals/user1',
                  'protected' => true,
              },
              {
                  'privilege' => '{DAV:}write',
                  'principal' => 'principals/user1',
                  'protected' => true,
              },
              {
                  'privilege' => '{DAV:}read',
                  'principal' => 'principals/user1/calendar-proxy-write',
                  'protected' => true,
              },
              {
                  'privilege' => '{DAV:}write',
                  'principal' => 'principals/user1/calendar-proxy-write',
                  'protected' => true,
              },
              {
                  'privilege' => '{DAV:}read',
                  'principal' => 'principals/user1/calendar-proxy-read',
                  'protected' => true,
              },
            ]
          assert_equal(expected, calendar_object.acl)
        end

        # @expectedException Sabre\DAV\Exception\MethodNotAllowed
        def test_set_acl

          children = @inbox.children
          assert_kind_of(SchedulingObject, children[0])

          obj = children[0]
          assert_raises(Dav::Exception::MethodNotAllowed) do
            obj.acl = []
          end
        end

        def test_get
          children = @inbox.children
          assert_kind_of(SchedulingObject, children[0])

          obj = children[0]

          assert_equal(@data, obj.get)
        end

        def test_get_refetch
          backend = Backend::MockScheduling.new
          backend.create_scheduling_object('principals/user1', 'foo', 'foo')

          obj = SchedulingObject.new(
            backend,
              'calendarid' => 1,
              'uri' => 'foo',
              'principaluri' => 'principals/user1',
          )

          assert_equal('foo', obj.get)
        end

        def test_get_etag1
          object_info = {
              'calendardata' => 'foo',
              'uri' => 'foo',
              'etag' => 'bar',
              'calendarid' => 1
          }

          backend = Backend::MockScheduling.new([],{})
          obj = SchedulingObject.new(backend, object_info)

          assert_equal('bar', obj.etag)
        end

        def test_get_etag2
          object_info = {
              'calendardata' => 'foo',
              'uri' => 'foo',
              'calendarid' => 1
          }

          backend = Backend::MockScheduling.new([],{})
          obj = SchedulingObject.new(backend, object_info)

          assert_equal("\"#{Digest::MD5.hexdigest('foo')}\"", obj.etag)
        end

        def test_get_supported_privileges_set
          object_info = {
              'calendardata' => 'foo',
              'uri' => 'foo',
              'calendarid' => 1
          }

          backend = Backend::MockScheduling.new([], {})
          obj = SchedulingObject.new(backend, object_info)
          assert_nil(obj.supported_privilege_set)
        end

        def test_get_size1

          object_info = {
              'calendardata' => 'foo',
              'uri' => 'foo',
              'calendarid' => 1
          }

          backend = Backend::MockScheduling.new([], {})
          obj = SchedulingObject.new(backend, object_info)
          assert_equal(3, obj.size)
        end

        def test_get_size2
          object_info = {
              'uri' => 'foo',
              'calendarid' => 1,
              'size' => 4,
            }

          backend = Backend::MockScheduling.new([], {})
          obj = SchedulingObject.new(backend, object_info)
          assert_equal(4, obj.size)
        end

        def test_get_content_type
          object_info = {
              'uri' => 'foo',
              'calendarid' => 1,
            }

          backend = Backend::MockScheduling.new([], {})
          obj = SchedulingObject.new(backend, object_info)
          assert_equal('text/calendar; charset=utf-8', obj.content_type)
        end

        def test_get_content_type2
          object_info = {
              'uri' => 'foo',
              'calendarid' => 1,
              'component' => 'VEVENT',
            }

          backend = Backend::MockScheduling.new([], {})
          obj = SchedulingObject.new(backend, object_info)
          assert_equal('text/calendar; charset=utf-8; component=VEVENT', obj.content_type)
        end

        def test_get_acl2
          object_info = {
              'uri' => 'foo',
              'calendarid' => 1,
              'acl' => [],
            }

          backend = Backend::MockScheduling.new([], {})
          obj = SchedulingObject.new(backend, object_info)
          assert_equal([], obj.acl)
        end
      end
    end
  end
end
