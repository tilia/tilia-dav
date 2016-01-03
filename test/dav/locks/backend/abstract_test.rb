module Tilia
  module Dav
    module Locks
      module Backend
        module AbstractTest
          def backend
            fail NotImplementedError
          end

          def test_setup
            backend = self.backend
            assert_kind_of(AbstractBackend, backend)
          end

          def test_get_locks
            backend = self.backend

            lock = LockInfo.new
            lock.owner = 'Sinterklaas'
            lock.timeout = 60
            lock.created = Time.now.to_i
            lock.token = 'MY-UNIQUE-TOKEN'
            lock.uri = 'someuri'

            assert(backend.lock('someuri', lock))

            locks = backend.locks('someuri', false)

            assert_equal(1, locks.size)
            assert_equal('Sinterklaas', locks[0].owner)
            assert_equal('someuri', locks[0].uri)
          end

          def test_get_locks_parent
            backend = self.backend

            lock = LockInfo.new
            lock.owner = 'Sinterklaas'
            lock.timeout = 60
            lock.created = Time.now.to_i
            lock.depth = Server::DEPTH_INFINITY
            lock.token = 'MY-UNIQUE-TOKEN'

            assert(backend.lock('someuri', lock))

            locks = backend.locks('someuri/child', false)

            assert_equal(1, locks.size)
            assert_equal('Sinterklaas', locks[0].owner)
            assert_equal('someuri', locks[0].uri)
          end

          def test_get_locks_parent_depth0
            backend = self.backend

            lock = LockInfo.new
            lock.owner = 'Sinterklaas'
            lock.timeout = 60
            lock.created = Time.now.to_i
            lock.depth = 0
            lock.token = 'MY-UNIQUE-TOKEN'

            assert(backend.lock('someuri', lock))

            locks = backend.locks('someuri/child', false)

            assert_equal(0, locks.size)
          end

          def test_get_locks_children
            backend = self.backend

            lock = LockInfo.new
            lock.owner = 'Sinterklaas'
            lock.timeout = 60
            lock.created = Time.now.to_i
            lock.depth = 0
            lock.token = 'MY-UNIQUE-TOKEN'

            assert(backend.lock('someuri/child', lock))

            locks = backend.locks('someuri/child', false)
            assert_equal(1, locks.size)

            locks = backend.locks('someuri', false)
            assert_equal(0, locks.size)

            locks = backend.locks('someuri', true)
            assert_equal(1, locks.size)
          end

          def test_lock_refresh
            backend = self.backend

            lock = LockInfo.new
            lock.owner = 'Sinterklaas'
            lock.timeout = 60
            lock.created = Time.now.to_i
            lock.token = 'MY-UNIQUE-TOKEN'

            assert(backend.lock('someuri', lock))

            # Second time

            lock.owner = 'Santa Clause'
            assert(backend.lock('someuri', lock))

            locks = backend.locks('someuri', false)

            assert_equal(1, locks.size)

            assert_equal('Santa Clause', locks[0].owner)
            assert_equal('someuri', locks[0].uri)
          end

          def test_unlock
            backend = self.backend

            lock = LockInfo.new
            lock.owner = 'Sinterklaas'
            lock.timeout = 60
            lock.created = Time.now.to_i
            lock.token = 'MY-UNIQUE-TOKEN'

            assert(backend.lock('someuri', lock))

            locks = backend.locks('someuri', false)
            assert_equal(1, locks.size)

            assert(backend.unlock('someuri', lock))

            locks = backend.locks('someuri', false)
            assert_equal(0, locks.size)
          end

          def test_unlock_unknown_token
            backend = self.backend

            lock = LockInfo.new
            lock.owner = 'Sinterklaas'
            lock.timeout = 60
            lock.created = Time.now.to_i
            lock.token = 'MY-UNIQUE-TOKEN'

            assert(backend.lock('someuri', lock))

            locks = backend.locks('someuri', false)
            assert_equal(1, locks.size)

            lock.token = 'SOME-OTHER-TOKEN'
            refute(backend.unlock('someuri', lock))

            locks = backend.locks('someuri', false)
            assert_equal(1, locks.size)
          end
        end
      end
    end
  end
end
