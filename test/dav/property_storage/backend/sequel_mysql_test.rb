require 'test_helper'

module Tilia
  module Dav
    module PropertyStorage
      module Backend
        class SequelMysqlTest < Minitest::Test
          include AbstractSequelTest

          def sequel
            db = TestUtil.mysql
            db.run('DROP TABLE IF EXISTS propertystorage')
            db.run(<<QUERY
CREATE TABLE propertystorage (
  id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  path VARBINARY(1024) NOT NULL,
  name VARBINARY(100) NOT NULL,
  valuetype INT UNSIGNED,
  value VARBINARY(255)
) #{TestUtil.mysql_engine}
QUERY
                  )
            db.run('CREATE UNIQUE INDEX path_property ON propertystorage (path(600), name(100))')
            db.run('INSERT INTO propertystorage (path, name, value) VALUES ("dir", "{DAV:}displayname", "Directory")')

            db
          end
        end
      end
    end
  end
end
