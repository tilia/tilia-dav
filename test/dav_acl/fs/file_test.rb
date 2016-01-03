require 'test_helper'

module Tilia
  module DavAcl
    module Fs
      class FileTest < Minitest::Test
        def setup
          @path = 'foo'
          @acl = [
            {
              'privilege' => '{DAV:}read',
              'principal' => '{DAV:}authenticated'
            }
          ]
          @owner = 'principals/evert'
          @sut = File.new(@path, @acl, @owner)
        end

        def test_get_owner
          assert_equal(
            @owner,
            @sut.owner
          )
        end

        def test_get_group
          assert_nil(@sut.group)
        end

        def test_get_acl
          assert_equal(
            @acl,
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
