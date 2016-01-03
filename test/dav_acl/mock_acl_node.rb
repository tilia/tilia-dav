module Tilia
  module DavAcl
    class MockAclNode < Dav::Node
      include IAcl

      attr_accessor :name
      attr_accessor :acl

      def initialize(name, acl = [])
        @name = name
        @acl = acl
      end

      def owner
        nil
      end

      def group
        nil
      end

      def supported_privilege_set
        nil
      end
    end
  end
end
