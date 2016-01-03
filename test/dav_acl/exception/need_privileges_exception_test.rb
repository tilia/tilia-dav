require 'test_helper'

module Tilia
  module DavAcl
    module Exception
      class NeedPrivilegesTest < Minitest::Test
        def test_serialize
          uri = 'foo'
          privileges = [
            '{DAV:}read',
            '{DAV:}write'
          ]
          ex = NeedPrivileges.new(uri, privileges)

          server = Dav::ServerMock.new
          dom = LibXML::XML::Document.new
          root = LibXML::XML::Node.new('d:root')
          LibXML::XML::Namespace.new(root, 'd', 'DAV:')
          dom.root = root

          ex.serialize(server, root)

          # Reloading because PHP DOM sucks (And ruby seems to need it, too)
          dom2 = LibXML::XML::Document.string(dom.to_s)

          xpaths = {
            '/d:root' => 1,
            '/d:root/d:need-privileges' => 1,
            '/d:root/d:need-privileges/d:resource' => 2,
            '/d:root/d:need-privileges/d:resource/d:href' => 2,
            '/d:root/d:need-privileges/d:resource/d:privilege' => 2,
            '/d:root/d:need-privileges/d:resource/d:privilege/d:read' => 1,
            '/d:root/d:need-privileges/d:resource/d:privilege/d:write' => 1
          }

          xpaths.each do |xpath, count|
            assert_equal(count, dom2.find(xpath).length, "Looking for : #{xpath}, we could only find #{dom2.find(xpath).length} elements, while we expected #{count}")
          end
        end
      end
    end
  end
end
