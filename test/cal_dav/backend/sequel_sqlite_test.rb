require 'test_helper'

module Tilia
  module CalDav
    module Backend
      class SequelSqliteTest < Minitest::Test
        include AbstractSequelTest

        def sequel
          self.class.sequel
        end

        def self.sequel
          db = TestUtil.sqlite
          db.run('DROP TABLE IF EXISTS calendarobjects')
          db.run('DROP TABLE IF EXISTS calendars')
          db.run('DROP TABLE IF EXISTS calendarchanges')
          db.run('DROP TABLE IF EXISTS calendarsubscriptions')
          db.run('DROP TABLE IF EXISTS schedulingobjects')

          db.run(<<SQL
CREATE TABLE calendarobjects (
  id integer primary key asc,
  calendardata blob,
  uri text,
  calendarid integer,
  lastmodified integer,
  etag text,
  size integer,
  componenttype text,
  firstoccurence integer,
  lastoccurence integer,
  uid text
)
SQL
                )

          db.run(<<SQL
CREATE TABLE calendars (
  id integer primary key asc,
  principaluri text,
  displayname text,
  uri text,
  synctoken integer,
  description text,
  calendarorder integer,
  calendarcolor text,
  timezone text,
  components text,
  transparent bool
)
SQL
                )

          db.run(<<SQL
CREATE TABLE calendarchanges (
  id integer primary key asc,
  uri text,
  synctoken integer,
  calendarid integer,
  operation integer
)
SQL
                )

          db.run('CREATE INDEX calendarid_synctoken ON calendarchanges (calendarid, synctoken)')
          db.run(<<SQL
CREATE TABLE calendarsubscriptions (
  id integer primary key asc,
  uri text,
  principaluri text,
  source text,
  displayname text,
  refreshrate text,
  calendarorder integer,
  calendarcolor text,
  striptodos bool,
  stripalarms bool,
  stripattachments bool,
  lastmodified int
)
SQL
                )

          db.run(<<SQL
CREATE TABLE schedulingobjects (
  id integer primary key asc,
  principaluri text,
  calendardata blob,
  uri text,
  lastmodified integer,
  etag text,
  size integer
)
SQL
                )

          db.run('CREATE INDEX principaluri_uri ON calendarsubscriptions (principaluri, uri)')

          db
        end
      end
    end
  end
end
