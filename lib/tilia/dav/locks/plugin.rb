require 'stringio'

module Tilia
  module Dav
    module Locks
      # Locking plugin
      #
      # This plugin provides locking support to a WebDAV server.
      # The easiest way to get started, is by hooking it up as such:
      #
      # lock_backend = new Sabre\DAV\Locks\Backend\File('./mylockdb')
      # lock_plugin = new Sabre\DAV\Locks\Plugin(lock_backend)
      # server.add_plugin(lock_plugin)
      class Plugin < ServerPlugin
        # locksBackend
        #
        # @var Backend\Backend\Interface
        # RUBY: attr_accessor :locks_backend

        # server
        #
        # @var Sabre\DAV\Server
        # RUBY: attr_accessor :server

        # __construct
        #
        # @param Backend\BackendInterface locks_backend
        def initialize(locks_backend)
          @locks_backend = locks_backend
        end

        # Initializes the plugin
        #
        # This method is automatically called by the Server class after addPlugin.
        #
        # @param DAV\Server server
        # @return void
        def setup(server)
          @server = server

          @server.xml.element_map['{DAV:}lockinfo'] = Xml::Request::Lock

          server.on('method:LOCK',    method(:http_lock))
          server.on('method:UNLOCK',  method(:http_unlock))
          server.on('validateTokens', method(:validate_tokens))
          server.on('propFind',       method(:prop_find))
          server.on('afterUnbind',    method(:after_unbind))
        end

        # Returns a plugin name.
        #
        # Using this name other plugins will be able to access other plugins
        # using Sabre\DAV\Server::getPlugin
        #
        # @return string
        def plugin_name
          'locks'
        end

        # This method is called after most properties have been found
        # it allows us to add in any Lock-related properties
        #
        # @param DAV\PropFind prop_find
        # @param DAV\INode node
        # @return void
        def prop_find(prop_find, _node)
          prop_find.handle('{DAV:}supportedlock', -> { Dav::Xml::Property::SupportedLock.new })
          prop_find.handle('{DAV:}lockdiscovery', -> { Dav::Xml::Property::LockDiscovery.new(locks(prop_find.path)) })
        end

        # Use this method to tell the server this plugin defines additional
        # HTTP methods.
        #
        # This method is passed a uri. It should only return HTTP methods that are
        # available for the specified uri.
        #
        # @param string uri
        # @return array
        def http_methods(_uri)
          ['LOCK', 'UNLOCK']
        end

        # Returns a list of features for the HTTP OPTIONS Dav: header.
        #
        # In this case this is only the number 2. The 2 in the Dav: header
        # indicates the server supports locks.
        #
        # @return array
        def features
          [2]
        end

        # Returns all lock information on a particular uri
        #
        # This function should return an array with Sabre\DAV\Locks\LockInfo objects. If there are no locks on a file, return an empty array.
        #
        # Additionally there is also the possibility of locks on parent nodes, so we'll need to traverse every part of the tree
        # If the return_child_locks argument is set to true, we'll also traverse all the children of the object
        # for any possible locks and return those as well.
        #
        # @param string uri
        # @param bool return_child_locks
        # @return array
        def locks(uri, return_child_locks = false)
          @locks_backend.locks(uri, return_child_locks)
        end

        # Locks an uri
        #
        # The WebDAV lock request can be operated to either create a new lock on a file, or to refresh an existing lock
        # If a new lock is created, a full XML body should be supplied, containing information about the lock such as the type
        # of lock (shared or exclusive) and the owner of the lock
        #
        # If a lock is to be refreshed, no body should be supplied and there should be a valid If header containing the lock
        #
        # Additionally, a lock can be requested for a non-existent file. In these case we're obligated to create an empty file as per RFC4918:S7.3
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return bool
        def http_lock(request, response)
          uri = request.path
          existing_locks = locks(uri)

          body = request.body_as_string
          if !body.blank?
            # This is a new lock request

            existing_lock = nil
            # Checking if there's already non-shared locks on the uri.
            existing_locks.each do |existing_lock|
              if existing_lock.scope == LockInfo::EXCLUSIVE
                fail Exception::ConflictingLock.new(existing_lock)
              end
            end

            lock_info = parse_lock_request(body)
            lock_info.depth = @server.http_depth
            lock_info.uri = uri
            if existing_lock && lock_info.scope != LockInfo::SHARED
              fail Exception::ConflictingLock(existing_lock)
            end
          else
            # Gonna check if this was a lock refresh.
            existing_locks = locks(uri)
            conditions = @server.if_conditions(request)
            found = nil

            existing_locks.each do |existing_lock|
              conditions.each do |condition|
                condition['tokens'].each do |token|
                  if token['token'] == 'opaquelocktoken:' + existing_lock.token
                    found = existing_lock
                    break
                  end
                end
                break if found
              end
              break if found
            end

            # If none were found, this request is in error.
            unless found
              if existing_locks.any?
                fail Exception::Locked.new(existing_locks.first)
              else
                fail Exception::BadRequest, 'An xml body is required for lock requests'
              end
            end

            # This must have been a lock refresh
            lock_info = found

            # The resource could have been locked through another uri.
            uri = lock_info.uri unless uri == lock_info.uri
          end

          timeout = timeout_header
          lock_info.timeout = timeout if timeout

          new_file = false

          # If we got this far.. we should go check if this node actually exists. If this is not the case, we need to create it first
          begin
            @server.tree.node_for_path(uri)

            # We need to call the beforeWriteContent event for RFC3744
            # Edit: looks like this is not used, and causing problems now.
            #
            # See Issue 222
            # @server.emit('beforeWriteContent',array(uri))
          rescue Exception::NotFound => e
            # It didn't, lets create it
            @server.create_file(uri, StringIO.new)
            new_file = true
          end

          lock_node(uri, lock_info)

          response.update_header('Content-Type', 'application/xml; charset=utf-8')
          response.update_header('Lock-Token', '<opaquelocktoken:' + lock_info.token + '>')
          response.status = new_file ? 201 : 200
          response.body = generate_lock_response(lock_info)

          # Returning false will interupt the event chain and mark this method
          # as 'handled'.
          false
        end

        # Unlocks a uri
        #
        # This WebDAV method allows you to remove a lock from a node. The client should provide a valid locktoken through the Lock-token http header
        # The server should return 204 (No content) on success
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return void
        def http_unlock(request, response)
          lock_token = request.header('Lock-Token')

          # If the locktoken header is not supplied, we need to throw a bad request exception
          fail Exception::BadRequest, 'No lock token was supplied' unless lock_token

          path = request.path
          locks = locks(path)

          # Windows sometimes forgets to include < and > in the Lock-Token
          # header
          lock_token = '<' + lock_token + '>' unless lock_token[0] == '<'

          locks.each do |lock|
            next unless "<opaquelocktoken:#{lock.token}>" == lock_token
            unlock_node(path, lock)
            response.update_header('Content-Length', '0')
            response.status = 204

            # Returning false will break the method chain, and mark the
            # method as 'handled'.
            return false
          end

          # If we got here, it means the locktoken was invalid
          fail Exception::LockTokenMatchesRequestUri
        end

        # This method is called after a node is deleted.
        #
        # We use this event to clean up any locks that still exist on the node.
        #
        # @param string path
        # @return void
        def after_unbind(path)
          locks = locks(path, include_children = true)
          locks.each do |lock|
            unlock_node(path, lock)
          end
        end

        # Locks a uri
        #
        # All the locking information is supplied in the lockInfo object. The object has a suggested timeout, but this can be safely ignored
        # It is important that if the existing timeout is ignored, the property is overwritten, as this needs to be sent back to the client
        #
        # @param string uri
        # @param LockInfo lock_info
        # @return bool
        def lock_node(uri, lock_info)
          return nil unless @server.emit('beforeLock', [uri, lock_info])
          @locks_backend.lock(uri, lock_info)
        end

        # Unlocks a uri
        #
        # This method removes a lock from a uri. It is assumed all the supplied information is correct and verified
        #
        # @param string uri
        # @param LockInfo lock_info
        # @return bool
        def unlock_node(uri, lock_info)
          return nil unless @server.emit('beforeUnlock', [uri, lock_info])
          @locks_backend.unlock(uri, lock_info)
        end

        # Returns the contents of the HTTP Timeout header.
        #
        # The method formats the header into an integer.
        #
        # @return int
        def timeout_header
          header = @server.http_request.header('Timeout')

          if header
            if header.downcase.index('second-') == 0
              header = header[7..-1].to_i
            elsif header.downcase.index('infinite') == 0
              header = LockInfo::TIMEOUT_INFINITE
            else
              fail Exception::BadRequest, 'Invalid HTTP timeout header'
            end
          else
            header = 0
          end

          header
        end

        protected

        # Generates the response for successful LOCK requests
        #
        # @param LockInfo lock_info
        # @return string
        def generate_lock_response(lock_info)
          @server.xml.write(
            '{DAV:}prop',
            '{DAV:}lockdiscovery' => Xml::Property::LockDiscovery.new([lock_info])
          )
        end

        public

        # The validateTokens event is triggered before every request.
        #
        # It's a moment where this plugin can check all the supplied lock tokens
        # in the If: header, and check if they are valid.
        #
        # In addition, it will also ensure that it checks any missing lokens that
        # must be present in the request, and reject requests without the proper
        # tokens.
        #
        # @param RequestInterface request
        # @param mixed conditions
        # @return void
        def validate_tokens(request, conditions_box)
          conditions = conditions_box.value

          # First we need to gather a list of locks that must be satisfied.
          must_locks = []
          method = request.method

          # Methods not in that list are operations that doesn't alter any
          # resources, and we don't need to check the lock-states for.
          case method
          when 'DELETE'
            must_locks += locks(request.path, true)
          when 'MKCOL', 'MKCALENDAR', 'PROPPATCH', 'PUT', 'PATCH'
            must_locks += locks(request.path, false)
          when 'MOVE'
            must_locks += locks(request.path, true)
            must_locks += locks(@server.calculate_uri(request.header('Destination')), false)
          when 'COPY'
            must_locks += locks(@server.calculate_uri(request.header('Destination')), false)
          when 'LOCK'
            # Temporary measure.. figure out later why this is needed
            # Here we basically ignore all incoming tokens...
            conditions.each_with_index do |condition, ii|
              condition['tokens'].each_with_index do |_token, jj|
                conditions[ii]['tokens'][jj]['validToken'] = true
              end
            end
            conditions_box.value = conditions
            return nil
          end

          # It's possible that there's identical locks, because of shared
          # parents. We're removing the duplicates here.
          tmp = {}
          must_locks.each do |lock|
            tmp[lock.token] = lock
          end
          must_locks = tmp.values

          conditions.each_with_index do |condition, kk|
            condition['tokens'].each_with_index do |token, ii|
              # Lock tokens always start with opaquelocktoken:
              next unless token['token'][0, 16] == 'opaquelocktoken:'

              check_token = token['token'][16..-1]

              # Looping through our list with locks.
              skip = false
              must_locks.each_with_index do |must_lock, jj|
                next unless must_lock.token == check_token
                must_locks.delete_at(jj)

                # Marking the condition as valid.
                conditions[kk]['tokens'][ii]['validToken'] = true

                # Advancing to the next token
                skip = true
                break
              end
              next if skip

              # If we got here, it means that there was a
              # lock-token, but it was not in 'mustLocks'.
              #
              # This is an edge-case, as it could mean that token
              # was specified with a url that was not 'required' to
              # check. So we're doing one extra lookup to make sure
              # we really don't know this token.
              #
              # This also gets triggered when the user specified a
              # lock-token that was expired.
              odd_locks = locks(condition['uri'])
              odd_locks.each do |odd_lock|
                next unless odd_lock.token == check_token
                conditions[kk]['tokens'][ii]['validToken'] = true
                skip = true
                break
              end
              next if skip

              # If we get all the way here, the lock-token was
              # really unknown.
            end
          end
          conditions_box.value = conditions

          # If there's any locks left in the 'mustLocks' array, it means that
          # the resource was locked and we must block it.
          fail Exception::Locked.new(must_locks.first) if must_locks.any?
        end

        protected

        # Parses a webdav lock xml body, and returns a new Sabre\DAV\Locks\LockInfo object
        #
        # @param string body
        # @return LockInfo
        def parse_lock_request(body)
          result = @server.xml.expect(
            '{DAV:}lockinfo',
            body
          )

          lock_info = LockInfo.new

          lock_info.owner = result.owner
          lock_info.token = UuidUtil.uuid
          lock_info.scope = result.scope

          lock_info
        end

        public

        # Returns a bunch of meta-data about the plugin.
        #
        # Providing this information is optional, and is mainly displayed by the
        # Browser plugin.
        #
        # The description key in the returned array may contain html and will not
        # be sanitized.
        #
        # @return array
        def plugin_info
          {
            'name'        => plugin_name,
            'description' => 'The locks plugin turns this server into a class-2 WebDAV server and adds support for LOCK and UNLOCK',
            'link'        => 'http://sabre.io/dav/locks/'
          }
        end
      end
    end
  end
end
