require 'fileutils'

module Tilia
  module DavAcl
    module Fs
      # This collection contains a collection for every principal.
      # It is similar to /home on many unix systems.
      #
      # The per-user collections can only be accessed by the user who owns the
      # collection.
      class HomeCollection < AbstractPrincipalCollection
        include IAcl

        # Name of this collection.
        #
        # @var string
        attr_accessor :collection_name

        protected

        # Path to where the users' files are actually stored.
        #
        # @var string
        attr_accessor :storage_path

        public

        # Creates the home collection.
        #
        # @param BackendInterface principal_backend
        # @param string storage_path Where the actual files are stored.
        # @param string principal_prefix list of principals to iterate.
        def initialize(principal_backend, storage_path, principal_prefix = 'principals')
          @collection_name = 'home'
          super(principal_backend, principal_prefix)
          @storage_path = storage_path
        end

        # Returns the name of the node.
        #
        # This is used to generate the url.
        #
        # @return string
        def name
          @collection_name
        end

        # Returns a principals' collection of files.
        #
        # The passed array contains principal information, and is guaranteed to
        # at least contain a uri item. Other properties may or may not be
        # supplied by the authentication backend.
        #
        # @param array principal_info
        # @return void
        def child_for_principal(principal_info)
          owner = principal_info['uri']
          acl = [
            {
              'privilege' => '{DAV:}read',
              'principal' => owner,
              'protected' => true
            },
            {
              'privilege' => '{DAV:}write',
              'principal' => owner,
              'protected' => true
            }
          ]

          principal_base_name = Uri.split(owner)[1]

          path = "#{@storage_path}/#{principal_base_name}"

          FileUtils.mkdir_p(path) unless ::File.directory?(path)

          Collection.new(
            path,
            acl,
            owner
          )
        end

        # Returns the owner principal
        #
        # This must be a url to a principal, or null if there's no owner
        #
        # @return string|null
        def owner
          nil
        end

        # Returns a group principal
        #
        # This must be a url to a principal, or null if there's no owner
        #
        # @return string|null
        def group
          nil
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
          [
            {
              'principal' => '{DAV:}authenticated',
              'privilege' => '{DAV:}read',
              'protected' => true
            }
          ]
        end

        # Updates the ACL
        #
        # This method will receive a list of new ACE's as an array argument.
        #
        # @param array acl
        # @return void
        def acl=(_acl)
          fail Dav::Exception::Forbidden, 'Setting ACL is not allowed here'
        end

        # Returns the list of supported privileges for this node.
        #
        # The returned data structure is a list of nested privileges.
        # See Tilia::DavAcl::Plugin::getDefaultSupportedPrivilegeSet for a simple
        # standard structure.
        #
        # If null is returned from this method, the default privilege set is used,
        # which is fine for most common usecases.
        #
        # @return array|null
        def supported_privilege_set
          nil
        end
      end
    end
  end
end
