require 'test_helper'

module Tilia
  module Dav
    module Xml
      module Request
        class SyncCollectionTest < XmlTester
          def test_deserialize_prop
            xml = <<XML
<?xml version="1.0"?>
<d:sync-collection xmlns:d="DAV:">
  <d:sync-token />
  <d:sync-level>1</d:sync-level>
  <d:prop>
    <d:foo />
  </d:prop>
</d:sync-collection>
XML

            result = parse(xml, '{DAV:}sync-collection' => Tilia::Dav::Xml::Request::SyncCollectionReport)

            elem = Tilia::Dav::Xml::Request::SyncCollectionReport.new
            elem.sync_level = 1
            elem.properties = ['{DAV:}foo']
            elem.sync_token = nil

            assert_instance_equal(elem, result['value'])
          end

          def test_deserialize_limit
            xml = <<XML
<?xml version="1.0"?>
<d:sync-collection xmlns:d="DAV:">
  <d:sync-token />
  <d:sync-level>1</d:sync-level>
  <d:prop>
    <d:foo />
  </d:prop>
  <d:limit><d:nresults>5</d:nresults></d:limit>
</d:sync-collection>
XML

            result = parse(xml, '{DAV:}sync-collection' => Tilia::Dav::Xml::Request::SyncCollectionReport)

            elem = Tilia::Dav::Xml::Request::SyncCollectionReport.new
            elem.sync_level = 1
            elem.properties = ['{DAV:}foo']
            elem.sync_token = nil
            elem.limit = 5

            assert_instance_equal(elem, result['value'])
          end

          def test_deserialize_infinity
            xml = <<XML
<?xml version="1.0"?>
<d:sync-collection xmlns:d="DAV:">
  <d:sync-token />
  <d:sync-level>infinity</d:sync-level>
  <d:prop>
    <d:foo />
  </d:prop>
</d:sync-collection>
XML

            result = parse(xml, '{DAV:}sync-collection' => Tilia::Dav::Xml::Request::SyncCollectionReport)

            elem = Tilia::Dav::Xml::Request::SyncCollectionReport.new
            elem.sync_level = Tilia::Dav::Server::DEPTH_INFINITY
            elem.sync_token = nil
            elem.properties = ['{DAV:}foo']

            assert_instance_equal(elem, result['value'])
          end

          def test_deserialize_missing_elem
            xml = <<XML
<?xml version="1.0"?>
<d:sync-collection xmlns:d="DAV:">
  <d:sync-token />
</d:sync-collection>
XML
            assert_raises(Tilia::Dav::Exception::BadRequest) { parse(xml, '{DAV:}sync-collection' => Tilia::Dav::Xml::Request::SyncCollectionReport) }
          end
        end
      end
    end
  end
end
