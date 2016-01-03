require 'test_helper'

module Tilia
  module Dav
    module Auth
      module Backend
        class FileTest < Minitest::Test
          def setup
            @temp_dir = Dir.mktmpdir
          end

          def teardown
            FileUtils.remove_entry @temp_dir
          end

          def test_construct
            file = Auth::Backend::File.new
            assert_kind_of(Auth::Backend::File, file)
          end

          def test_load_file_broken
            ::File.open("#{@temp_dir}/backend", 'w') do |f|
              f.puts 'user:realm:hash'
            end
            file = Auth::Backend::File.new
            assert_raises(Exception) { file.load_file("#{@temp_dir}/backend") }
          end

          def test_load_file
            ::File.open("#{@temp_dir}/backend", 'w') do |f|
              f.puts "user:realm:#{Digest::MD5.hexdigest('user:realm:password')}"
            end
            file = Auth::Backend::File.new
            file.load_file("#{@temp_dir}/backend")

            refute(file.digest_hash('realm', 'blabla'))
            assert_equal(Digest::MD5.hexdigest('user:realm:password'), file.digest_hash('realm', 'user'))
          end
        end
      end
    end
  end
end
