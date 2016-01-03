module Tilia
  module DavAcl
    module PrincipalBackend
      # Implement this interface to add support for creating new principals to your
      # principal backend.
      #
      # @copyright Copyright (C) 2007-2015 fruux GmbH (https://fruux.com/).
      # @author Evert Pot (http://evertpot.com/)
      # @license http://sabre.io/license/ Modified BSD License
      module CreatePrincipalSupport
        include BackendInterface

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
        end
      end
    end
  end
end
