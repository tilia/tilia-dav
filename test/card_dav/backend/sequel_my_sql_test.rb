require 'test_helper'

module Tilia
  module CardDav
    module Backend
      class SequelMySqlTest < Minitest::Test
        include AbstractSequelTest

        def sequel
          db = TestUtil.mysql
          db.run('DROP TABLE IF EXISTS addressbooks')
          db.run('DROP TABLE IF EXISTS addressbookchanges')
          db.run('DROP TABLE IF EXISTS cards')

          db.run(<<QUERY
CREATE TABLE addressbooks (
  id INT(11) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  principaluri VARBINARY(255),
  displayname VARCHAR(255),
  uri VARBINARY(200),
  description VARCHAR(10000),
  synctoken INT(11) UNSIGNED NOT NULL DEFAULT '1',
  UNIQUE(principaluri(100), uri(100))
) #{TestUtil.mysql_engine} DEFAULT CHARSET=utf8mb4
QUERY
                )
          db.run(<<QUERY
CREATE TABLE cards (
  id INT(11) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  addressbookid INT(11) UNSIGNED NOT NULL,
  carddata VARBINARY(10000),
  uri VARBINARY(200),
  lastmodified INT(11) UNSIGNED,
  etag VARBINARY(32),
  size INT(11) UNSIGNED NOT NULL
) #{TestUtil.mysql_engine} DEFAULT CHARSET=utf8mb4
QUERY
                )
          db.run(<<QUERY
CREATE TABLE addressbookchanges (
  id INT(11) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  uri VARBINARY(200) NOT NULL,
  synctoken INT(11) UNSIGNED NOT NULL,
  addressbookid INT(11) UNSIGNED NOT NULL,
  operation SMALLINT(2) NOT NULL,
  INDEX addressbookid_synctoken (addressbookid, synctoken)
) #{TestUtil.mysql_engine} DEFAULT CHARSET=utf8mb4
QUERY
                )

          db
        end
      end
    end
  end
end
