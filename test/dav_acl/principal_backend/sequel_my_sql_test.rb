require 'test_helper'

module Tilia
  module DavAcl
    module PrincipalBackend
      class SequelMySqlTest < Minitest::Test
        include AbstractSequelTest

        def sequel
          db = TestUtil.mysql
          db.run('DROP TABLE IF EXISTS principals')
          db.run(<<QUERY
create table principals (
  id integer unsigned not null primary key auto_increment,
  uri varchar(50),
  email varchar(80),
  displayname VARCHAR(80),
  vcardurl VARCHAR(80),
  unique(uri)
) #{TestUtil.mysql_engine}
QUERY
                )
          db.run("INSERT INTO principals (uri,email,displayname) VALUES ('principals/user','user@example.org','User')")
          db.run("INSERT INTO principals (uri,email,displayname) VALUES ('principals/group','group@example.org','Group')")

          db.run('DROP TABLE IF EXISTS groupmembers')
          db.run(<<QUERY
CREATE TABLE groupmembers (
  id INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  principal_id INTEGER UNSIGNED NOT NULL,
  member_id INTEGER UNSIGNED NOT NULL,
  UNIQUE(principal_id, member_id)
)  #{TestUtil.mysql_engine}
QUERY
                )
          db.run('INSERT INTO groupmembers (principal_id,member_id) VALUES (2,1)')

          db
        end
      end
    end
  end
end
