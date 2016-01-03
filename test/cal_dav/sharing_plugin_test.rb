require 'test_helper'

module Tilia
  module CalDav
    class SharingPluginTest < DavServerTest
      def setup
        @setup_cal_dav = true
        @setup_cal_dav_sharing = true
        @setup_acl = true
        @auto_login = 'user1'

        @caldav_calendars = [
          {
            'principaluri' => 'principals/user1',
            'id' => 1,
            'uri' => 'cal1'
          },
          {
            'principaluri' => 'principals/user1',
            'id' => 2,
            'uri' => 'cal2',
            "{#{Plugin::NS_CALENDARSERVER}}shared-url" => 'calendars/user1/cal2',
            '{http://sabredav.org/ns}owner-principal' => 'principals/user2',
            '{http://sabredav.org/ns}read-only' => 'true'
          },
          {
            'principaluri' => 'principals/user1',
            'id' => 3,
            'uri' => 'cal3'
          }
        ]

        super

        # Making the logged in user an admin, for full access:
        @acl_plugin.admin_principals << 'principals/user1'
        @acl_plugin.admin_principals << 'principals/user2'
      end

      def test_simple
        assert_kind_of(SharingPlugin, @server.plugin('caldav-sharing'))
        assert_equal(
          'caldav-sharing',
          @caldav_sharing_plugin.plugin_info['name']
        )
      end

      def test_get_features
        assert_equal(
          ['calendarserver-sharing'],
          @caldav_sharing_plugin.features
        )
      end

      def test_before_get_shareable_calendar
        # Forcing the server to authenticate:
        @auth_plugin.before_method(Http::Request.new, Http::Response.new)
        props = @server.properties(
          'calendars/user1/cal1',
          [
            "{#{Plugin::NS_CALENDARSERVER}}invite",
            "{#{Plugin::NS_CALENDARSERVER}}allowed-sharing-modes"
          ]
        )

        assert_kind_of(Xml::Property::Invite, props["{#{Plugin::NS_CALENDARSERVER}}invite"])
        assert_kind_of(Xml::Property::AllowedSharingModes, props["{#{Plugin::NS_CALENDARSERVER}}allowed-sharing-modes"])
      end

      def test_before_get_shared_calendar
        props = @server.properties(
          'calendars/user1/cal2',
          [
            "{#{Plugin::NS_CALENDARSERVER}}shared-url",
            "{#{Plugin::NS_CALENDARSERVER}}invite"
          ]
        )

        assert_kind_of(Xml::Property::Invite, props["{#{Plugin::NS_CALENDARSERVER}}invite"])
        assert_kind_of(Dav::Xml::Property::Href, props["{#{Plugin::NS_CALENDARSERVER}}shared-url"])
      end

      def test_update_properties
        @caldav_backend.update_shares(
          1,
          [ # 1 Hash in Array
            'href' => 'mailto:joe@example.org'
          ],
          []
        )
        result = @server.update_properties(
          'calendars/user1/cal1',
          '{DAV:}resourcetype' => Dav::Xml::Property::ResourceType.new(['{DAV:}collection'])
        )

        assert_equal(
          { '{DAV:}resourcetype' => 200 },
          result
        )

        assert_equal(0, @caldav_backend.shares(1).size)
      end

      def test_update_properties_pass_thru
        result = @server.update_properties(
          'calendars/user1/cal3',
          '{DAV:}foo' => 'bar'
        )

        assert_equal(
          { '{DAV:}foo' => 403 },
          result
        )
      end

      def test_unknown_method_no_post
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PATCH',
          'REQUEST_PATH'   => '/'
        )

        response = request(request)

        assert_equal(501, response.status, response.body)
      end

      def test_unknown_method_no_xml
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/',
          'CONTENT_TYPE'   => 'text/plain'
        )

        response = request(request)

        assert_equal(501, response.status, response.body)
      end

      def test_unknown_method_no_node
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/foo',
          'CONTENT_TYPE'   => 'text/xml'
        )

        response = request(request)

        assert_equal(501, response.status, response.body)
      end

      def test_share_request
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/calendars/user1/cal1',
          'CONTENT_TYPE'   => 'text/xml'
        )

        xml = <<RRR
<?xml version="1.0"?>
<cs:share xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:">
    <cs:set>
        <d:href>mailto:joe@example.org</d:href>
        <cs:common-name>Joe Shmoe</cs:common-name>
        <cs:read-write />
    </cs:set>
    <cs:remove>
        <d:href>mailto:nancy@example.org</d:href>
    </cs:remove>
</cs:share>
RRR

        request.body = xml

        response = request(request)
        assert_equal(200, response.status, response.body)

        assert_equal(
          [ # Hash in Array
            'href' => 'mailto:joe@example.org',
            'commonName' => 'Joe Shmoe',
            'readOnly' => false,
            'status' => SharingPlugin::STATUS_NORESPONSE,
            'summary' => nil
          ],
          @caldav_backend.shares(1)
        )

        # Verifying that the calendar is now marked shared.
        props = @server.properties('calendars/user1/cal1', ['{DAV:}resourcetype'])
        assert(
          props['{DAV:}resourcetype'].is('{http://calendarserver.org/ns/}shared-owner')
        )
      end

      def test_share_request_no_shareable_calendar
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/calendars/user1/cal2',
          'CONTENT_TYPE'   => 'text/xml'
        )

        xml = <<XML
<?xml version="1.0"?>
<cs:share xmlns:cs="#{Plugin::NS_CALENDARSERVER}" xmlns:d="DAV:">
    <cs:set>
        <d:href>mailto:joe@example.org</d:href>
        <cs:common-name>Joe Shmoe</cs:common-name>
        <cs:read-write />
    </cs:set>
    <cs:remove>
        <d:href>mailto:nancy@example.org</d:href>
    </cs:remove>
</cs:share>
XML

        request.body = xml

        response = request(request)
        assert_equal(501, response.status, response.body)
      end

      def test_invite_reply
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/calendars/user1',
          'CONTENT_TYPE'   => 'text/xml'
        )

        xml = <<XML
<?xml version="1.0"?>
<cs:invite-reply xmlns:cs="#{Plugin::NS_CALENDARSERVER}" xmlns:d="DAV:">
    <cs:hosturl><d:href>/principals/owner</d:href></cs:hosturl>
    <cs:invite-accepted />
</cs:invite-reply>
XML

        request.body = xml
        response = request(request)
        assert_equal(200, response.status, response.body)
      end

      def test_invite_bad_xml
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/calendars/user1',
          'CONTENT_TYPE'   => 'text/xml'
        )

        xml = <<XML
<?xml version="1.0"?>
<cs:invite-reply xmlns:cs="#{Plugin::NS_CALENDARSERVER}" xmlns:d="DAV:">
</cs:invite-reply>
XML
        request.body = xml
        response = request(request)
        assert_equal(400, response.status, response.body)
      end

      def test_invite_wrong_url
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/calendars/user1/cal1',
          'CONTENT_TYPE'   => 'text/xml'
        )

        xml = <<XML
<?xml version="1.0"?>
<cs:invite-reply xmlns:cs="#{Plugin::NS_CALENDARSERVER}" xmlns:d="DAV:">
    <cs:hosturl><d:href>/principals/owner</d:href></cs:hosturl>
</cs:invite-reply>
XML

        request.body = xml
        response = request(request)
        assert_equal(501, response.status, response.body)

        # If the plugin did not handle this request, it must ensure that the
        # body is still accessible by other plugins.
        assert_equal(xml, request.body)
      end

      def test_publish
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/calendars/user1/cal1',
          'CONTENT_TYPE'   => 'text/xml'
        )

        xml = <<XML
<?xml version="1.0"?>
<cs:publish-calendar xmlns:cs="#{Plugin::NS_CALENDARSERVER}" xmlns:d="DAV:" />
XML

        request.body = xml

        response = request(request)
        assert_equal(202, response.status, response.body)
      end

      def test_unpublish
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/calendars/user1/cal1',
          'CONTENT_TYPE'   => 'text/xml'
        )

        xml = <<XML
<?xml version="1.0"?>
<cs:unpublish-calendar xmlns:cs="#{Plugin::NS_CALENDARSERVER}" xmlns:d="DAV:" />
XML

        request.body = xml

        response = request(request)
        assert_equal(200, response.status, response.body)
      end

      def test_publish_wrong_url
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/calendars/user1/cal2',
          'CONTENT_TYPE'   => 'text/xml'
        )

        xml = <<XML
<?xml version="1.0"?>
<cs:publish-calendar xmlns:cs="#{Plugin::NS_CALENDARSERVER}" xmlns:d="DAV:" />
XML

        request.body = xml

        response = request(request)
        assert_equal(501, response.status, response.body)
      end

      def test_unpublish_wrong_url
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/calendars/user1/cal2',
          'CONTENT_TYPE'   => 'text/xml'
        )

        xml = <<XML
<?xml version="1.0"?>
<cs:unpublish-calendar xmlns:cs="#{Plugin::NS_CALENDARSERVER}" xmlns:d="DAV:" />
XML

        request.body = xml

        response = request(request)
        assert_equal(501, response.status, response.body)
      end

      def test_unknown_xml_doc
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH'   => '/calendars/user1/cal2',
          'CONTENT_TYPE'   => 'text/xml'
        )

        xml = <<XML
<?xml version="1.0"?>
<cs:foo-bar xmlns:cs="#{Plugin::NS_CALENDARSERVER}" xmlns:d="DAV:" />
XML

        request.body = xml

        response = request(request)
        assert_equal(501, response.status, response.body)
      end
    end
  end
end
