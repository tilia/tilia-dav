require 'test_helper'

module Tilia
  module Dav
    module PropertyStorage
      module Backend
        class SequelSqliteTest < Minitest::Test
          include AbstractSequelTest

          def sequel
            db = TestUtil.sqlite
            db.run(<<SQL
CREATE TABLE propertystorage (
    id integer primary key asc,
    path text,
    name text,
    valuetype integer,
    value string
)
SQL
                  )
            db.run('CREATE UNIQUE INDEX path_property ON propertystorage (path, name)')
            db.run('INSERT INTO propertystorage (path, name, value) VALUES ("dir", "{DAV:}displayname", "Directory")')

            db
          end
        end
      end
    end
  end
end
