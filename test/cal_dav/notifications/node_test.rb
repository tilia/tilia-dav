require 'test_helper'

module Tilia
  module CalDav
    module Notifications
      class NodeTest < Minitest::Test
        def setup
          principal_uri = 'principals/user1'

          @system_status = Xml::Notification::SystemStatus.new(1, '"1"')

          @caldav_backend = Backend::MockSharing.new(
            [],
            {},
            'principals/user1' => [
              @system_status
            ]
          )

          @node = Node.new(@caldav_backend, 'principals/user1', @system_status)
        end

        def test_get_id
          assert_equal(@system_status.id.to_s + '.xml', @node.name)
        end

        def test_get_etag
          assert_equal('"1"', @node.etag)
        end

        def test_get_notification_type
          assert_equal(@system_status, @node.notification_type)
        end

        def test_delete
          @node.delete
          assert_equal([], @caldav_backend.notifications_for_principal('principals/user1'))
        end

        def test_get_group
          assert_nil(@node.group)
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
            }
          ]

          assert_equal(expected, @node.acl)
        end

        def test_set_acl
          assert_raises(Dav::Exception::NotImplemented) do
            @node.acl = []
          end
        end

        def test_get_supported_privilege_set
          assert_nil(@node.supported_privilege_set)
        end
      end
    end
  end
end
