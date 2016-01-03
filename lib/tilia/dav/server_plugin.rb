module Tilia
  module Dav
    # The baseclass for all server plugins.
    #
    # Plugins can modify or extend the servers behaviour.
    class ServerPlugin
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
      end

      # This method should return a list of server-features.
      #
      # This is for example 'versioning' and is added to the DAV: header
      # in an OPTIONS response.
      #
      # @return array
      def features
        []
      end

      # Use this method to tell the server this plugin defines additional
      # HTTP methods.
      #
      # This method is passed a uri. It should only return HTTP methods that are
      # available for the specified uri.
      #
      # @param string path
      # @return array
      def http_methods(_path)
        []
      end

      # Returns a plugin name.
      #
      # Using this name other plugins will be able to access other plugins
      # using \Sabre\DAV\Server::getPlugin
      #
      # @return string
      def plugin_name
        self.class.to_s
      end

      # Returns a list of reports this plugin supports.
      #
      # This will be used in the {DAV:}supported-report-set property.
      # Note that you still need to subscribe to the 'report' event to actually
      # implement them
      #
      # @param string uri
      # @return array
      def supported_report_set(_uri)
        []
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
          'name' => plugin_name,
          'description' => nil,
          'link' => nil
        }
      end
    end
  end
end
