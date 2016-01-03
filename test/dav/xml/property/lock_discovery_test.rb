require 'test_helper'

module Tilia
  module Dav
    module Xml
      module Property
        class LockDiscoveryTest < XmlTester
          def test_serialize
            lock = Tilia::Dav::Locks::LockInfo.new
            lock.owner = 'hello'
            lock.token = 'blabla'
            lock.timeout = 600
            lock.created = Time.zone.parse('2015-03-25 19:21:00')
            lock.scope = Tilia::Dav::Locks::LockInfo::EXCLUSIVE
            lock.depth = 0
            lock.uri = 'hi'

            prop = Tilia::Dav::Xml::Property::LockDiscovery.new([lock])

            xml = write('{DAV:}root' => prop)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:activelock>
  <d:lockscope><d:exclusive /></d:lockscope>
  <d:locktype><d:write /></d:locktype>
  <d:lockroot>
    <d:href>/hi</d:href>
  </d:lockroot>
  <d:depth>0</d:depth>
  <d:timeout>Second-600</d:timeout>
  <d:locktoken>
    <d:href>opaquelocktoken:blabla</d:href>
  </d:locktoken>
  <d:owner>hello</d:owner>
</d:activelock>
</d:root>
XML
            assert_xml_equal(expected, xml)
          end

          def test_serialize_shared
            lock = Tilia::Dav::Locks::LockInfo.new
            lock.owner = 'hello'
            lock.token = 'blabla'
            lock.timeout = 600
            lock.created = Time.zone.parse('2015-03-25 19:21:00')
            lock.scope = Tilia::Dav::Locks::LockInfo::SHARED
            lock.depth = 0
            lock.uri = 'hi'

            prop = Tilia::Dav::Xml::Property::LockDiscovery.new([lock])

            xml = write('{DAV:}root' => prop)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:activelock>
  <d:lockscope><d:shared /></d:lockscope>
  <d:locktype><d:write /></d:locktype>
  <d:lockroot>
    <d:href>/hi</d:href>
  </d:lockroot>
  <d:depth>0</d:depth>
  <d:timeout>Second-600</d:timeout>
  <d:locktoken>
    <d:href>opaquelocktoken:blabla</d:href>
  </d:locktoken>
  <d:owner>hello</d:owner>
</d:activelock>
</d:root>
XML
            assert_xml_equal(expected, xml)
          end
        end
      end
    end
  end
end
