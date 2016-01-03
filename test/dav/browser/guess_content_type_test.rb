require 'test_helper'

module Tilia
  module Dav
    module Browser
      class GuessContentTypeTest < AbstractServer
        def setup
          super
          ::File.open("#{temp_dir}/somefile.jpg", 'w') { |f| f.write 'blabla' }
          ::File.open("#{temp_dir}/somefile.hoi", 'w') { |f| f.write 'blabla' }
        end

        def test_get_properties
          properties = ['{DAV:}getcontenttype']

          result = @server.properties_for_path('/somefile.jpg', properties)
          assert(result[0])
          assert_has_key(404, result[0])
          assert_has_key('{DAV:}getcontenttype', result[0][404])
        end

        def test_get_properties_plugin_enabled
          @server.add_plugin(GuessContentType.new)
          properties = ['{DAV:}getcontenttype']
          result = @server.properties_for_path('/somefile.jpg', properties)
          assert(result[0])
          assert_has_key(200, result[0], "We received: #{result.inspect}")
          assert_has_key('{DAV:}getcontenttype', result[0][200])
          assert_equal('image/jpeg', result[0][200]['{DAV:}getcontenttype'])
        end

        def test_get_properties_unknown
          @server.add_plugin(GuessContentType.new)
          properties = ['{DAV:}getcontenttype']
          result = @server.properties_for_path('/somefile.hoi', properties)
          assert(result[0])
          assert_has_key(200, result[0])
          assert_has_key('{DAV:}getcontenttype', result[0][200])
          assert_equal('application/octet-stream', result[0][200]['{DAV:}getcontenttype'])
        end
      end
    end
  end
end
