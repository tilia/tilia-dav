require 'test_helper'

module Tilia
  module Dav
    module Auth
      module Backend
        class SequelSQLiteTest < Minitest::Test
          include AbstractSequelTest

          def sequel
            db = TestUtil.sqlite
            db.run('CREATE TABLE users (username TEXT, digesta1 TEXT, email VARCHAR(80), displayname VARCHAR(80))')
            db.run('INSERT INTO users VALUES ("user","hash","user@example.org","User")')

            db
          end
        end
      end
    end
  end
end
