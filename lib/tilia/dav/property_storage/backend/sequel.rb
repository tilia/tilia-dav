require 'yaml'

module Tilia
  module Dav
    module PropertyStorage
      module Backend
        # PropertyStorage PDO backend.
        #
        # This backend class uses a PDO-enabled database to store webdav properties.
        # Both sqlite and mysql have been tested.
        #
        # The database structure can be found in the examples/sql/ directory.
        class Sequel
          include BackendInterface

          # Value is stored as string.
          VT_STRING = 1

          # Value is stored as XML fragment.
          VT_XML = 2

          # Value is stored as a property object.
          VT_OBJECT = 3

          protected

          # PDO
          #
          # @var sequel
          attr_accessor :sequel

          public

          # PDO table name we'll be using
          #
          # @var string
          attr_accessor :table_name

          # Creates the PDO property storage engine
          #
          # @param Sequel sequel
          def initialize(sequel)
            @sequel = sequel
            @table_name = 'propertystorage'
          end

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
          def prop_find(path, prop_find)
            if !prop_find.all_props? && prop_find.load_404_properties.size == 0
              return
            end

            @sequel.fetch("SELECT name, value, valuetype FROM #{@table_name} WHERE path = ?", path) do |row|
              case row[:valuetype]
              when nil, VT_STRING
                prop_find.set(row[:name], row[:value])
              when VT_XML
                prop_find.set(row[:name], Xml::Property::Complex.new(row[:value]))
              when VT_OBJECT
                prop_find.set(row[:name], YAML.load(row[:value]))
              end
            end
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
          def prop_patch(path, prop_patch)
            prop_patch.handle_remaining(
              lambda do |properties|
                update_stmt = "REPLACE INTO #{@table_name} (path, name, valuetype, value) VALUES (?, ?, ?, ?)"
                delete_stmt = "DELETE FROM #{@table_name} WHERE path = ? AND name = ?"

                properties.each do |name, value|
                  if !value.nil?
                    if value.scalar?
                      value_type = VT_STRING
                    elsif value.is_a?(Xml::Property::Complex)
                      value_type = VT_XML
                      value = value.xml
                    else
                      value_type = VT_OBJECT
                      value = YAML.dump(value)
                    end

                    update_ds = @sequel[
                      update_stmt,
                      path,
                      name,
                      value_type,
                      value
                    ]
                    update_ds.update
                  else
                    delete_ds = @sequel[
                      delete_stmt,
                      path,
                      name
                    ]
                    delete_ds.delete
                  end
                end

                true
              end
            )
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
          def delete(path)
            child_path = path.gsub(
              /[=%_]/,
              '=' => '==',
              '%' => '=%',
              '_' => '=_'
            )
            child_path << '/%'
            delete_ds = @sequel[
              "DELETE FROM #{@table_name} WHERE path = ? OR path LIKE ? ESCAPE '='",
              path,
              child_path
            ]
            delete_ds.delete
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
          def move(source, destination)
            # I don't know a way to write this all in a single sql query that's
            # also compatible across db engines, so we're letting PHP do all the
            # updates. Much slower, but it should still be pretty fast in most
            # cases.
            update = "UPDATE #{table_name} SET path = ? WHERE id = ?"
            @sequel.fetch("SELECT id, path FROM #{@table_name} WHERE path = ? OR path LIKE ?", source, "#{source}/%") do |row|
              # Sanity check. SQL may select too many records, such as records
              # with different cases.
              next if row[:path] != source && row[:path].index("#{source}/") != 0

              trailing_part = row[:path][source.size + 1..-1]
              new_path = destination
              new_path << "/#{trailing_part}" unless trailing_part.blank?

              update_ds = @sequel[
                update,
                new_path,
                row[:id]
              ]
              update_ds.update
            end
          end
        end
      end
    end
  end
end
