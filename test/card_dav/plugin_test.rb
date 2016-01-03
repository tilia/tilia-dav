require 'test_helper'

module Tilia
  module CardDav
    class PluginTest < AbstractPluginTest
      def test_construct
        assert_equal("{#{Plugin::NS_CARDDAV}}addressbook", @server.resource_type_mapping[IAddressBook])

        assert(@plugin.features.include?('addressbook'))
        assert_equal('carddav', @plugin.plugin_info['name'])
      end

      def test_supported_report_set
        assert_equal(
          [
            "{#{Plugin::NS_CARDDAV}}addressbook-multiget",
            "{#{Plugin::NS_CARDDAV}}addressbook-query"
          ],
          @plugin.supported_report_set('addressbooks/user1/book1')
        )
      end

      def test_supported_report_set_empty
        assert_equal([], @plugin.supported_report_set(''))
      end

      def test_address_book_home_set
        result = @server.properties('principals/user1', ["{#{Plugin::NS_CARDDAV}}addressbook-home-set"])

        assert_equal(1, result.size)
        assert_has_key("{#{Plugin::NS_CARDDAV}}addressbook-home-set", result)
        assert_equal('addressbooks/user1/', result["{#{Plugin::NS_CARDDAV}}addressbook-home-set"].href)
      end

      def test_directory_gateway
        result = @server.properties('principals/user1', ["{#{Plugin::NS_CARDDAV}}directory-gateway"])

        assert_equal(1, result.size)
        assert_has_key("{#{Plugin::NS_CARDDAV}}directory-gateway", result)
        assert_equal(['directory'], result["{#{Plugin::NS_CARDDAV}}directory-gateway"].hrefs)
      end

      def test_report_pass_through
        assert(@plugin.report('{DAV:}foo', LibXML::XML::Document.new, ''))
      end

      def test_html_actions_panel
        output = Box.new('')
        r = @server.emit('onHTMLActionsPanel', [@server.tree.node_for_path('addressbooks/user1'), output])
        refute(r)

        assert(output.value.index('Display name'))
      end

      def test_addressbook_plugin_properties
        ns = "{#{Plugin::NS_CARDDAV}}"
        prop_find = Dav::PropFind.new(
          'addressbooks/user1/book1',
          [
            "#{ns}supported-address-data",
            "#{ns}supported-collation-set"
          ]
        )
        node = @server.tree.node_for_path('addressbooks/user1/book1')
        @plugin.prop_find_early(prop_find, node)

        assert_kind_of(
          Xml::Property::SupportedAddressData,
          prop_find.get("#{ns}supported-address-data")
        )
        assert_kind_of(
          Xml::Property::SupportedCollationSet,
          prop_find.get("#{ns}supported-collation-set")
        )
      end

      def test_get_transform
        request = Http::Request.new('GET', '/addressbooks/user1/book1/card1', ['Accept: application/vcard+json'])
        response = Http::ResponseMock.new

        @server.invoke_method(request, response)

        assert_equal(200, response.status)
      end
    end
  end
end
