module Tilia
  module Dav
    module Locks
      # LockInfo class
      #
      # An object of the LockInfo class holds all the information relevant to a
      # single lock.
      class LockInfo
        # A shared lock
        SHARED = 1

        # An exclusive lock
        EXCLUSIVE = 2

        # A never expiring timeout
        TIMEOUT_INFINITE = -1

        # The owner of the lock
        #
        # @var string
        attr_accessor :owner

        # The locktoken
        #
        # @var string
        attr_accessor :token

        # How long till the lock is expiring
        #
        # @var int
        attr_accessor :timeout

        # UNIX Timestamp of when this lock was created
        #
        # @var int
        attr_accessor :created

        # Exclusive or shared lock
        #
        # @var int
        attr_accessor :scope

        # Depth of lock, can be 0 or Sabre\DAV\Server::DEPTH_INFINITY
        attr_accessor :depth

        # The uri this lock locks
        #
        # TODO: This value is not always set
        # @var mixed
        attr_accessor :uri

        # TODO: document
        def initialize
          @scope = EXCLUSIVE
          @depth = 0
        end
      end
    end
  end
end
