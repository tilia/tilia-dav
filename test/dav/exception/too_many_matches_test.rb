require 'test_helper'

module Tilia
  module Dav
    class Exception
      class TooManyMatchesTest < Minitest::Test
        def test_serialize
          dom = LibXML::XML::Document.new
          root = LibXML::XML::Node.new('d:root')
          LibXML::XML::Namespace.new(root, 'd', 'DAV:')
          dom.root = root

          locked = TooManyMatches.new

          locked.serialize(ServerMock.new, root)

          output = dom.to_s

          expected = <<XML
<?xml version="1.0" encoding="UTF-8"?>
<d:root xmlns:d="DAV:">
  <d:number-of-matches-within-limits/>
</d:root>
XML

          assert_xml_equal(expected, output)
        end
      end
    end
  end
end
