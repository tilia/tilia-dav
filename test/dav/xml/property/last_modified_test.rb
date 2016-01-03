require 'test_helper'

module Tilia
  module Dav
    module Xml
      module Property
        class LastModifiedTest < XmlTester
          def test_serialize_date_time
            tz = ActiveSupport::TimeZone.new('America/Vancouver')
            dt = tz.parse('2015-03-24 11:47:00')
            val = { '{DAV:}getlastmodified' =>  Tilia::Dav::Xml::Property::GetLastModified.new(dt) }

            result = write(val)
            expected = <<XML
<?xml version="1.0"?>
<d:getlastmodified xmlns:d="DAV:">Tue, 24 Mar 2015 18:47:00 GMT</d:getlastmodified>
XML

            assert_xml_equal(expected, result)
          end

          def test_serialize_time_stamp
            tz = ActiveSupport::TimeZone.new('America/Vancouver')
            dt = tz.parse('2015-03-24 11:47:00')
            val = { '{DAV:}getlastmodified' =>  Tilia::Dav::Xml::Property::GetLastModified.new(dt.to_i) }

            result = write(val)
            expected = <<XML
<?xml version="1.0"?>
<d:getlastmodified xmlns:d="DAV:">Tue, 24 Mar 2015 18:47:00 GMT</d:getlastmodified>
XML

            assert_xml_equal(expected, result)
          end

          def test_deserialize
            input = <<XML
<?xml version="1.0"?>
<d:getlastmodified xmlns:d="DAV:">Tue, 24 Mar 2015 18:47:00 GMT</d:getlastmodified>
XML

            element_map = { '{DAV:}getlastmodified' => Tilia::Dav::Xml::Property::GetLastModified }
            result = parse(input, element_map)

            tz = ActiveSupport::TimeZone.new('UTC')
            assert_equal(tz.parse('2015-03-24 18:47:00'), result['value'].time)
          end
        end
      end
    end
  end
end
