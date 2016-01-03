require 'test_helper'

module Tilia
  module CalDav
    module Notifications
      class CollectionTest < Minitest::Test
        def setup
          @principal_uri = 'principals/user1'

          @notification = Xml::Notification::SystemStatus.new(1, '"1"')

          @caldav_backend = Backend::MockSharing.new(
            [],
            {},
            'principals/user1' => [@notification]
          )

          @collection = Collection.new(@caldav_backend, @principal_uri)
        end

        def test_get_children
          assert_equal('notifications', @collection.name)

          assert_instance_equal(
            [Node.new(@caldav_backend, @principal_uri, @notification)],
            @collection.children
          )
        end

        def test_get_owner
          assert_equal('principals/user1', @collection.owner)
        end

        def test_get_group
          assert_nil(@collection.group)
        end

        def test_get_acl
          expected = [
            {
              'privilege' => '{DAV:}read',
              'principal' => @principal_uri,
              'protected' => true
            },
            {
              'privilege' => '{DAV:}write',
              'principal' => @principal_uri,
              'protected' => true
            }
          ]

          assert_equal(expected, @collection.acl)
        end

        def test_set_acl
          assert_raises(Dav::Exception::NotImplemented) do
            @collection.acl = []
          end
        end

        def test_get_supported_privilege_set
          assert_nil(@collection.supported_privilege_set)
        end
      end
    end
  end
end
