module Tilia
  module Dav
    module Auth
      module Backend
        # This is an authentication backend that uses a database to manage passwords.
        class Sequel < AbstractDigest
          # PDO table name we'll be using
          #
          # @var string
          attr_accessor :table_name

          # Creates the backend object.
          #
          # If the filename argument is passed in, it will parse out the specified file fist.
          #
          # @param sequel
          def initialize(sequel)
            @sequel = sequel
            @table_name = 'users'

            super()
          end

          # Returns the digest hash for a user.
          #
          # @param string realm
          # @param string username
          # @return string|null
          def digest_hash(_realm, username)
            @sequel.fetch("SELECT digesta1 FROM #{@table_name} WHERE username=?", username) do |row|
              return row[:digesta1]
            end
            nil
          end
        end
      end
    end
  end
end
