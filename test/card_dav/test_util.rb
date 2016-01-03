module Tilia
  module CardDav
    module DatabaseUtil
      def self.backend
        backend = Backend::Sequel.new(sqlite_db)
        backend
      end

      def self.sqlite_db
        db = Backend::SequelSqliteTest.sequel

        # Inserting events through a backend class.
        backend = Backend::Sequel.new(db)
        addressbook_id = backend.create_address_book(
          'principals/user1',
          'UUID-123467',
          '{DAV:}displayname' => 'user1 addressbook',
          '{urn:ietf:params:xml:ns:carddav}addressbook-description' => 'AddressBook description'
        )
        backend.create_address_book(
          'principals/user1',
          'UUID-123468',
          '{DAV:}displayname' => 'user1 addressbook2',
          '{urn:ietf:params:xml:ns:carddav}addressbook-description' => 'AddressBook description'
        )
        backend.create_card(
          addressbook_id,
          'UUID-2345',
          test_card_data
        )
        db
      end

      def self.test_card_data
        addressbook_data = <<VCF
BEGIN:VCARD
VERSION:3.0
PRODID:-//Acme Inc.//RoadRunner 1.0//EN
FN:Wile E. Coyote
N:Coyote;Wile;Erroll;
ORG:Acme Inc.
UID:39A6B5ED-DD51-4AFE-A683-C35EE3749627
REV:2012-06-20T07:00:39+00:00
END:VCARD
VCF

        addressbook_data
      end
    end
  end
end
