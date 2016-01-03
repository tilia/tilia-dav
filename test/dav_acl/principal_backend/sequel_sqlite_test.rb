require 'test_helper'

module Tilia
  module DavAcl
    module PrincipalBackend
      class SequelSqliteTest < Minitest::Test
        include AbstractSequelTest

        def sequel
          db = TestUtil.sqlite
          db.run('CREATE TABLE principals (id INTEGER PRIMARY KEY ASC, uri TEXT, email VARCHAR(80), displayname VARCHAR(80))')
          db.run('INSERT INTO principals VALUES (1, "principals/user","user@example.org","User")')
          db.run('INSERT INTO principals VALUES (2, "principals/group","group@example.org","Group")')

          db.run(<<SQL
CREATE TABLE groupmembers (
  id INTEGER PRIMARY KEY ASC,
  principal_id INT,
  member_id INT,
  UNIQUE(principal_id, member_id)
)
SQL
                )
          db.run('INSERT INTO groupmembers (principal_id,member_id) VALUES (2,1)')

          db
        end
      end
    end
  end
end
