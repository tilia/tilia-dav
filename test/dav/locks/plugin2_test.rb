require 'test_helper'

module Tilia
  module Dav
    module Locks
      class Plugin2Test < DavServerTest
        def setup
          @setup_locks = true
          super
        end

        def set_up_tree
          @tree = Fs::Directory.new(@temp_dir)
        end

        # This test first creates a file with LOCK and then deletes it.
        #
        # After deleting the file, the lock should no longer be in the lock
        # backend.
        #
        # Reported in ticket #487
        def test_unlock_after_delete
          body = <<XML
<?xml version="1.0"?>
<D:lockinfo xmlns:D="DAV:">
    <D:lockscope><D:exclusive/></D:lockscope>
    <D:locktype><D:write/></D:locktype>
</D:lockinfo>
XML

          request = Http::Request.new(
            'LOCK',
            '/file.txt',
            {},
            body
          )
          response = request(request)
          assert_equal(201, response.status, response.body_as_string)

          assert_equal(
            1,
            @locks_backend.locks('file.txt', true).size
          )

          request = Http::Request.new(
            'DELETE',
            '/file.txt',
            'If' => "(#{response.header('Lock-Token')})"
          )
          response = request(request)
          assert_equal(204, response.status, response.body_as_string)

          assert_equal(
            0,
            @locks_backend.locks('file.txt', true).size
          )
        end
      end
    end
  end
end
