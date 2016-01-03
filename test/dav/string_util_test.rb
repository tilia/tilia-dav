require 'test_helper'

module Tilia
  module Dav
    class StringUtilTest < Minitest::Test
      def dataset
        [
          ['FOOBAR', 'FOO',    'i;octet', 'contains', true],
          ['FOOBAR', 'foo',    'i;octet', 'contains', false],
          ['FÖÖBAR', 'FÖÖ',    'i;octet', 'contains', true],
          ['FÖÖBAR', 'föö',    'i;octet', 'contains', false],
          ['FOOBAR', 'FOOBAR', 'i;octet', 'equals', true],
          ['FOOBAR', 'fooBAR', 'i;octet', 'equals', false],
          ['FOOBAR', 'FOO',    'i;octet', 'starts-with', true],
          ['FOOBAR', 'foo',    'i;octet', 'starts-with', false],
          ['FOOBAR', 'BAR',    'i;octet', 'starts-with', false],
          ['FOOBAR', 'bar',    'i;octet', 'starts-with', false],
          ['FOOBAR', 'FOO',    'i;octet', 'ends-with', false],
          ['FOOBAR', 'foo',    'i;octet', 'ends-with', false],
          ['FOOBAR', 'BAR',    'i;octet', 'ends-with', true],
          ['FOOBAR', 'bar',    'i;octet', 'ends-with', false],

          ['FOOBAR', 'FOO',    'i;ascii-casemap', 'contains', true],
          ['FOOBAR', 'foo',    'i;ascii-casemap', 'contains', true],
          ['FÖÖBAR', 'FÖÖ',    'i;ascii-casemap', 'contains', true],
          ['FÖÖBAR', 'föö',    'i;ascii-casemap', 'contains', false],
          ['FOOBAR', 'FOOBAR', 'i;ascii-casemap', 'equals', true],
          ['FOOBAR', 'fooBAR', 'i;ascii-casemap', 'equals', true],
          ['FOOBAR', 'FOO',    'i;ascii-casemap', 'starts-with', true],
          ['FOOBAR', 'foo',    'i;ascii-casemap', 'starts-with', true],
          ['FOOBAR', 'BAR',    'i;ascii-casemap', 'starts-with', false],
          ['FOOBAR', 'bar',    'i;ascii-casemap', 'starts-with', false],
          ['FOOBAR', 'FOO',    'i;ascii-casemap', 'ends-with', false],
          ['FOOBAR', 'foo',    'i;ascii-casemap', 'ends-with', false],
          ['FOOBAR', 'BAR',    'i;ascii-casemap', 'ends-with', true],
          ['FOOBAR', 'bar',    'i;ascii-casemap', 'ends-with', true],

          ['FOOBAR', 'FOO',    'i;unicode-casemap', 'contains', true],
          ['FOOBAR', 'foo',    'i;unicode-casemap', 'contains', true],
          ['FÖÖBAR', 'FÖÖ',    'i;unicode-casemap', 'contains', true],
          ['FÖÖBAR', 'föö',    'i;unicode-casemap', 'contains', true],
          ['FOOBAR', 'FOOBAR', 'i;unicode-casemap', 'equals', true],
          ['FOOBAR', 'fooBAR', 'i;unicode-casemap', 'equals', true],
          ['FOOBAR', 'FOO',    'i;unicode-casemap', 'starts-with', true],
          ['FOOBAR', 'foo',    'i;unicode-casemap', 'starts-with', true],
          ['FOOBAR', 'BAR',    'i;unicode-casemap', 'starts-with', false],
          ['FOOBAR', 'bar',    'i;unicode-casemap', 'starts-with', false],
          ['FOOBAR', 'FOO',    'i;unicode-casemap', 'ends-with', false],
          ['FOOBAR', 'foo',    'i;unicode-casemap', 'ends-with', false],
          ['FOOBAR', 'BAR',    'i;unicode-casemap', 'ends-with', true],
          ['FOOBAR', 'bar',    'i;unicode-casemap', 'ends-with', true]
        ]
      end

      def test_text_match
        dataset.each do |data|
          (haystack, needle, collation, match_type, result) = data
          assert_equal(result, Tilia::Dav::StringUtil.text_match(haystack, needle, collation, match_type))
        end
      end

      def test_bad_collation
        assert_raises(Tilia::Dav::Exception::BadRequest) { Tilia::Dav::StringUtil.text_match('foobar', 'foo', 'blabla', 'contains') }
      end

      def test_bad_match_type
        assert_raises(Tilia::Dav::Exception::BadRequest) { Tilia::Dav::StringUtil.text_match('foobar', 'foo', 'i;octet', 'booh') }
      end

      def test_ensure_utf8_ascii
        input_string = 'harkema'
        output_string = 'harkema'

        assert_equal(output_string, Tilia::Dav::StringUtil.ensure_utf8(input_string))
      end

      def test_ensure_utf8_latin1
        input_string = "m\u00fcnster"
        output_string = 'münster'

        assert_equal(output_string, Tilia::Dav::StringUtil.ensure_utf8(input_string))
      end

      def test_ensure_utf8_utf8
        input_string = "m\xc3\xbcnster"
        output_string = 'münster'

        assert_equal(output_string, Tilia::Dav::StringUtil.ensure_utf8(input_string))
      end
    end
  end
end
