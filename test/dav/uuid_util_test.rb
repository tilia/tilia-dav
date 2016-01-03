require 'test_helper'

module Tilia
  module Dav
    class UuidUtilTest < Minitest::Test
      def test_validate_uuid
        assert(Tilia::Dav::UuidUtil.validate_uuid('11111111-2222-3333-4444-555555555555'))
        refute(Tilia::Dav::UuidUtil.validate_uuid(' 11111111-2222-3333-4444-555555555555'))
        assert(Tilia::Dav::UuidUtil.validate_uuid('ffffffff-2222-3333-4444-555555555555'))
        refute(Tilia::Dav::UuidUtil.validate_uuid('fffffffg-2222-3333-4444-555555555555'))
      end
    end
  end
end
