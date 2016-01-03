require 'test_helper'

module Tilia
  module CardDav
    module Backend
      class SequelSqliteTest < Minitest::Test
        include AbstractSequelTest

        def sequel
          self.class.sequel
        end

        def self.sequel
          db = TestUtil.sqlite
          db.run('DROP TABLE IF EXISTS addressbooks')
          db.run('DROP TABLE IF EXISTS addressbookchanges')
          db.run('DROP TABLE IF EXISTS cards')

          db.run(<<SQL
CREATE TABLE addressbooks (
  id integer primary key asc,
  principaluri text,
  displayname text,
  uri text,
  description text,
  synctoken integer
)
SQL
                )
          db.run(<<SQL
CREATE TABLE cards (
  id integer primary key asc,
  addressbookid integer,
  carddata blob,
  uri text,
  lastmodified integer,
  etag text,
  size integer
)
SQL
                )
          db.run(<<SQL
CREATE TABLE addressbookchanges (
  id integer primary key asc,
  uri text,
  synctoken integer,
  addressbookid integer,
  operation integer
)
SQL
                )
          db.run('CREATE INDEX addressbookid_synctoken ON addressbookchanges (addressbookid, synctoken)')

          db
        end
      end
    end
  end
end
