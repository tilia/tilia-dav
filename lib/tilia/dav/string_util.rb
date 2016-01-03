module Tilia
  module Dav
    # String utility
    #
    # This class is mainly used to implement the 'text-match' filter, used by both
    # the CalDAV calendar-query REPORT, and CardDAV addressbook-query REPORT.
    # Because they both need it, it was decided to put it in Sabre\DAV instead.
    class StringUtil
      # Checks if a needle occurs in a haystack ;)
      #
      # @param string haystack
      # @param string needle
      # @param string collation
      # @param string match_type
      # @return bool
      def self.text_match(haystack, needle, collation, match_type = 'contains')
        case collation
        when 'i;ascii-casemap'
          # NOTE: following is not true for RUBY
          # default strtolower takes locale into consideration
          # we don't want this.
          haystack = haystack.upcase
          needle = needle.upcase
        when 'i;octet'
          # Do nothing
        when 'i;unicode-casemap'
          haystack = haystack.mb_chars.upcase.to_s
          needle = needle.mb_chars.upcase.to_s
        else
          fail Exception::BadRequest, "Collation type: #{collation} is not supported"
        end

        case match_type
        when 'contains'
          !!haystack.index(needle)
        when 'equals'
          haystack == needle
        when 'starts-with'
          haystack.index(needle) == 0
        when 'ends-with'
          haystack.rindex(needle) == haystack.length - needle.length
        else
          fail Exception::BadRequest, "Match-type: #{match_type} is not supported"
        end
      end

      # This method takes an input string, checks if it's not valid UTF-8 and
      # attempts to convert it to UTF-8 if it's not.
      #
      # Note that currently this can only convert ISO-8559-1 to UTF-8 (latin-1),
      # anything else will likely fail.
      #
      # @param string input
      # @return string
      def self.ensure_utf8(input)
        cd = CharDet.detect(input)

        # Best solution I could find ...
        if cd['confidence'] > 0.4 && cd['encoding'] =~ /(?:windows|iso)/i
          input = input.encode('UTF-8', cd['encoding'])
        end

        # Removing any control characters
        input.gsub(/(?:[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F])/, '')
      end
    end
  end
end
