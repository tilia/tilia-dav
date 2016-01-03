require 'test_helper'

module Tilia
  module CalDav
    module Subscriptions
      class SubscriptionTest < Minitest::Test
        def subscription(override = {})
          caldav_backend = Backend::MockSubscriptionSupport.new([], {})

          info = {
            '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/src', false),
            'lastmodified' => Time.zone.parse('2013-04-06 11:40:00').to_i, # tomorrow is my birthday!
            '{DAV:}displayname' => 'displayname'
          }

          id = caldav_backend.create_subscription('principals/user1', 'uri', info.merge(override))
          sub_info = caldav_backend.subscriptions_for_user('principals/user1')

          assert_equal(1, sub_info.size)
          subscription = Subscription.new(caldav_backend, sub_info[0])

          @backend = caldav_backend
          subscription
        end

        def test_values
          sub = subscription

          assert_equal('uri', sub.name)
          assert_equal(Time.zone.parse('2013-04-06 11:40:00').to_i, sub.last_modified)
          assert_equal([], sub.children)

          assert_instance_equal(
            {
              '{DAV:}displayname' => 'displayname',
              '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/src', false)
            },
            sub.properties(['{DAV:}displayname', '{http://calendarserver.org/ns/}source'])
          )

          assert_equal('principals/user1', sub.owner)
          assert_nil(sub.group)

          acl = [
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
          assert_equal(acl, sub.acl)

          assert_nil(sub.supported_privilege_set)
        end

        def test_values2
          sub = subscription('lastmodified' => nil)

          assert_equal(nil, sub.last_modified)
        end

        def test_set_acl
          sub = subscription
          assert_raises(Dav::Exception::MethodNotAllowed) do
            sub.acl = []
          end
        end

        def test_delete
          sub = subscription
          sub.delete

          assert_equal([], @backend.subscriptions_for_user('principals1/user1'))
        end

        def test_update_properties
          sub = subscription
          prop_patch = Dav::PropPatch.new(
            '{DAV:}displayname' => 'foo'
          )
          sub.prop_patch(prop_patch)
          assert(prop_patch.commit)

          assert_equal(
            'foo',
            @backend.subscriptions_for_user('principals/user1')[0]['{DAV:}displayname']
          )
        end

        def test_bad_construct
          caldav_backend = Backend::MockSubscriptionSupport.new([], {})
          assert_raises(ArgumentError) do
            Subscription.new(caldav_backend, {})
          end
        end
      end
    end
  end
end
