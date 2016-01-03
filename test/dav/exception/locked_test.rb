require 'test_helper'

module Tilia
  module Dav
    class Exception
      class LockedTest < Minitest::Test
        def test_serialize
          dom = LibXML::XML::Document.new
          root = LibXML::XML::Node.new('d:root')
          LibXML::XML::Namespace.new(root, 'd', 'DAV:')
          dom.root = root

          lock_info = Locks::LockInfo.new
          lock_info.uri = '/foo'
          locked = Locked.new(lock_info)

          locked.serialize(ServerMock.new, root)

          output = dom.to_s

          expected = <<XML
<?xml version="1.0" encoding="UTF-8"?>
<d:root xmlns:d="DAV:">
  <d:lock-token-submitted>
    <d:href>/foo</d:href>
  </d:lock-token-submitted>
</d:root>
XML

          assert_xml_equal(expected, output)
        end

        def test_serialize_ampersand
          dom = LibXML::XML::Document.new
          root = LibXML::XML::Node.new('d:root')
          LibXML::XML::Namespace.new(root, 'd', 'DAV:')
          dom.root = root

          lock_info = Locks::LockInfo.new
          lock_info.uri = '/foo&bar'
          locked = Locked.new(lock_info)

          locked.serialize(ServerMock.new, root)

          output = dom.to_s

          expected = <<XML
<?xml version="1.0" encoding="UTF-8"?>
<d:root xmlns:d="DAV:">
  <d:lock-token-submitted>
    <d:href>/foo&amp;bar</d:href>
  </d:lock-token-submitted>
</d:root>
XML

          assert_xml_equal(expected, output)
        end
      end
    end
  end
end
