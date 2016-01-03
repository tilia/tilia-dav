module Tilia
  module DavAcl
    module PrincipalBackend
      class Mock < AbstractBackend
        attr_accessor :group_members
        attr_accessor :principals

        def initialize(principals = nil)
          @group_members = {}
          @principals = principals

          unless principals
            @principals = [
              {
                'uri'                                   => 'principals/user1',
                '{DAV:}displayname'                     => 'User 1',
                '{http://sabredav.org/ns}email-address' => 'user1.sabredav@sabredav.org',
                '{http://sabredav.org/ns}vcard-url'     => 'addressbooks/user1/book1/vcard1.vcf'
              },
              {
                'uri'               => 'principals/admin',
                '{DAV:}displayname' => 'Admin'
              },
              {
                'uri'                                   => 'principals/user2',
                '{DAV:}displayname'                     => 'User 2',
                '{http://sabredav.org/ns}email-address' => 'user2.sabredav@sabredav.org'
              }
            ]
          end
        end

        def principals_by_prefix(prefix)
          prefix = prefix.gsub(%r{^/+|/+$}, '')
          prefix << '/' unless prefix.blank?

          to_return = []
          @principals.each do |principal|
            next if !prefix.blank? && principal['uri'].index(prefix) != 0
            to_return << principal
          end

          to_return
        end

        def add_principal(principal)
          @principals << principal
        end

        def principal_by_path(path)
          principals_by_prefix('principals').each do |principal|
            return principal if principal['uri'] == path
          end
          nil
        end

        def search_principals(prefix_path, search_properties, test = 'allof')
          matches = []

          principals_by_prefix(prefix_path).each do |principal|
            skip = false
            search_properties.each do |key, value|
              unless principal.key?(key)
                skip = true
                break
              end
              unless principal[key].downcase.index(value.downcase)
                skip = true
                break
              end

              # We have a match for this searchProperty!
              if test == 'allof'
                next
              else
                break
              end
            end
            next if skip

            matches << principal['uri']
          end

          matches
        end

        def group_member_set(path)
          @group_members.key?(path) ? @group_members[path] : []
        end

        def group_membership(path)
          membership = []
          @group_members.each do |group, members|
            membership << group if members.include?(path)
          end
          membership
        end

        def update_group_member_set(path, members)
          @group_members[path] = members
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
        # @param \Sabre\DAV\PropPatch prop_patch
        def update_principal(path, prop_patch)
          value = nil
          principal_index = nil
          principal = nil

          @principals.each_with_index do |value, i|
            principal_index = i
            if value['uri'] == path
              principal = value
              break
            end
          end

          return nil unless principal

          prop_patch.handle_remaining(
            lambda do |mutations|
              mutations.each do |prop, value|
                if value.nil? && principal.key?(prop)
                  principal.delete(prop)
                else
                  principal[prop] = value
                end
              end

              @principals[principal_index] = principal

              return true
            end
          )
        end
      end
    end
  end
end
