require 'test_helper'

module Tilia
  module Dav
    module Xml
      module Element
        class PropTest < XmlTester
          def assert_decode_prop(input, expected, element_map = {})
            element_map['{DAV:}root'] = Tilia::Dav::Xml::Element::Prop

            result = parse(input, element_map)
            assert_kind_of(Hash, result)
            assert_instance_equal(expected, result['value'])
          end

          def test_deserialize_simple
            input = <<XML
<?xml version="1.0"?>
<root xmlns="DAV:">
  <foo>bar</foo>
</root>
XML

            expected = { '{DAV:}foo' => 'bar' }

            assert_decode_prop(input, expected)
          end

          def test_deserialize_empty
            input = <<XML
<?xml version="1.0"?>
<root xmlns="DAV:" />
XML

            expected = {}

            assert_decode_prop(input, expected)
          end

          def test_deserialize_complex
            input = <<XML
<?xml version="1.0"?>
<root xmlns="DAV:">
  <foo><no>yes</no></foo>
</root>
XML

            expected = { '{DAV:}foo' => Tilia::Dav::Xml::Property::Complex.new('<no xmlns="DAV:">yes</no>') }

            assert_decode_prop(input, expected)
          end

          def test_deserialize_custom
            input = <<XML
<?xml version="1.0"?>
<root xmlns="DAV:">
  <foo><href>/hello</href></foo>
</root>
XML

            expected = { '{DAV:}foo' => Tilia::Dav::Xml::Property::Href.new('/hello', false) }

            element_map = { '{DAV:}foo' => Tilia::Dav::Xml::Property::Href }

            assert_decode_prop(input, expected, element_map)
          end

          def test_deserialize_custom_callback
            input = <<XML
<?xml version="1.0"?>
<root xmlns="DAV:">
  <foo>blabla</foo>
</root>
XML

            expected = { '{DAV:}foo' => 'zim' }

            element_map = {
              '{DAV:}foo' => lambda do |reader|
                reader.next
                return 'zim'
              end
            }

            assert_decode_prop(input, expected, element_map)
          end

          def test_deserialize_custom_bad
            input = <<XML
<?xml version="1.0"?>
<root xmlns="DAV:">
  <foo>blabla</foo>
</root>
XML

            expected = {}

            element_map = { '{DAV:}foo' => 'idk?' }

            assert_raises(RuntimeError) { assert_decode_prop(input, expected, element_map) }
          end

          def test_deserialize_custom_bad_obj
            input = <<XML
<?xml version="1.0"?>
<root xmlns="DAV:">
  <foo>blabla</foo>
</root>
XML

            expected = {}

            element_map = { '{DAV:}foo' => Class.new }

            assert_raises(RuntimeError) { assert_decode_prop(input, expected, element_map) }
          end
        end
      end
    end
  end
end
