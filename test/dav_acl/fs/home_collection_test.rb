require 'test_helper'

module Tilia
  module DavAcl
    module Fs
      class HomeCollectionTest < Minitest::Test
        def setup
          @name = 'thuis'
          @path = Dir.mktmpdir
          principal_backend = PrincipalBackend::Mock.new
          @sut = HomeCollection.new(principal_backend, @path)
          @sut.collection_name = @name
        end

        def teardown
          FileUtils.remove_entry @path
        end

        def test_get_name
          assert_equal(
            @name,
            @sut.name
          )
        end

        def test_get_child
          child = @sut.child('user1')
          assert_kind_of(Collection, child)
          assert_equal('user1', child.name)

          owner = 'principals/user1'
          acl = [
            {
              'privilege' => '{DAV:}read',
              'principal' => owner,
              'protected' => true
            },
            {
              'privilege' => '{DAV:}write',
              'principal' => owner,
              'protected' => true
            }
          ]

          assert_equal(acl, child.acl)
          assert_equal(owner, child.owner)
        end

        def test_get_owner
          assert_nil(@sut.owner)
        end

        def test_get_group
          assert_nil(@sut.group)
        end

        def test_get_acl
          acl = [
            {
              'principal' => '{DAV:}authenticated',
              'privilege' => '{DAV:}read',
              'protected' => true
            }
          ]

          assert_equal(
            acl,
            @sut.acl
          )
        end

        def test_set_acl
          assert_raises(Dav::Exception::Forbidden) { @sut.acl = [] }
        end

        def test_get_supported_privilege_set
          assert_nil(@sut.supported_privilege_set)
        end
      end
    end
  end
end
