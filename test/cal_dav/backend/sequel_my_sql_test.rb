require 'test_helper'

module Tilia
  module CalDav
    module Backend
      class SequelMySqlTest < Minitest::Test
        include AbstractSequelTest

        def sequel
          db = TestUtil.mysql
          db.run('DROP TABLE IF EXISTS calendarobjects')
          db.run('DROP TABLE IF EXISTS calendars')
          db.run('DROP TABLE IF EXISTS calendarchanges')
          db.run('DROP TABLE IF EXISTS calendarsubscriptions')
          db.run('DROP TABLE IF EXISTS schedulingobjects')

          db.run(<<SQL
CREATE TABLE calendarobjects (
  id INT(11) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  calendardata VARBINARY(10000),
  uri VARBINARY(200),
  calendarid INTEGER UNSIGNED NOT NULL,
  lastmodified INT(11) UNSIGNED,
  etag VARBINARY(32),
  size INT(11) UNSIGNED NOT NULL,
  componenttype VARBINARY(8),
  firstoccurence INT(11) UNSIGNED,
  lastoccurence INT(11) UNSIGNED,
  uid VARBINARY(200),
  UNIQUE(calendarid, uri)
) #{TestUtil.mysql_engine} DEFAULT CHARSET=utf8mb4
SQL
                )

          db.run(<<SQL
CREATE TABLE calendars (
  id INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  principaluri VARBINARY(100),
  displayname VARCHAR(100),
  uri VARBINARY(200),
  synctoken INTEGER UNSIGNED NOT NULL DEFAULT '1',
  description VARCHAR(1000),
  calendarorder INT(11) UNSIGNED NOT NULL DEFAULT '0',
  calendarcolor VARBINARY(10),
  timezone VARCHAR(10000),
  components VARBINARY(20),
  transparent TINYINT(1) NOT NULL DEFAULT '0',
  UNIQUE(principaluri, uri)
) #{TestUtil.mysql_engine} DEFAULT CHARSET=utf8mb4
SQL
                )

          db.run(<<SQL
CREATE TABLE calendarchanges (
  id INT(11) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  uri VARBINARY(200) NOT NULL,
  synctoken INT(11) UNSIGNED NOT NULL,
  calendarid INT(11) UNSIGNED NOT NULL,
  operation INT(11) NOT NULL,
  INDEX calendarid_synctoken (calendarid, synctoken)
) #{TestUtil.mysql_engine} DEFAULT CHARSET=utf8mb4
SQL
                )

          db.run(<<SQL
CREATE TABLE calendarsubscriptions (
  id INT(11) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  uri VARBINARY(200) NOT NULL,
  principaluri VARBINARY(100) NOT NULL,
  source VARCHAR(10000),
  displayname VARCHAR(100),
  refreshrate VARCHAR(10),
  calendarorder INT(11) UNSIGNED NOT NULL DEFAULT '0',
  calendarcolor VARBINARY(10),
  striptodos TINYINT(1) NULL,
  stripalarms TINYINT(1) NULL,
  stripattachments TINYINT(1) NULL,
  lastmodified INT(11) UNSIGNED,
  UNIQUE(principaluri, uri)
) #{TestUtil.mysql_engine} DEFAULT CHARSET=utf8mb4
SQL
                )

          db.run(<<SQL
CREATE TABLE schedulingobjects (
  id INT(11) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  principaluri VARBINARY(255),
  calendardata VARBINARY(10000),
  uri VARBINARY(200),
  lastmodified INT(11) UNSIGNED,
  etag VARBINARY(32),
  size INT(11) UNSIGNED NOT NULL
) #{TestUtil.mysql_engine} DEFAULT CHARSET=utf8mb4
SQL
                )

          db
        end
      end
    end
  end
end
