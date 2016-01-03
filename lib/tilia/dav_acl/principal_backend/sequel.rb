module Tilia
  module DavAcl
    module PrincipalBackend
      # PDO principal backend
      #
      # This backend assumes all principals are in a single collection. The default collection
      # is 'principals/', but this can be overriden.
      class Sequel < AbstractBackend
        include CreatePrincipalSupport

        # PDO table name for 'principals'
        #
        # @var string
        attr_accessor :table_name

        # PDO table name for 'group members'
        #
        # @var string
        attr_accessor :group_members_table_name

        protected

        # pdo
        #
        # @var PDO
        attr_accessor :sequel

        # A list of additional fields to support
        #
        # @var array
        attr_accessor :field_map

        public

        # Sets up the backend.
        #
        # @param PDO pdo
        def initialize(sequel)
          @table_name = 'principals'
          @group_members_table_name = 'groupmembers'
          @field_map = {
            # This property can be used to display the users' real name.
            '{DAV:}displayname' => {
              'dbField' => 'displayname'
            },

            # This is the users' primary email-address.
            '{http://sabredav.org/ns}email-address' => {
              'dbField' => 'email'
            }
          }
          @sequel = sequel
        end

        # Returns a list of principals based on a prefix.
        #
        # This prefix will often contain something like 'principals'. You are only
        # expected to return principals that are in this base path.
        #
        # You are expected to return at least a 'uri' for every user, you can
        # return any additional properties if you wish so. Common properties are:
        #   {DAV:}displayname
        #   {http://sabredav.org/ns}email-address - This is a custom SabreDAV
        #     field that's actualy injected in a number of other properties. If
        #     you have an email address, use this property.
        #
        # @param string prefix_path
        # @return array
        def principals_by_prefix(prefix_path)
          fields = ['uri']

          @field_map.each do |_key, value|
            fields << value['dbField']
          end

          principals = []
          @sequel.fetch("SELECT #{fields.join(',')} FROM #{@table_name}") do |row|
            # Checking if the principal is in the prefix
            row_prefix = Http::UrlUtil.split_path(row[:uri])[0]

            next unless row_prefix == prefix_path

            principal = {
              'uri' => row[:uri]
            }

            @field_map.each do |key, value|
              unless row[value['dbField'].to_sym].blank?
                principal[key] = row[value['dbField'].to_sym]
              end
            end
            principals << principal
          end

          principals
        end

        # Returns a specific principal, specified by it's path.
        # The returned structure should be the exact same as from
        # getPrincipalsByPrefix.
        #
        # @param string path
        # @return array
        def principal_by_path(path)
          fields = [
            'id',
            'uri'
          ]

          @field_map.each do |_key, value|
            fields << value['dbField']
          end

          ds = @sequel["SELECT #{fields.join(',')}  FROM #{@table_name} WHERE uri = ?", path]
          row = ds.all.first

          return unless row

          principal = {
            'id'  => row[:id],
            'uri' => row[:uri]
          }

          @field_map.each do |key, value|
            if row[value['dbField'].to_sym]
              principal[key] = row[value['dbField'].to_sym]
            end
          end

          principal
        end

        # Updates one ore more webdav properties on a principal.
        #
        # The list of mutations is stored in a Sabre\DAV\PropPatch object.
        # To do the actual updates, you must tell this object which properties
        # you're going to process with the handle method.
        #
        # Calling the handle method is like telling the PropPatch object "I
        # promise I can handle updating this property".
        #
        # Read the PropPatch documenation for more info and examples.
        #
        # @param string path
        # @param DAV\PropPatch prop_patch
        def update_principal(path, prop_patch)
          prop_patch.handle(
            @field_map.keys,
            lambda do |properties|
              query = "UPDATE #{@table_name} SET "

              first = true
              values = {}
              properties.each do |key, value|
                db_field = @field_map[key]['dbField']

                query << ', ' unless first
                first = false
                query << "#{db_field} = :#{db_field}"
                values[db_field.to_sym] = value
              end

              query << ' WHERE uri = :uri'
              values[:uri] = path

              ds = @sequel[query, values]
              ds.update

              true
            end
          )
        end

        # This method is used to search for principals matching a set of
        # properties.
        #
        # This search is specifically used by RFC3744's principal-property-search
        # REPORT.
        #
        # The actual search should be a unicode-non-case-sensitive search. The
        # keys in searchProperties are the WebDAV property names, while the values
        # are the property values to search on.
        #
        # By default, if multiple properties are submitted to this method, the
        # various properties should be combined with 'AND'. If test is set to
        # 'anyof', it should be combined using 'OR'.
        #
        # This method should simply return an array with full principal uri's.
        #
        # If somebody attempted to search on a property the backend does not
        # support, you should simply return 0 results.
        #
        # You can also just return 0 results if you choose to not support
        # searching at all, but keep in mind that this may stop certain features
        # from working.
        #
        # @param string prefix_path
        # @param array search_properties
        # @param string test
        # @return array
        def search_principals(prefix_path, search_properties, _test = 'allof')
          query = "SELECT uri FROM #{@table_name} WHERE 1=1 "
          values = []

          search_properties.each do |property, value|
            case property
            when '{DAV:}displayname'
              query << ' AND displayname LIKE ?'
              values << "%#{value}%"
            when '{http://sabredav.org/ns}email-address'
              query << ' AND email LIKE ?'
              values << "%#{value}%"
            else
              # Unsupported property
              return []
            end
          end

          principals = []
          @sequel.fetch(query, *values) do |row|
            # Checking if the principal is in the prefix
            row_prefix = Http::UrlUtil.split_path(row[:uri])[0]
            next unless row_prefix == prefix_path

            principals << row[:uri]
          end

          principals
        end

        # Returns the list of members for a group-principal
        #
        # @param string principal
        # @return array
        def group_member_set(principal)
          principal = principal_by_path(principal)
          fail Dav::Exception, 'Principal not found' if principal.empty?

          result = []
          @sequel.fetch("SELECT principals.uri as uri FROM #{@group_members_table_name} AS groupmembers LEFT JOIN #{@table_name} AS principals ON groupmembers.member_id = principals.id WHERE groupmembers.principal_id = ?", principal['id']) do |row|
            result << row[:uri]
          end

          result
        end

        # Returns the list of groups a principal is a member of
        #
        # @param string principal
        # @return array
        def group_membership(principal)
          principal = principal_by_path(principal)
          fail Dav::Exception, 'Principal not found' if principal.empty?

          result = []
          @sequel.fetch("SELECT principals.uri as uri FROM #{@group_members_table_name} AS groupmembers LEFT JOIN #{@table_name} AS principals ON groupmembers.principal_id = principals.id WHERE groupmembers.member_id = ?", principal['id']) do |row|
            result << row[:uri]
          end

          result
        end

        # Updates the list of group members for a group principal.
        #
        # The principals should be passed as a list of uri's.
        #
        # @param string principal
        # @param array members
        # @return void
        def update_group_member_set(principal, members)
          # Grabbing the list of principal id's.
          member_ids = []
          principal_id = nil

          @sequel.fetch("SELECT id, uri FROM #{@table_name} WHERE uri IN (?#{', ?' * members.size})", principal, *members) do |row|
            if row[:uri] == principal
              principal_id = row[:id]
            else
              member_ids << row[:id]
            end
          end

          fail Dav::Exception, 'Principal not found' unless principal_id

          # Wiping out old members
          ds = @sequel["DELETE FROM #{@group_members_table_name} WHERE principal_id = ?", principal_id]
          ds.delete

          member_ids.each do |member_id|
            ds = @sequel["INSERT INTO #{@group_members_table_name} (principal_id, member_id) VALUES (?, ?)", principal_id, member_id]
            ds.insert
          end
        end

        # Creates a new principal.
        #
        # This method receives a full path for the new principal. The mkCol object
        # contains any additional webdav properties specified during the creation
        # of the principal.
        #
        # @param string path
        # @param MkCol mk_col
        # @return void
        def create_principal(path, mk_col)
          ds = @sequel["INSERT INTO #{@table_name} (uri) VALUES (?)", path]
          ds.insert

          update_principal(path, mk_col)
        end
      end
    end
  end
end
