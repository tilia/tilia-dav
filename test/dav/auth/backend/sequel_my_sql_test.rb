require 'test_helper'

module Tilia
  module Dav
    module Auth
      module Backend
        class SequelMySQLTest < Minitest::Test
          include AbstractSequelTest

          def sequel
            db = TestUtil.mysql
            db.run('DROP TABLE IF EXISTS users')
            db.run(<<QUERY
create table users (
  id integer unsigned not null primary key auto_increment,
  username varchar(50),
  digesta1 varchar(32),
  email varchar(80),
  displayname varchar(80),
  unique(username)
) #{TestUtil.mysql_engine}
QUERY
                  )
            db.run("INSERT INTO users (username,digesta1,email,displayname) VALUES ('user','hash','user@example.org','User')")

            db
          end
        end
      end
    end
  end
end
