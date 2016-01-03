require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Request
        class ShareTest < Dav::Xml::XmlTester
          def setup
            super
            @element_map['{http://calendarserver.org/ns/}share'] = Share
          end

          def test_deserialize
            xml = <<XML
<?xml version="1.0" encoding="utf-8" ?>
   <CS:share xmlns:D="DAV:"
                 xmlns:CS="http://calendarserver.org/ns/">
     <CS:set>
       <D:href>mailto:eric@example.com</D:href>
       <CS:common-name>Eric York</CS:common-name>
       <CS:summary>Shared workspace</CS:summary>
       <CS:read-write />
     </CS:set>
     <CS:remove>
       <D:href>mailto:foo@bar</D:href>
     </CS:remove>
   </CS:share>
XML

            result = parse(xml)
            share = Share.new(
              [
                {
                  'href'       => 'mailto:eric@example.com',
                  'commonName' => 'Eric York',
                  'summary'    => 'Shared workspace',
                  'readOnly'   => false
                }
              ],
              [
                'mailto:foo@bar'
              ]
            )

            assert_instance_equal(share, result['value'])
          end

          def test_deserialize_mininal
            xml = <<XML
<?xml version="1.0" encoding="utf-8" ?>
   <CS:share xmlns:D="DAV:"
                 xmlns:CS="http://calendarserver.org/ns/">
     <CS:set>
       <D:href>mailto:eric@example.com</D:href>
        <CS:read />
     </CS:set>
   </CS:share>
XML

            result = parse(xml)
            share = Share.new(
              [
                {
                  'href'       => 'mailto:eric@example.com',
                  'commonName' => nil,
                  'summary'    => nil,
                  'readOnly'   => true
                }
              ],
              []
            )

            assert_instance_equal(share, result['value'])
          end
        end
      end
    end
  end
end
