module Tilia
  module CalDav
    module Principal
      # CalDAV principal
      #
      # This is a standard user-principal for CalDAV. This principal is also a
      # collection and returns the caldav-proxy-read and caldav-proxy-write child
      # principals.
      class User < DavAcl::Principal
        include Dav::ICollection

        # Creates a new file in the directory
        #
        # @param string name Name of the file
        # @param resource data Initial payload, passed as a readable stream resource.
        # @throws DAV\Exception\Forbidden
        # @return void
        def create_file(name, _data = nil)
          fail Dav::Exception::Forbidden, "Permission denied to create file (filename #{name})"
        end

        # Creates a new subdirectory
        #
        # @param string name
        # @throws DAV\Exception\Forbidden
        # @return void
        def create_directory(_name)
          fail Dav::Exception::Forbidden, 'Permission denied to create directory'
        end

        # Returns a specific child node, referenced by its name
        #
        # @param string name
        # @return DAV\INode
        def child(name)
          principal = @principal_backend.principal_by_path(principal_url + '/' + name)

          fail Dav::Exception::NotFound, "Node with name #{name} was not found" unless principal

          return ProxyRead.new(@principal_backend, @principal_properties) if name == 'calendar-proxy-read'
          return ProxyWrite.new(@principal_backend, @principal_properties) if name == 'calendar-proxy-write'

          fail Dav::Exception::NotFound, "Node with name #{name} was not found"
        end

        # Returns an array with all the child nodes
        #
        # @return DAV\INode[]
        def children
          r = []

          r << ProxyRead.new(@principal_backend, @principal_properties) if @principal_backend.principal_by_path(principal_url + '/calendar-proxy-read')
          r << ProxyWrite.new(@principal_backend, @principal_properties) if @principal_backend.principal_by_path(principal_url + '/calendar-proxy-write')

          r
        end

        # Returns whether or not the child node exists
        #
        # @param string name
        # @return bool
        def child_exists(name)
          child(name)
          return true
        rescue Dav::Exception::NotFound
          return false
        end

        # Returns a list of ACE's for this node.
        #
        # Each ACE has the following properties:
        #   * 'privilege', a string such as {DAV:}read or {DAV:}write. These are
        #     currently the only supported privileges
        #   * 'principal', a url to the principal who owns the node
        #   * 'protected' (optional), indicating that this ACE is not allowed to
        #      be updated.
        #
        # @return array
        def acl
          acl = super
          acl << {
            'privilege' => '{DAV:}read',
            'principal' => @principal_properties['uri'] + '/calendar-proxy-read',
            'protected' => true
          }
          acl << {
            'privilege' => '{DAV:}read',
            'principal' => @principal_properties['uri'] + '/calendar-proxy-write',
            'protected' => true
          }
          acl
        end
      end
    end
  end
end
