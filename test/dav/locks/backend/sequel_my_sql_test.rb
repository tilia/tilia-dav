require 'test_helper'

module Tilia
  module Dav
    module Locks
      module Backend
        class SequelMySqlTest < Minitest::Test
          include AbstractTest

          def backend
            db = TestUtil.mysql
            db.run('DROP TABLE IF EXISTS locks')
            db.run(<<QUERY
CREATE TABLE locks (
  id INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  owner VARCHAR(100),
  timeout INTEGER UNSIGNED,
  created INTEGER,
  token VARCHAR(100),
  scope TINYINT,
  depth TINYINT,
  uri VARCHAR(255)
) #{TestUtil.mysql_engine}
QUERY
                  )
            Sequel.new(db)
          end
        end
      end
    end
  end
end
