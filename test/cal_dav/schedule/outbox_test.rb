require 'test_helper'

module Tilia
  module CalDav
    module Schedule
      class OutboxTest < Minitest::Test
        def test_setup
          outbox = Outbox.new('principals/user1')
          assert_equal('outbox', outbox.name)
          assert_equal([], outbox.children)
          assert_equal('principals/user1', outbox.owner)
          assert_equal(nil, outbox.group)

          assert_equal(
            [
              {
                'privilege' => "{#{Plugin::NS_CALDAV}}schedule-query-freebusy",
                'principal' => 'principals/user1',
                'protected' => true
              },

              {
                'privilege' => "{#{Plugin::NS_CALDAV}}schedule-post-vevent",
                'principal' => 'principals/user1',
                'protected' => true
              },
              {
                'privilege' => '{DAV:}read',
                'principal' => 'principals/user1',
                'protected' => true
              },
              {
                'privilege' => "{#{Plugin::NS_CALDAV}}schedule-query-freebusy",
                'principal' => 'principals/user1/calendar-proxy-write',
                'protected' => true
              },
              {
                'privilege' => "{#{Plugin::NS_CALDAV}}schedule-post-vevent",
                'principal' => 'principals/user1/calendar-proxy-write',
                'protected' => true
              },
              {
                'privilege' => '{DAV:}read',
                'principal' => 'principals/user1/calendar-proxy-read',
                'protected' => true
              },
              {
                'privilege' => '{DAV:}read',
                'principal' => 'principals/user1/calendar-proxy-write',
                'protected' => true
              }
            ],
            outbox.acl
          )

          assert_raises(Dav::Exception::MethodNotAllowed) do
            outbox.acl = []
          end
        end

        def test_get_supported_privilege_set
          outbox = Outbox.new('principals/user1')
          r = outbox.supported_privilege_set

          ok = 0
          r['aggregates'].each do |priv|
            ok += 1 if priv['privilege'] == "{#{Plugin::NS_CALDAV}}schedule-query-freebusy"
            ok += 1 if priv['privilege'] == "{#{Plugin::NS_CALDAV}}schedule-post-vevent"
          end

          assert_equal(2, ok, "We're missing one or more privileges")
        end
      end
    end
  end
end
