module Tilia
  module Dav
    module Auth
      module Backend
        # This is an authentication backend that uses a file to manage passwords.
        #
        # The backend file must conform to Apache's htdigest format
        class File < AbstractDigest
          # List of users
          #
          # @var array
          # RUBY: attr_accessor :users

          # Creates the backend object.
          #
          # If the filename argument is passed in, it will parse out the specified file fist.
          #
          # @param string|null filename
          def initialize(filename = nil)
            super()
            @users = {}

            load_file(filename) if filename
          end

          # Loads an htdigest-formatted file. This method can be called multiple times if
          # more than 1 file is used.
          #
          # @param string filename
          # @return void
          def load_file(filename)
            ::File.readlines(filename).each do |line|
              line.chomp!

              if line.scan(':').size != 2
                fail Dav::Exception, 'Malformed htdigest file. Every line should contain 2 colons'
              end

              (username, realm, a1) = line.split(':')

              unless a1 =~ /^[a-zA-Z0-9]{32}$/
                fail Dav::Exception, 'Malformed htdigest file. Invalid md5 hash'
              end

              @users[realm + ':' + username] = a1
            end
          end

          # Returns a users' information
          #
          # @param string realm
          # @param string username
          # @return string
          def digest_hash(realm, username)
            @users["#{realm}:#{username}"]
          end
        end
      end
    end
  end
end
