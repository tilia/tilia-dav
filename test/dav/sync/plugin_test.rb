require 'yaml'

module Tilia
  module Dav
    module Sync
      class PluginTest < DavServerTest
        def setup
          super
          @server.add_plugin(Plugin.new)
        end

        def test_get_info
          assert_has_key('name', Plugin.new.plugin_info)
        end

        def set_up_tree
          @collection = MockSyncCollection.new(
            'coll',
            [
              SimpleFile.new('file1.txt', 'foo'),
              SimpleFile.new('file2.txt', 'bar')
            ]
          )
          @tree = [
            @collection,
            SimpleCollection.new('normalcoll', [])
          ]
        end

        def test_supported_report_set
          result = @server.properties('/coll', ['{DAV:}supported-report-set'])
          refute(result['{DAV:}supported-report-set'].has('{DAV:}sync-collection'))

          # Making a change
          @collection.add_change(['file1.txt'], [], [])

          result = @server.properties('/coll', ['{DAV:}supported-report-set'])
          assert(result['{DAV:}supported-report-set'].has('{DAV:}sync-collection'))
        end

        def test_get_sync_token
          result = @server.properties('/coll', ['{DAV:}sync-token'])
          refute(result.key?('{DAV:}sync-token'))

          # Making a change
          @collection.add_change(['file1.txt'], [], [])

          result = @server.properties('/coll', ['{DAV:}sync-token'])
          assert_has_key('{DAV:}sync-token', result)

          # non-sync-enabled collection
          @collection.add_change(['file1.txt'], [], [])

          result = @server.properties('/normalcoll', ['{DAV:}sync-token'])
          refute(result.key?('{DAV:}sync-token'))
        end

        def test_sync_initial_sync_collection
          # Making a change
          @collection.add_change(['file1.txt'], [], [])

          request = Http::Request.new('REPORT', '/coll/', 'Content-Type' => 'application/xml')

          body = <<BLA
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
<D:sync-token/>
<D:sync-level>1</D:sync-level>
<D:prop>
  <D:getcontentlength/>
</D:prop>
</D:sync-collection>
BLA

          request.body = body

          response = request(request)

          assert_equal(207, response.status, "Full response body: #{response.body_as_string}")

          multi_status = @server.xml.parse(response.body_as_string)

          # Checking the sync-token
          assert_equal(
            'http://sabre.io/ns/sync/1',
            multi_status.sync_token
          )

          responses = multi_status.responses
          assert_equal(2, responses.size, 'We expected exactly 2 {DAV:}response')

          response = responses[0]

          assert_nil(response.http_status)
          assert_equal('/coll/file1.txt', response.href)
          assert_equal(
            {
              '200' => {
                '{DAV:}getcontentlength' => '3'
              }
            },
            response.response_properties
          )

          response = responses[1]

          assert_nil(response.http_status)
          assert_equal('/coll/file2.txt', response.href)
          assert_equal(
            {
              '200' => {
                '{DAV:}getcontentlength' => '3'
              }
            },
            response.response_properties
          )
        end

        def test_subsequent_sync_sync_collection
          # Making a change
          @collection.add_change(['file1.txt'], [], [])
          # Making another change
          @collection.add_change([], ['file2.txt'], ['file3.txt'])

          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'REPORT',
            'REQUEST_PATH'   => '/coll/',
            'CONTENT_TYPE'    => 'application/xml'
          )

          body = <<BLA
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
  <D:sync-token>http://sabre.io/ns/sync/1</D:sync-token>
  <D:sync-level>infinite</D:sync-level>
  <D:prop>
    <D:getcontentlength/>
  </D:prop>
</D:sync-collection>
BLA

          request.body = body

          response = request(request)

          assert_equal(207, response.status, "Full response body: #{response.body}")

          multi_status = @server.xml.parse(response.body_as_string)

          # Checking the sync-token
          assert_equal(
            'http://sabre.io/ns/sync/2',
            multi_status.sync_token
          )

          responses = multi_status.responses
          assert_equal(2, responses.size, 'We expected exactly 2 {DAV:}response')

          response = responses[0]

          assert_nil(response.http_status)
          assert_equal('/coll/file2.txt', response.href)
          assert_equal(
            {
              '200' => {
                '{DAV:}getcontentlength' => '3'
              }
            },
            response.response_properties
          )

          response = responses[1]

          assert_equal('404', response.http_status)
          assert_equal('/coll/file3.txt', response.href)
          assert_equal({}, response.response_properties)
        end

        def test_subsequent_sync_sync_collection_limit
          # Making a change
          @collection.add_change(['file1.txt'], [], [])
          # Making another change
          @collection.add_change([], ['file2.txt'], ['file3.txt'])

          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'REPORT',
            'REQUEST_PATH'   => '/coll/',
            'CONTENT_TYPE'    => 'application/xml'
          )

          body = <<BLA
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
  <D:sync-token>http://sabre.io/ns/sync/1</D:sync-token>
  <D:sync-level>infinite</D:sync-level>
  <D:prop>
    <D:getcontentlength/>
  </D:prop>
  <D:limit><D:nresults>1</D:nresults></D:limit>
</D:sync-collection>
BLA

          request.body = body

          response = request(request)

          assert_equal(207, response.status, "Full response body: #{response.body}")

          multi_status = @server.xml.parse(response.body_as_string)

          # Checking the sync-token
          assert_equal(
            'http://sabre.io/ns/sync/2',
            multi_status.sync_token
          )

          responses = multi_status.responses
          assert_equal(1, responses.size, 'We expected exactly 1 {DAV:}response')

          response = responses[0]

          assert_equal('404', response.http_status)
          assert_equal('/coll/file3.txt', response.href)
          assert_equal({}, response.response_properties)
        end

        def test_subsequent_sync_sync_collection_depth_fall_back
          # Making a change
          @collection.add_change(['file1.txt'], [], [])
          # Making another change
          @collection.add_change([], ['file2.txt'], ['file3.txt'])

          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'REPORT',
            'REQUEST_PATH'   => '/coll/',
            'CONTENT_TYPE'   => 'application/xml',
            'HTTP_DEPTH'     => '1'
          )

          body = <<BLA
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
  <D:sync-token>http://sabre.io/ns/sync/1</D:sync-token>
  <D:prop>
    <D:getcontentlength/>
  </D:prop>
</D:sync-collection>
BLA

          request.body = body

          response = request(request)

          assert_equal(207, response.status, "Full response body: #{response.body}")

          multi_status = @server.xml.parse(response.body_as_string)

          # Checking the sync-token
          assert_equal(
            'http://sabre.io/ns/sync/2',
            multi_status.sync_token
          )

          responses = multi_status.responses
          assert_equal(2, responses.size, 'We expected exactly 2 {DAV:}response')

          response = responses[0]

          assert_nil(response.http_status)
          assert_equal('/coll/file2.txt', response.href)
          assert_equal(
            {
              '200' => {
                '{DAV:}getcontentlength' => '3'
              }
            },
            response.response_properties
          )
          response = responses[1]

          assert_equal('404', response.http_status)
          assert_equal('/coll/file3.txt', response.href)
          assert_equal({}, response.response_properties)
        end

        def test_sync_no_sync_info
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'REPORT',
            'REQUEST_PATH'   => '/coll/',
            'CONTENT_TYPE'    => 'application/xml'
          )

          body = <<BLA
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
  <D:sync-token/>
  <D:sync-level>1</D:sync-level>
  <D:prop>
    <D:getcontentlength/>
  </D:prop>
</D:sync-collection>
BLA

          request.body = body

          response = request(request)

          # The default state has no sync-token, so this report should not yet
          # be supported.
          assert_equal(415, response.status, "Full response body: #{response.body}")
        end

        def test_sync_no_sync_collection
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'REPORT',
            'REQUEST_PATH'   => '/normalcoll/',
            'CONTENT_TYPE'    => 'application/xml'
          )

          body = <<BLA
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
  <D:sync-token/>
  <D:sync-level>1</D:sync-level>
  <D:prop>
    <D:getcontentlength/>
  </D:prop>
</D:sync-collection>
BLA

          request.body = body

          response = request(request)

          # The default state has no sync-token, so this report should not yet
          # be supported.
          assert_equal(415, response.status, "Full response body: #{response.body}")
        end

        def test_sync_invalid_token
          @collection.add_change(['file1.txt'], [], [])
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'REPORT',
            'REQUEST_PATH'   => '/coll/',
            'CONTENT_TYPE'    => 'application/xml'
          )

          body = <<BLA
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
  <D:sync-token>http://sabre.io/ns/sync/invalid</D:sync-token>
  <D:sync-level>1</D:sync-level>
  <D:prop>
    <D:getcontentlength/>
  </D:prop>
</D:sync-collection>
BLA

          request.body = body

          response = request(request)

          # The default state has no sync-token, so this report should not yet
          # be supported.
          assert_equal(403, response.status, "Full response body: #{response.body}")
        end

        def test_sync_invalid_token_no_prefix
          @collection.add_change(['file1.txt'], [], [])
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'REPORT',
            'REQUEST_PATH'   => '/coll/',
            'CONTENT_TYPE'    => 'application/xml'
          )

          body = <<BLA
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
  <D:sync-token>invalid</D:sync-token>
  <D:sync-level>1</D:sync-level>
  <D:prop>
    <D:getcontentlength/>
  </D:prop>
</D:sync-collection>
BLA

          request.body = body

          response = request(request)

          # The default state has no sync-token, so this report should not yet
          # be supported.
          assert_equal(403, response.status, "Full response body: #{response.body}")
        end

        def test_sync_no_sync_token
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'REPORT',
            'REQUEST_PATH'   => '/coll/',
            'CONTENT_TYPE'    => 'application/xml'
          )

          body = <<BLA
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
  <D:sync-level>1</D:sync-level>
  <D:prop>
    <D:getcontentlength/>
  </D:prop>
</D:sync-collection>
BLA

          request.body = body

          response = request(request)

          # The default state has no sync-token, so this report should not yet
          # be supported.
          assert_equal(400, response.status, "Full response body: #{response.body}")
        end

        def test_sync_no_prop
          @collection.add_change(['file1.txt'], [], [])
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'REPORT',
            'REQUEST_PATH'   => '/coll/',
            'CONTENT_TYPE'   => 'application/xml'
          )

          body = <<BLA
<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:">
  <D:sync-token />
  <D:sync-level>1</D:sync-level>
</D:sync-collection>
BLA

          request.body = body

          response = request(request)

          # The default state has no sync-token, so this report should not yet
          # be supported.
          assert_equal(400, response.status, "Full response body: #{response.body}")
        end

        def test_if_conditions
          @collection.add_change(['file1.txt'], [], [])
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'DELETE',
            'REQUEST_PATH'   => '/coll/file1.txt',
            'HTTP_IF'        => '</coll> (<http://sabre.io/ns/sync/1>)'
          )
          response = request(request)

          # If a 403 is thrown this works correctly. The file in questions
          # doesn't allow itself to be deleted.
          # If the If conditions failed, it would have been a 412 instead.
          assert_equal(403, response.status)
        end

        def test_if_conditions_not
          @collection.add_change(['file1.txt'], [], [])
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'DELETE',
            'REQUEST_PATH'   => '/coll/file1.txt',
            'HTTP_IF'        => '</coll> (Not <http://sabre.io/ns/sync/2>)'
          )
          response = request(request)

          # If a 403 is thrown this works correctly. The file in questions
          # doesn't allow itself to be deleted.
          # If the If conditions failed, it would have been a 412 instead.
          assert_equal(403, response.status)
        end

        def test_if_conditions_no_sync_token
          @collection.add_change(['file1.txt'], [], [])
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'DELETE',
            'REQUEST_PATH'   => '/coll/file1.txt',
            'HTTP_IF'        => '</coll> (<opaquelocktoken:foo>)'
          )
          response = request(request)

          assert_equal(412, response.status)
        end
      end
    end
  end
end
