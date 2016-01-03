module Tilia
  module Dav
    module Xml
      class XmlTester < Minitest::Test
        attr_accessor :element_map
        attr_accessor :namespace_map
        attr_accessor :context_uri

        def setup
          super
          @element_map = {}
          @namespace_map = { 'DAV:' => 'd' }
          @context_uri = '/'
        end

        def write(input)
          writer = Tilia::Xml::Writer.new
          writer.context_uri = context_uri
          writer.namespace_map = namespace_map
          writer.open_memory
          writer.set_indent(true)
          writer.write(input)
          writer.output_memory
        end

        def parse(xml, element_map = {})
          reader = Tilia::Xml::Reader.new
          reader.element_map = self.element_map.merge(element_map)
          reader.xml(xml)
          reader.parse
        end
      end
    end
  end
end
