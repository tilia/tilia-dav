module Tilia
  module Dav
    module PropertyStorage
      module Backend
        # Propertystorage backend interface.
        #
        # Propertystorage backends must implement this interface to be used by the
        # propertystorage plugin.
        module BackendInterface
          # Fetches properties for a path.
          #
          # This method received a PropFind object, which contains all the
          # information about the properties that need to be fetched.
          #
          # Ususually you would just want to call 'get404Properties' on this object,
          # as this will give you the _exact_ list of properties that need to be
          # fetched, and haven't yet.
          #
          # However, you can also support the 'allprops' property here. In that
          # case, you should check for prop_find.all_props?.
          #
          # @param string path
          # @param PropFind prop_find
          # @return void
          def prop_find(_path, _prop_find)
          end

          # Updates properties for a path
          #
          # This method received a PropPatch object, which contains all the
          # information about the update.
          #
          # Usually you would want to call 'handleRemaining' on this object, to get
          # a list of all properties that need to be stored.
          #
          # @param string path
          # @param PropPatch prop_patch
          # @return void
          def prop_patch(_path, _prop_patch)
          end

          # This method is called after a node is deleted.
          #
          # This allows a backend to clean up all associated properties.
          #
          # The delete method will get called once for the deletion of an entire
          # tree.
          #
          # @param string path
          # @return void
          def delete(_path)
          end

          # This method is called after a successful MOVE
          #
          # This should be used to migrate all properties from one path to another.
          # Note that entire collections may be moved, so ensure that all properties
          # for children are also moved along.
          #
          # @param string source
          # @param string destination
          # @return void
          def move(_source, _destination)
          end
        end
      end
    end
  end
end
