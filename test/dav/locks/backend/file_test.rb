require 'test_helper'

module Tilia
  module Dav
    module Locks
      module Backend
        class FileTest < Minitest::Test
          include AbstractTest

          def backend
            @temp_dir = Dir.mktmpdir

            backend = File.new("#{@temp_dir}/lockdb")
            backend
          end

          def teardown
            FileUtils.remove_entry @temp_dir
          end
        end
      end
    end
  end
end
