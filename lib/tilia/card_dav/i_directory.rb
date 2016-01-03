module Tilia
  module CardDav
    # IDirectory interface
    #
    # Implement this interface to have an addressbook marked as a 'directory'. A
    # directory is an (often) global addressbook.
    #
    # A full description can be found in the IETF draft:
    #   - draft-daboo-carddav-directory-gateway
    module IDirectory
      include IAddressBook
    end
  end
end
