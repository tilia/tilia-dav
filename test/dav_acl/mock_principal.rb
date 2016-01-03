module Tilia
  module DavAcl
    class MockPrincipal < Dav::Node
      include IPrincipal

      attr_accessor :name
      attr_accessor :principal_url
      attr_accessor :group_membership
      attr_accessor :group_member_set

      def initialize(name, principal_url, group_membership = [], group_member_set = [])
        @name = name
        @principal_url = principal_url
        @group_membership = group_membership
        @group_member_set = group_member_set
      end

      def displayname
        @name
      end

      def alternate_uri_set
        []
      end
    end
  end
end
