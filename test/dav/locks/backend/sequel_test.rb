require 'test_helper'

module Tilia
  module Dav
    module Locks
      module Backend
        class SequelTest < Minitest::Test
          include AbstractTest

          def backend
            db = TestUtil.sqlite
            db.run('CREATE TABLE locks ( id integer primary key asc, owner text, timeout text, created integer, token text, scope integer, depth integer, uri text)')
            Sequel.new(db)
          end
        end
      end
    end
  end
end
