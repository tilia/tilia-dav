require 'test_helper'

module Tilia
  module CalDav
    class ShareableCalendarTest < Minitest::Test
      def setup
        props = {
          'id' => 1
        }

        @backend = Backend::MockSharing.new(
          [props]
        )
        @backend.update_shares(
          1,
          [
            {
              'href' => 'mailto:removeme@example.org',
              'commonName' => 'To be removed',
              'readOnly' => true
            }
          ],
          []
        )

        @instance = ShareableCalendar.new(@backend, props)
      end

      def test_update_shares
        @instance.update_shares(
          [ # 1 Hash in Array
            'href' => 'mailto:test@example.org',
            'commonName' => 'Foo Bar',
            'summary' => 'Booh',
            'readOnly' => false
          ],
          ['mailto:removeme@example.org']
        )

        assert_equal(
          [ # 1 Hash in Array
            'href' => 'mailto:test@example.org',
            'commonName' => 'Foo Bar',
            'summary' => 'Booh',
            'readOnly' => false,
            'status' => SharingPlugin::STATUS_NORESPONSE
          ],
          @instance.shares
        )
      end

      def test_publish
        assert(@instance.publish_status = true)
        refute(@instance.publish_status = false)
      end
    end
  end
end
