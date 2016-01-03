module Tilia
  module Dav
    module Xml
      module Property
        # supported-report-set property.
        #
        # This property is defined in RFC3253, but since it's
        # so common in other webdav-related specs, it is part of the core server.
        #
        # This property is defined here:
        # http://tools.ietf.org/html/rfc3253#section-3.1.5
        class SupportedReportSet
          include Tilia::Xml::XmlSerializable
          include Browser::HtmlOutput

          # List of reports
          #
          # @var array
          # RUBY: attr_accessor :reports

          # Creates the property
          #
          # Any reports passed in the constructor
          # should be valid report-types in clark-notation.
          #
          # Either a string or an array of strings must be passed.
          #
          # @param string|string[] reports
          def initialize(reports = nil)
            @reports = []

            add_report(reports) if reports
          end

          # Adds a report to this property
          #
          # The report must be a string in clark-notation.
          # Multiple reports can be specified as an array.
          #
          # @param mixed report
          # @return void
          def add_report(report)
            report = [report] unless report.is_a?(Array)

            report.each do |r|
              unless r =~ /^{([^}]*)}(.*)$/
                fail Dav::Exception, 'Reportname must be in clark-notation'
              end

              @reports << r
            end
          end

          # Returns the list of supported reports
          #
          # @return string[]
          def value
            @reports
          end

          # Returns true or false if the property contains a specific report.
          #
          # @param string report_name
          # @return bool
          def has(report_name)
            @reports.include?(report_name)
          end

          # The xmlSerialize metod is called during xml writing.
          #
          # Use the writer argument to write its own xml serialization.
          #
          # An important note: do _not_ create a parent element. Any element
          # implementing XmlSerializble should only ever write what's considered
          # its 'inner xml'.
          #
          # The parent of the current element is responsible for writing a
          # containing element.
          #
          # This allows serializers to be re-used for different element names.
          #
          # If you are opening new elements, you must also close them again.
          #
          # @param Writer writer
          # @return void
          def xml_serialize(writer)
            value.each do |val|
              writer.start_element('{DAV:}supported-report')
              writer.start_element('{DAV:}report')
              writer.write_element(val)
              writer.end_element
              writer.end_element
            end
          end

          # Generate html representation for this value.
          #
          # The html output is 100% trusted, and no effort is being made to sanitize
          # it. It's up to the implementor to sanitize user provided values.
          #
          # The output must be in UTF-8.
          #
          # The baseUri parameter is a url to the root of the application, and can
          # be used to construct local links.
          #
          # @param HtmlOutputHelper html
          # @return string
          def to_html(html)
            tmp = value.map do |value|
              html.xml_name(value)
            end
            tmp.join(', ')
          end
        end
      end
    end
  end
end
