module Tilia
  module DavAcl
    # SabreDAV ACL Plugin
    #
    # This plugin provides functionality to enforce ACL permissions.
    # ACL is defined in RFC3744.
    #
    # In addition it also provides support for the {DAV:}current-user-principal
    # property, defined in RFC5397 and the {DAV:}expand-property report, as
    # defined in RFC3253.
    class Plugin < Dav::ServerPlugin
      # Recursion constants
      #
      # This only checks the base node
      R_PARENT = 1

      # Recursion constants
      #
      # This checks every node in the tree
      R_RECURSIVE = 2

      # Recursion constants
      #
      # This checks every parentnode in the tree, but not leaf-nodes.
      R_RECURSIVEPARENTS = 3

      protected

      # Reference to server object.
      #
      # @var Sabre\DAV\Server
      attr_accessor :server

      public

      # List of urls containing principal collections.
      # Modify this if your principals are located elsewhere.
      #
      # @var array
      attr_accessor :principal_collection_set

      # By default ACL is only enforced for nodes that have ACL support (the
      # ones that implement IACL). For any other node, access is
      # always granted.
      #
      # To override this behaviour you can turn this setting off. This is useful
      # if you plan to fully support ACL in the entire tree.
      #
      # @var bool
      attr_accessor :allow_access_to_nodes_without_acl

      # By default nodes that are inaccessible by the user, can still be seen
      # in directory listings (PROPFIND on parent with Depth: 1)
      #
      # In certain cases it's desirable to hide inaccessible nodes. Setting this
      # to true will cause these nodes to be hidden from directory listings.
      #
      # @var bool
      attr_accessor :hide_nodes_from_listings

      # This list of properties are the properties a client can search on using
      # the {DAV:}principal-property-search report.
      #
      # The keys are the property names, values are descriptions.
      #
      # @var array
      attr_accessor :principal_search_property_set

      # Any principal uri's added here, will automatically be added to the list
      # of ACL's. They will effectively receive {DAV:}all privileges, as a
      # protected privilege.
      #
      # @var array
      attr_accessor :admin_principals

      # Returns a list of features added by this plugin.
      #
      # This list is used in the response of a HTTP OPTIONS request.
      #
      # @return array
      def features
        ['access-control', 'calendarserver-principal-property-search']
      end

      # Returns a list of available methods for a given url
      #
      # @param string uri
      # @return array
      def methods(_uri)
        ['ACL']
      end

      # Returns a plugin name.
      #
      # Using this name other plugins will be able to access other plugins
      # using Sabre\DAV\Server::getPlugin
      #
      # @return string
      def plugin_name
        'acl'
      end

      # Returns a list of reports this plugin supports.
      #
      # This will be used in the {DAV:}supported-report-set property.
      # Note that you still need to subscribe to the 'report' event to actually
      # implement them
      #
      # @param string uri
      # @return array
      def supported_report_set(_uri)
        [
          '{DAV:}expand-property',
          '{DAV:}principal-property-search',
          '{DAV:}principal-search-property-set'
        ]
      end

      # Checks if the current user has the specified privilege(s).
      #
      # You can specify a single privilege, or a list of privileges.
      # This method will throw an exception if the privilege is not available
      # and return true otherwise.
      #
      # @param string uri
      # @param array|string privileges
      # @param int recursion
      # @param bool throw_exceptions if set to false, this method won't throw exceptions.
      # @throws Tilia::DavAcl::Exception\NeedPrivileges
      # @return bool
      def check_privileges(uri, privileges, _recursion = R_PARENT, throw_exceptions = true)
        privileges = [privileges] unless privileges.is_a?(Array)

        acl = current_user_privilege_set(uri)

        if acl.nil?
          if @allow_access_to_nodes_without_acl
            return true
          else
            if throw_exceptions
              fail Exception::NeedPrivileges.new(uri, privileges)
            else
              return false
            end
          end
        end

        failed = []
        privileges.each do |priv|
          failed << priv unless acl.include?(priv)
        end

        if failed.any?
          if throw_exceptions
            fail Exception::NeedPrivileges.new(uri, failed)
          else
            return false
          end
        end

        true
      end

      # Returns the standard users' principal.
      #
      # This is one authorative principal url for the current user.
      # This method will return null if the user wasn't logged in.
      #
      # @return string|null
      def current_user_principal
        auth_plugin = @server.plugin('auth')
        return nil if auth_plugin.nil?

        # @var auth_plugin Sabre\DAV\Auth\Plugin
        auth_plugin.current_principal
      end

      # Returns a list of principals that's associated to the current
      # user, either directly or through group membership.
      #
      # @return array
      def current_user_principals
        current_user = current_user_principal

        return [] if current_user.nil?

        [current_user] + principal_membership(current_user)
      end

      protected

      # This array holds a cache for all the principals that are associated with
      # a single principal.
      #
      # @var array
      attr_accessor :principal_membership_cache

      public

      # Returns all the principal groups the specified principal is a member of.
      #
      # @param string principal
      # @return array
      def principal_membership(main_principal)
        # First check our cache
        return @principal_membership_cache[main_principal] if @principal_membership_cache.key?(main_principal)

        check = [main_principal]
        principals = []

        while check.size > 0
          principal = check.shift

          node = @server.tree.node_for_path(principal)
          next unless node.is_a?(IPrincipal)
          node.group_membership.each do |group_member|
            unless principals.include?(group_member)
              check << group_member
              principals << group_member
            end
          end
        end

        # Store the result in the cache
        @principal_membership_cache[main_principal] = principals

        principals
      end

      # Returns the supported privilege structure for this ACL plugin.
      #
      # See RFC3744 for more details. Currently we default on a simple,
      # standard structure.
      #
      # You can either get the list of privileges by a uri (path) or by
      # specifying a Node.
      #
      # @param string|INode node
      # @return array
      def supported_privilege_set(node)
        node = @server.tree.node_for_path(node) if node.is_a?(String)

        if node.is_a?(IAcl)
          result = node.supported_privilege_set

          return result if result && result.any?
        end

        self.class.default_supported_privilege_set
      end

      # Returns a fairly standard set of privileges, which may be useful for
      # other systems to use as a basis.
      #
      # @return array
      def self.default_supported_privilege_set
        {
          'privilege'  => '{DAV:}all',
          'abstract'   => true,
          'aggregates' => [
            {
              'privilege'  => '{DAV:}read',
              'aggregates' => [
                {
                  'privilege' => '{DAV:}read-acl',
                  'abstract'  => false
                },
                {
                  'privilege' => '{DAV:}read-current-user-privilege-set',
                  'abstract'  => false
                }
              ]
            }, # {DAV:}read
            {
              'privilege'  => '{DAV:}write',
              'aggregates' => [
                {
                  'privilege' => '{DAV:}write-acl',
                  'abstract'  => false
                },
                {
                  'privilege' => '{DAV:}write-properties',
                  'abstract'  => false
                },
                {
                  'privilege' => '{DAV:}write-content',
                  'abstract'  => false
                },
                {
                  'privilege' => '{DAV:}bind',
                  'abstract'  => false
                },
                {
                  'privilege' => '{DAV:}unbind',
                  'abstract'  => false
                },
                {
                  'privilege' => '{DAV:}unlock',
                  'abstract'  => false
                }
              ]
            }, # {DAV:}write
          ]
        } # {DAV:}all
      end

      # Returns the supported privilege set as a flat list
      #
      # This is much easier to parse.
      #
      # The returned list will be index by privilege name.
      # The value is a struct containing the following properties:
      #   - aggregates
      #   - abstract
      #   - concrete
      #
      # @param string|INode node
      # @return array
      def flat_privilege_set(node)
        privs = supported_privilege_set(node)

        fps_traverse = lambda do |priv, concrete, flat|
          my_priv = {
            'privilege'  => priv['privilege'],
            'abstract'   => priv.key?('abstract') && priv['abstract'],
            'aggregates' => [],
            'concrete'   => priv['abstract'] ? concrete : priv['privilege']
          }

          if priv.key?('aggregates')
            priv['aggregates'].each do |sub_priv|
              my_priv['aggregates'] << sub_priv['privilege']
            end
          end

          flat[priv['privilege']] = my_priv

          if priv.key?('aggregates')
            priv['aggregates'].each do |sub_priv|
              fps_traverse.call(sub_priv, my_priv['concrete'], flat)
            end
          end
        end

        flat = {}
        fps_traverse.call(privs, nil, flat)

        flat
      end

      # Returns the full ACL list.
      #
      # Either a uri or a INode may be passed.
      #
      # null will be returned if the node doesn't support ACLs.
      #
      # @param string|DAV\INode node
      # @return array
      def acl(node)
        node = @server.tree.node_for_path(node) if node.is_a?(String)

        return nil unless node.is_a?(IAcl)

        acl = node.acl
        @admin_principals.each do |admin_principal|
          acl << {
            'principal' => admin_principal,
            'privilege' => '{DAV:}all',
            'protected' => true
          }
        end

        acl
      end

      # Returns a list of privileges the current user has
      # on a particular node.
      #
      # Either a uri or a DAV\INode may be passed.
      #
      # null will be returned if the node doesn't support ACLs.
      #
      # @param string|DAV\INode node
      # @return array
      def current_user_privilege_set(node)
        node = @server.tree.node_for_path(node) if node.is_a?(String)

        acl = acl(node)

        return nil if acl.nil?

        principals = current_user_principals

        collected = []

        acl.each do |ace|
          principal = ace['principal']

          case principal
          when '{DAV:}owner'
            owner = node.owner
            collected << ace if owner && principals.include?(owner)
          # 'all' matches for every user

          # 'authenticated' matched for every user that's logged in.
          # Since it's not possible to use ACL while not being logged
          # in, this is also always true.
          when '{DAV:}all', '{DAV:}authenticated'
            collected << ace
          # 'unauthenticated' can never occur either, so we simply
          # ignore these.
          when '{DAV:}unauthenticated'
            # noop
          else
            collected << ace if principals.include?(ace['principal'])
          end
        end

        # Now we deduct all aggregated privileges.
        flat = flat_privilege_set(node)

        collected2 = []
        while collected.size > 0
          current = collected.pop
          collected2 << current['privilege']

          flat[current['privilege']]['aggregates'].each do |sub_priv|
            collected2 << sub_priv
            collected << flat[sub_priv]
          end
        end

        collected2.uniq
      end

      # Returns a principal based on its uri.
      #
      # Returns null if the principal could not be found.
      #
      # @param string uri
      # @return null|string
      def principal_by_uri(uri)
        result = nil
        collections = @principal_collection_set
        collections.each do |collection|
          principal_collection = @server.tree.node_for_path(collection)
          unless principal_collection.is_a?(IPrincipalCollection)
            # Not a principal collection, we're simply going to ignore
            # this.
            next
          end

          result = principal_collection.find_by_uri(uri)
          return result unless result.blank?
        end

        nil
      end

      # Principal property search
      #
      # This method can search for principals matching certain values in
      # properties.
      #
      # This method will return a list of properties for the matched properties.
      #
      # @param array search_properties    The properties to search on. This is a
      #                                   key-value list. The keys are property
      #                                   names, and the values the strings to
      #                                   match them on.
      # @param array requested_properties This is the list of properties to
      #                                   return for every match.
      # @param string collection_uri      The principal collection to search on.
      #                                   If this is ommitted, the standard
      #                                   principal collection-set will be used.
      # @param string test               "allof" to use AND to search the
      #                                   properties. 'anyof' for OR.
      # @return array     This method returns an array structure similar to
      #                  Sabre\DAV\Server::getPropertiesForPath. Returned
      #                  properties are index by a HTTP status code.
      def principal_search(search_properties, requested_properties, collection_uri = nil, test = 'allof')
        if collection_uri
          uris = [collection_uri]
        else
          uris = @principal_collection_set
        end

        lookup_results = []
        uris.each do |uri|
          principal_collection = @server.tree.node_for_path(uri)
          unless principal_collection.is_a?(IPrincipalCollection)
            # Not a principal collection, we're simply going to ignore
            # this.
            next
          end

          results = principal_collection.search_principals(search_properties, test)
          results.each do |result|
            lookup_results << uri.gsub(%r{/+$}, '') + '/' + result
          end
        end

        matches = []

        lookup_results.each do |lookup_result|
          matches << @server.properties_for_path(lookup_result, requested_properties, 0).first
        end

        matches
      end

      # Sets up the plugin
      #
      # This method is automatically called by the server class.
      #
      # @param DAV\Server server
      # @return void
      def setup(server)
        @server = server
        @server.on('propFind',            method(:prop_find), 20)
        @server.on('beforeMethod',        method(:before_method), 20)
        @server.on('beforeBind',          method(:before_bind), 20)
        @server.on('beforeUnbind',        method(:before_unbind), 20)
        @server.on('propPatch',           method(:prop_patch))
        @server.on('beforeUnlock',        method(:before_unlock), 20)
        @server.on('report',              method(:report))
        @server.on('method:ACL',          method(:http_acl))
        @server.on('onHTMLActionsPanel',  method(:html_actions_panel))

        @server.protected_properties += [
          '{DAV:}alternate-URI-set',
          '{DAV:}principal-URL',
          '{DAV:}group-membership',
          '{DAV:}principal-collection-set',
          '{DAV:}current-user-principal',
          '{DAV:}supported-privilege-set',
          '{DAV:}current-user-privilege-set',
          '{DAV:}acl',
          '{DAV:}acl-restrictions',
          '{DAV:}inherited-acl-set',
          '{DAV:}owner',
          '{DAV:}group'
        ]

        # Automatically mapping nodes implementing IPrincipal to the
        # {DAV:}principal resourcetype.
        @server.resource_type_mapping[Tilia::DavAcl::IPrincipal] = '{DAV:}principal'

        # Mapping the group-member-set property to the HrefList property
        # class.
        @server.xml.element_map['{DAV:}group-member-set'] = Tilia::Dav::Xml::Property::Href
        @server.xml.element_map['{DAV:}acl'] = Tilia::DavAcl::Xml::Property::Acl
        @server.xml.element_map['{DAV:}expand-property'] = Tilia::DavAcl::Xml::Request::ExpandPropertyReport
        @server.xml.element_map['{DAV:}principal-property-search'] = Tilia::DavAcl::Xml::Request::PrincipalPropertySearchReport
        @server.xml.element_map['{DAV:}principal-search-property-set'] = Tilia::DavAcl::Xml::Request::PrincipalSearchPropertySetReport
      end

      # {{{ Event handlers

      # Triggered before any method is handled
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return void
      def before_method(request, _response)
        method = request.method
        path = request.path

        exists = @server.tree.node_exists(path)

        # If the node doesn't exists, none of these checks apply
        return unless exists

        case method
        when 'GET', 'HEAD', 'OPTIONS'
          # For these 3 we only need to know if the node is readable.
          check_privileges(path, '{DAV:}read')
        when 'PUT', 'LOCK', 'UNLOCK'
          # This method requires the write-content priv if the node
          # already exists, and bind on the parent if the node is being
          # created.
          # The bind privilege is handled in the beforeBind event.
          check_privileges(path, '{DAV:}write-content')
        when 'PROPPATCH'
          check_privileges(path, '{DAV:}write-properties')
        when 'ACL'
          check_privileges(path, '{DAV:}write-acl')
        when 'COPY', 'MOVE'
          # Copy requires read privileges on the entire source tree.
          # If the target exists write-content normally needs to be
          # checked, however, we're deleting the node beforehand and
          # creating a new one after, so this is handled by the
          # beforeUnbind event.
          #
          # The creation of the new node is handled by the beforeBind
          # event.
          #
          # If MOVE is used beforeUnbind will also be used to check if
          # the sourcenode can be deleted.
          check_privileges(path, '{DAV:}read', R_RECURSIVE)
        end
      end

      # Triggered before a new node is created.
      #
      # This allows us to check permissions for any operation that creates a
      # new node, such as PUT, MKCOL, MKCALENDAR, LOCK, COPY and MOVE.
      #
      # @param string uri
      # @return void
      def before_bind(uri)
        parent_uri = Uri.split(uri)[0]
        check_privileges(parent_uri, '{DAV:}bind')
      end

      # Triggered before a node is deleted
      #
      # This allows us to check permissions for any operation that will delete
      # an existing node.
      #
      # @param string uri
      # @return void
      def before_unbind(uri)
        parent_uri = Uri.split(uri)[0]
        check_privileges(parent_uri, '{DAV:}unbind', R_RECURSIVEPARENTS)
      end

      # Triggered before a node is unlocked.
      #
      # @param string uri
      # @param DAV\Locks\LockInfo lock
      # @TODO: not yet implemented
      # @return void
      def before_unlock(uri, lock)
        # noop
      end

      # Triggered before properties are looked up in specific nodes.
      #
      # @param DAV\PropFind prop_find
      # @param DAV\INode node
      # @param array requested_properties
      # @param array returned_properties
      # @TODO really should be broken into multiple methods, or even a class.
      # @return bool
      def prop_find(prop_find, node)
        path = prop_find.path

        # Checking the read permission
        unless check_privileges(path, '{DAV:}read', R_PARENT, false)
          # User is not allowed to read properties

          # Returning false causes the property-fetching system to pretend
          # that the node does not exist, and will cause it to be hidden
          # from listings such as PROPFIND or the browser plugin.
          return false if @hide_nodes_from_listings

          # Otherwise we simply mark every property as 403.
          prop_find.requested_properties.each do |requested_property|
            prop_find.set(requested_property, nil, 403)
          end

          return true
        end

        # Adding principal properties
        if node.is_a?(IPrincipal)
          prop_find.handle(
            '{DAV:}alternate-URI-set',
            -> { Dav::Xml::Property::Href.new(node.alternate_uri_set) }
          )
          prop_find.handle(
            '{DAV:}principal-URL',
            -> { Dav::Xml::Property::Href.new("#{node.principal_url}/") }
          )
          prop_find.handle(
            '{DAV:}group-member-set',
            lambda do
              members = node.group_member_set
              members = members.map { |m| m.gsub(%r{/+$}, '') + '/' }
              Dav::Xml::Property::Href.new(members)
            end
          )
          prop_find.handle(
            '{DAV:}group-membership',
            lambda do
              members = node.group_membership
              members = members.map { |m| m.gsub(%r{/+$}, '') + '/' }
              Dav::Xml::Property::Href.new(members)
            end
          )
          prop_find.handle(
            '{DAV:}displayname',
            node.method(:displayname)
          )
        end

        prop_find.handle(
          '{DAV:}principal-collection-set',
          lambda do
            val = @principal_collection_set
            # Ensuring all collections end with a slash
            val = val.map { |v| v + '/' }
            Dav::Xml::Property::Href.new(val)
          end
        )
        prop_find.handle(
          '{DAV:}current-user-principal',
          lambda do
            url = current_user_principal
            if url
              return Xml::Property::Principal.new(Xml::Property::Principal::HREF, url + '/')
            else
              return Xml::Property::Principal.new(Xml::Property::Principal::UNAUTHENTICATED)
            end
          end
        )
        prop_find.handle(
          '{DAV:}supported-privilege-set',
          lambda do
            Xml::Property::SupportedPrivilegeSet.new(supported_privilege_set(node))
          end
        )
        prop_find.handle(
          '{DAV:}current-user-privilege-set',
          lambda do
            if !check_privileges(path, '{DAV:}read-current-user-privilege-set', R_PARENT, false)
              prop_find.set('{DAV:}current-user-privilege-set', null, 403)
            else
              val = current_user_privilege_set(node)
              if val.nil?
                return nil
              else
                return Xml::Property::CurrentUserPrivilegeSet.new(val)
              end
            end
          end
        )
        prop_find.handle(
          '{DAV:}acl',
          lambda do
            # The ACL property contains all the permissions
            if !check_privileges(path, '{DAV:}read-acl', R_PARENT, false)
              prop_find.set('{DAV:}acl', nil, 403)
            else
              acl = acl(node)
              if acl.nil?
                return nil
              else
                return Xml::Property::Acl.new(acl)
              end
            end
          end
        )
        prop_find.handle(
          '{DAV:}acl-restrictions',
          -> { Xml::Property::AclRestrictions.new }
        )

        # Adding ACL properties
        if node.is_a?(IAcl)
          prop_find.handle(
            '{DAV:}owner',
            -> { Dav::Xml::Property::Href.new(node.owner + '/') }
          )
        end
      end

      # This method intercepts PROPPATCH methods and make sure the
      # group-member-set is updated correctly.
      #
      # @param string path
      # @param DAV\PropPatch prop_patch
      # @return void
      def prop_patch(path, prop_patch)
        prop_patch.handle(
          '{DAV:}group-member-set',
          lambda do |value|
            if value.nil?
              member_set = []
            elsif value.is_a?(Dav::Xml::Property::Href)
              member_set = value.hrefs.map { |h| @server.calculate_uri(h) }
            else
              fail Dav::Exception, 'The group-member-set property MUST be an instance of Sabre\DAV\Property\HrefList or null'
            end

            node = @server.tree.node_for_path(path)
            unless node.is_a?(IPrincipal)
              # Fail
              return false
            end

            node.group_member_set = member_set
            # We must also clear our cache, just in case

            @principal_membership_cache = {}

            return true
          end
        )
      end

      # This method handles HTTP REPORT requests
      #
      # @param string report_name
      # @param mixed report
      # @param mixed path
      # @return bool
      def report(report_name, report, _path)
        case report_name
        when '{DAV:}principal-property-search'
          @server.transaction_type = 'report-principal-property-search'
          principal_property_search_report(report)
          return false
        when '{DAV:}principal-search-property-set'
          @server.transaction_type = 'report-principal-search-property-set'
          principal_search_property_set_report(report)
          return false
        when '{DAV:}expand-property'
          @server.transaction_type = 'report-expand-property'
          expand_property_report(report)
          return false
        end
      end

      # This method is responsible for handling the 'ACL' event.
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_acl(request, response)
        path = request.path
        body = request.body_as_string

        fail Dav::Exception::BadRequest, 'XML body expected in ACL request' if body.blank?

        acl = @server.xml.expect('{DAV:}acl', body)
        new_acl = acl.privileges

        # Normalizing urls
        new_acl.each_with_index do |new_ace, k|
          new_acl[k]['principal'] = @server.calculate_uri(new_ace['principal'])
        end
        node = @server.tree.node_for_path(path)

        fail Dav::Exception::MethodNotAllowed, 'This node does not support the ACL method' unless node.is_a?(IAcl)

        old_acl = acl(node)

        supported_privileges = flat_privilege_set(node)

        # Checking if protected principals from the existing principal set are
        # not overwritten.
        old_acl.each do |old_ace|
          next if !old_ace.key?('protected') || !old_ace['protected']

          found = false
          new_acl.each do |new_ace|
            next unless new_ace['privilege'] == old_ace['privilege'] &&
                        new_ace['principal'] == old_ace['principal'] &&
                        new_ace['protected']
            found = true
          end

          fail Exception::AceConflict, 'This resource contained a protected {DAV:}ace, but this privilege did not occur in the ACL request' unless found
        end

        new_acl.each do |new_ace|
          # Do we recognize the privilege
          fail Exception::NotSupportedPrivilege, "The privilege you specified (#{new_ace['privilege']}) is not recognized by this server" unless supported_privileges.key?(new_ace['privilege'])

          fail Exception::NoAbstract, "The privilege you specified (#{new_ace['privilege']}) is an abstract privilege" if supported_privileges[new_ace['privilege']]['abstract']

          # Looking up the principal
          begin
            principal = @server.tree.node_for_path(new_ace['principal'])
          rescue Dav::Exception::NotFound => e
            raise Exception::NotRecognizedPrincipal, "The specified principal (#{new_ace['principal']}) does not exist"
          end

          fail Exception::NotRecognizedPrincipal, "The specified uri (#{new_ace['principal']}) is not a principal" unless principal.is_a?(IPrincipal)
        end
        node.acl = new_acl

        response.status = 200

        # Breaking the event chain, because we handled this method.
        false
      end

      # }}}

      # Reports {{{

      protected

      # The expand-property report is defined in RFC3253 section 3-8.
      #
      # This report is very similar to a standard PROPFIND. The difference is
      # that it has the additional ability to look at properties containing a
      # {DAV:}href element, follow that property and grab additional elements
      # there.
      #
      # Other rfc's, such as ACL rely on this report, so it made sense to put
      # it in this plugin.
      #
      # @param Xml\Request\ExpandPropertyReport report
      # @return void
      def expand_property_report(report)
        depth = @server.http_depth(0)
        request_uri = @server.request_uri

        result = expand_properties(request_uri, report.properties, depth)

        xml = @server.xml.write(
          '{DAV:}multistatus',
          Dav::Xml::Response::MultiStatus.new(result),
          @server.base_uri
        )
        @server.http_response.update_header('Content-Type', 'application/xml; charset=utf-8')
        @server.http_response.status = 207
        @server.http_response.body = xml
      end

      # This method expands all the properties and returns
      # a list with property values
      #
      # @param array path
      # @param array requested_properties the list of required properties
      # @param int depth
      # @return array
      def expand_properties(path, requested_properties, depth)
        found_properties = @server.properties_for_path(path, requested_properties.keys, depth)

        result = []
        found_properties.each do |node|
          requested_properties.each do |property_name, child_requested_properties|
            # We're only traversing if sub-properties were requested
            next unless child_requested_properties
            next if child_requested_properties.size == 0

            # We only have to do the expansion if the property was found
            # and it contains an href element.
            next unless node[200].key?(property_name)

            next unless node[200][property_name].is_a?(Dav::Xml::Property::Href)

            child_hrefs = node[200][property_name].hrefs
            child_props = []

            child_hrefs.each do |href|
              # Gathering the result of the children
              child_props << {
                'name'  => '{DAV:}response',
                'value' => expand_properties(href, child_requested_properties, 0)[0]
              }
            end

            # Replacing the property with its expannded form.
            node[200][property_name] = child_props
          end

          result << Dav::Xml::Element::Response.new(node['href'], node)
        end

        result
      end

      # principalSearchPropertySetReport
      #
      # This method responsible for handing the
      # {DAV:}principal-search-property-set report. This report returns a list
      # of properties the client may search on, using the
      # {DAV:}principal-property-search report.
      #
      # @param Xml\Request\PrincipalSearchPropertySetReport report
      # @return void
      def principal_search_property_set_report(_report)
        http_depth = @server.http_depth(0)

        fail Dav::Exception::BadRequest, 'This report is only defined when Depth: 0' unless http_depth == 0

        writer = @server.xml.writer
        writer.open_memory
        writer.start_document

        writer.start_element('{DAV:}principal-search-property-set')

        @principal_search_property_set.each do |property_name, description|
          writer.start_element('{DAV:}principal-search-property')
          writer.start_element('{DAV:}prop')

          writer.write_element(property_name)

          writer.end_element # prop

          unless description.blank?
            writer.write(
              [ # Hash in Array!
                'name'       => '{DAV:}description',
                'value'      => description,
                'attributes' => { 'xml:lang' => 'en' }
              ]
            )
          end

          writer.end_element # principal-search-property
        end

        writer.end_element # principal-search-property-set

        @server.http_response.update_header('Content-Type', 'application/xml; charset=utf-8')
        @server.http_response.status = 200
        @server.http_response.body = writer.output_memory
      end

      # principalPropertySearchReport
      #
      # This method is responsible for handing the
      # {DAV:}principal-property-search report. This report can be used for
      # clients to search for groups of principals, based on the value of one
      # or more properties.
      #
      # @param Xml\Request\PrincipalPropertySearchReport report
      # @return void
      def principal_property_search_report(report)
        uri = nil

        uri = @server.http_request.path unless report.apply_to_principal_collection_set

        fail Dav::Exception::BadRequest, 'Depth must be 0' unless @server.http_depth('0') == 0

        result = principal_search(
          report.search_properties,
          report.properties,
          uri,
          report.test
        )

        prefer = @server.http_prefer

        @server.http_response.status = 207
        @server.http_response.update_header('Content-Type', 'application/xml; charset=utf-8')
        @server.http_response.update_header('Vary', 'Brief,Prefer')
        @server.http_response.body = @server.generate_multi_status(result, prefer['return'] == 'minimal')
      end

      public

      # }}}

      # This method is used to generate HTML output for the
      # DAV\Browser\Plugin. This allows us to generate an interface users
      # can use to create new calendars.
      #
      # @param DAV\INode node
      # @param [Box] output
      # @return bool
      def html_actions_panel(node, output)
        return false unless node.is_a?(PrincipalCollection)

        output.value << <<HTML
<tr><td colspan="2"><form method="post" action="">
<h3>Create new principal</h3>
<input type="hidden" name="sabreAction" value="mkcol" />
<input type="hidden" name="resourceType" value="{DAV:}principal" />
<label>Name (uri):</label> <input type="text" name="name" /><br />
<label>Display name:</label> <input type="text" name="{DAV:}displayname" /><br />
<label>Email address:</label> <input type="text" name="{http://sabredav*DOT*org/ns}email-address" /><br />
<input type="submit" value="create" />
</form>
</td></tr>
HTML

        false
      end

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
          'description' => 'Adds support for WebDAV ACL (rfc3744)',
          'link'        => 'http://sabre.io/dav/acl/'
        }
      end

      # TODO: document
      def initialize
        @principal_collection_set = ['principals']
        @allow_access_to_nodes_without_acl = true
        @hide_nodes_from_listings = false
        @principal_search_property_set = {
          '{DAV:}displayname'                     => 'Display name',
          '{http://sabredav.org/ns}email-address' => 'Email address'
        }
        @admin_principals = []
        @principal_membership_cache = {}
      end
    end
  end
end
