require 'test_helper'

module Tilia
  module CalDav
    def setup
      @backend = DatabaseUtil.backend

      calendars = @backend.calendars_for_user('principals/user1')
      assert_equal(2, calendars.size)
      @calendar = Calendar.new(@backend, calendars[0])
    end

    def test_setup
      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])

      assert_kind_of(String, children[0].name)
      assert_kind_of(String, children[0].get)
      assert_kind_of(String, children[0].etag)
      assert_equal('text/calendar; charset=utf-8; component=vevent', children[0].content_type)
    end

    # @expectedException InvalidArgumentException
    def test_invalid_arg1
      assert_raises(ArgumentError) do
        CalendarObject.new(
          Backend::Mock.new([], {}),
          {},
          {}
        )
      end
    end

    def test_invalid_arg2
      assert_raises(ArgumentError) do
        CalendarObject.new(
          Backend::Mock.new([], {}),
          {},
          'calendarid' => '1'
        )
      end
    end

    def test_put
      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])
      new_data = DatabaseUtil.get_test_calendar_data

      children[0].put(new_data)
      assert_equal(new_data, children[0].get)
    end

    def test_put_stream
      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])
      new_data = DatabaseUtil.get_test_calendar_data

      stream = StringIO.new
      stream.write(new_data)
      stream.rewind
      children[0].put(stream)
      assert_equal(new_data, children[0].get)
    end

    def test_delete
      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])

      obj = children[0]
      obj.delete

      children2 = @calendar.children
      assert_equal(children.size - 1, children2.size)
    end

    def test_get_last_modified
      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])

      obj = children[0]

      last_mod = obj.last_modified
      assert_kind_of(Fixnum, last_mod)
    end

    def test_get_size
      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])

      obj = children[0]

      size = obj.size
      assert_kind_of(Fixnum, size)
    end

    def test_get_owner
      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])

      obj = children[0]
      assert_equal('principals/user1', obj.owner)
    end

    def test_get_group
      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])

      obj = children[0]
      assert_nil(obj.group)
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

      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])

      obj = children[0]
      assert_equal(expected, obj.acl)
    end

    def test_default_acl
      backend = Backend::Mock.new([], [])
      calendar_object = CalendarObject.new(
        backend,
        { 'principaluri' => 'principals/user1' },
        'calendarid' => 1, 'uri' => 'foo'
      )
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
      assert_equal(expected, calendar_object.acl)
    end

    def test_set_acl
      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])

      obj = children[0]
      assert_raises(Dav::Exception::MethodNotAllowed) do
        obj.acl = []
      end
    end

    def test_get
      children = @calendar.children
      assert_kind_of(CalendarObject, children[0])

      obj = children[0]

      expected = <<VCF
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Apple Inc.//iCal 4.0.1//EN
CALSCALE:GREGORIAN
BEGIN:VTIMEZONE
TZID:Asia/Seoul
BEGIN:DAYLIGHT
TZOFFSETFROM:+0900
RRULE:FREQ=YEARLY;UNTIL=19880507T150000Z;BYMONTH=5;BYDAY=2SU
DTSTART:19870510T000000
TZNAME:GMT+09:00
TZOFFSETTO:+1000
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:+1000
DTSTART:19881009T000000
TZNAME:GMT+09:00
TZOFFSETTO:+0900
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
CREATED:20100225T154229Z
UID:39A6B5ED-DD51-4AFE-A683-C35EE3749627
TRANSP:TRANSPARENT
SUMMARY:Something here
DTSTAMP:20100228T130202Z
DTSTART;TZID=Asia/Seoul:20100223T060000
DTEND;TZID=Asia/Seoul:20100223T070000
ATTENDEE;PARTSTAT=NEEDS-ACTION:mailto:lisa@example.com
SEQUENCE:2
END:VEVENT
END:VCALENDAR
VCF

      assert_equal(expected, obj.get)
    end

    def test_get_refetch
      backend = Backend::Mock.new(
        [],
        1 => {
          'foo' => {
            'calendardata' => 'foo',
            'uri' => 'foo'
          }
        }
      )
      obj = CalendarObject.new(backend, { 'id' => 1 }, 'uri' => 'foo')

      assert_equal('foo', obj.get)
    end

    def test_get_etag1
      object_info = {
        'calendardata' => 'foo',
        'uri' => 'foo',
        'etag' => 'bar',
        'calendarid' => 1
      }

      backend = Backend::Mock.new([], {})
      obj = CalendarObject.new(backend, {}, object_info)

      assert_equal('bar', obj.etag)
    end

    def test_get_etag2
      object_info = {
        'calendardata' => 'foo',
        'uri' => 'foo',
        'calendarid' => 1
      }

      backend = Backend::Mock.new([], {})
      obj = CalendarObject.new(backend, {}, object_info)

      assert_equal("\"#{Digest::MD5.hex_digest('foo')}\"", obj.etag)
    end

    def test_get_supported_privileges_set
      object_info = {
        'calendardata' => 'foo',
        'uri' => 'foo',
        'calendarid' => 1
      }

      backend = Backend::Mock.new([], {})
      obj = CalendarObject.new(backend, {}, object_info)
      assert_nil(obj.supported_privilege_set)
    end

    def test_get_size1
      object_info = {
        'calendardata' => 'foo',
        'uri' => 'foo',
        'calendarid' => 1
      }

      backend = Backend::Mock.new([], {})
      obj = CalendarObject.new(backend, {}, object_info)
      assert_equal(3, obj.size)
    end

    def test_get_size2
      object_info = {
        'uri' => 'foo',
        'calendarid' => 1,
        'size' => 4
      }

      backend = Backend::Mock.new([], {})
      obj = CalendarObject.new(backend, {}, object_info)
      assert_equal(4, obj.size)
    end
  end
end
