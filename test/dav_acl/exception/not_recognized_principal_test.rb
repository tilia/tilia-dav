require 'test_helper'

module Tilia
  module DavAcl
    module Exception
      class NotRecognizedPrincipalTest < Minitest::Test
        def test_serialize
          ex = NotRecognizedPrincipal.new('message')

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
            '/d:root/d:recognized-principal' => 1
          }

          xpaths.each do |xpath, count|
            assert_equal(count, dom2.find(xpath).length, "Looking for : #{xpath}, we could only find #{dom2.find(xpath).length} elements, while we expected #{count}")
          end
        end
      end
    end
  end
end
