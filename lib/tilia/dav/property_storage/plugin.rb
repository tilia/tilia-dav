module Tilia
  module Dav
    module PropertyStorage
      # PropertyStorage Plugin.
      #
      # Adding this plugin to your server allows clients to store any arbitrary
      # WebDAV property.
      #
      # See:
      #   http://sabre.io/dav/property-storage/
      #
      # for more information.
      class Plugin < ServerPlugin
        # If you only want this plugin to store properties for a limited set of
        # paths, you can use a pathFilter to do this.
        #
        # The pathFilter should be a callable. The callable retrieves a path as
        # its argument, and should return true or false wether it allows
        # properties to be stored.
        #
        # @var callable
        attr_accessor :path_filter

        # Creates the plugin
        #
        # @param Backend\BackendInterface backend
        def initialize(backend)
          @backend = backend
        end

        # This initializes the plugin.
        #
        # This function is called by Sabre\DAV\Server, after
        # addPlugin is called.
        #
        # This method should set up the required event subscriptions.
        #
        # @param Server server
        # @return void
        def setup(server)
          server.on('propFind',    method(:prop_find), 130)
          server.on('propPatch',   method(:prop_patch), 300)
          server.on('afterMove',   method(:after_move))
          server.on('afterUnbind', method(:after_unbind))
        end

        # Called during PROPFIND operations.
        #
        # If there's any requested properties that don't have a value yet, this
        # plugin will look in the property storage backend to find them.
        #
        # @param PropFind prop_find
        # @param INode node
        # @return void
        def prop_find(prop_find, _node)
          path = prop_find.path
          return nil if path_filter && !path_filter.call(path)
          @backend.prop_find(prop_find.path, prop_find)
        end

        # Called during PROPPATCH operations
        #
        # If there's any updated properties that haven't been stored, the
        # propertystorage backend can handle it.
        #
        # @param string path
        # @param PropPatch prop_patch
        # @return void
        def prop_patch(path, prop_patch)
          return nil if path_filter && !path_filter.call(path)
          @backend.prop_patch(path, prop_patch)
        end

        # Called after a node is deleted.
        #
        # This allows the backend to clean up any properties still in the
        # database.
        #
        # @param string path
        # @return void
        def after_unbind(path)
          return nil if path_filter && !path_filter.call(path)
          @backend.delete(path)
        end

        # Called after a node is moved.
        #
        # This allows the backend to move all the associated properties.
        #
        # @param string source
        # @param string destination
        # @return void
        def after_move(source, destination)
          return nil if path_filter && !path_filter.call(source)
          # If the destination is filtered, afterUnbind will handle cleaning up
          # the properties.
          return nil if path_filter && !path_filter(destination)

          @backend.move(source, destination)
        end

        # Returns a plugin name.
        #
        # Using this name other plugins will be able to access other plugins
        # using \Sabre\DAV\Server::getPlugin
        #
        # @return string
        def plugin_name
          'property-storage'
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
            'description' => 'This plugin allows any arbitrary WebDAV property to be set on any resource.',
            'link'        => 'http://sabre.io/dav/property-storage/'
          }
        end
      end
    end
  end
end
