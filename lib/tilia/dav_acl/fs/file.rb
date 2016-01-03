module Tilia
  module DavAcl
    module Fs
      # This is an ACL-enabled file node.
      class File < Dav::FsExt::File
        include IAcl

        protected

        # A list of ACL rules.
        #
        # @var array
        attr_accessor :acl

        # Owner uri, or null for no owner.
        #
        # @var string|null
        attr_accessor :owner

        public

        # Constructor
        #
        # @param string path on-disk path.
        # @param array acl ACL rules.
        # @param string|null owner principal owner string.
        def initialize(path, acl, owner = nil)
          super(path)
          @acl = acl
          @owner = owner
        end

        # Returns the owner principal
        #
        # This must be a url to a principal, or null if there's no owner
        #
        # @return string|null
        attr_reader :owner

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
        attr_reader :acl

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
