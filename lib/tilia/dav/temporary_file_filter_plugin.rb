require 'digest'

module Tilia
  module Dav
    # Temporary File Filter Plugin
    #
    # The purpose of this filter is to intercept some of the garbage files
    # operation systems and applications tend to generate when mounting
    # a WebDAV share as a disk.
    #
    # It will intercept these files and place them in a separate directory.
    # these files are not deleted automatically, so it is adviceable to
    # delete these after they are not accessed for 24 hours.
    #
    # Currently it supports:
    #   * OS/X style resource forks and .DS_Store
    #   * desktop.ini and Thumbs.db (windows)
    #   * .*.swp (vim temporary files)
    #   * .dat.* (smultron temporary files)
    #
    # Additional patterns can be added, by adding on to the
    # temporaryFilePatterns property.
    class TemporaryFileFilterPlugin < ServerPlugin
      # This is the list of patterns we intercept.
      # If new patterns are added, they must be valid patterns for preg_match.
      #
      # @var array
      attr_accessor :temporary_file_patterns

      # A reference to the main Server class
      #
      # @var Sabre\DAV\Server
      # RUBY: attr_accessor :server

      # This is the directory where this plugin
      # will store it's files.
      #
      # @var string
      # RUBY: attr_accessor :data_dir

      # Creates the plugin.
      #
      # Make sure you specify a directory for your files. If you don't, we
      # will use PHP's directory for session-storage instead, and you might
      # not want that.
      #
      # @param string|null data_dir
      def initialize(data_dir = nil)
        @temporary_file_patterns = [
          /^\._(.*)$/,     # OS/X resource forks
          /^.DS_Store$/,   # OS/X custom folder settings
          /^desktop.ini$/, # Windows custom folder settings
          /^Thumbs.db$/,   # Windows thumbnail cache
          /^.(.*).swp$/,   # ViM temporary files
          /^\.dat(.*)$/,   # Smultron seems to create these
          /^~lock.(.*)\#$/ # Windows 7 lockfiles
        ]

        data_dir = ::File.join(Dir.tmpdir, 'tiliadav', '') unless data_dir
        Dir.mkdir(data_dir) unless ::File.directory?(data_dir)
        @data_dir = data_dir
      end

      # Initialize the plugin
      #
      # This is called automatically be the Server class after this plugin is
      # added with Sabre\DAV\Server::add_plugin
      #
      # @param Server server
      # @return void
      def setup(server)
        @server = server
        @server.on('beforeMethod',     method(:before_method))
        @server.on('beforeCreateFile', method(:before_create_file))
      end

      # This method is called before any HTTP method handler
      #
      # This method intercepts any GET, DELETE, PUT and PROPFIND calls to
      # filenames that are known to match the 'temporary file' regex.
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def before_method(request, response)
        temp_location = temp_file?(request.path)
        return true unless temp_location

        case request.method
        when 'GET'
          http_get(request, response, temp_location)
        when 'PUT'
          http_put(request, response, temp_location)
        when 'PROPFIND'
          http_propfind(request, response, temp_location)
        when 'DELETE'
          http_delete(request, response, temp_location)
        else
          true
        end
      end

      # This method is invoked if some subsystem creates a new file.
      #
      # This is used to deal with HTTP LOCK requests which create a new
      # file.
      #
      # @param string uri
      # @param resource data
      # @param DAV\ICollection _parent_node
      # @param bool _modified Should be set to true, if this event handler
      #                       changed &data.
      # @return bool
      def before_create_file(uri, data, _parent, _modified)
        temp_path = temp_file?(uri)
        if temp_path
          h_r = @server.http_response
          h_r.update_header('X-Sabre-Temp', 'true')
          ::File.open(temp_path, 'w') do |file|
            file.write(data)
          end
          return false
        end

        nil
      end

      protected

      # This method will check if the url matches the temporary file pattern
      # if it does, it will return an path based on @data_dir for the
      # temporary file storage.
      #
      # @param string path
      # @return bool|string
      def temp_file?(path)
        # We're only interested in the basename.
        temp_path = Tilia::Http::UrlUtil.split_path(path)[1]

        @temporary_file_patterns.each do |temp_file|
          if temp_path =~ temp_file
            return "#{data_dir}/sabredav_#{Digest::MD5.hexdigest(path)}.tempfile"
          end
        end

        false
      end

      public

      # This method handles the GET method for temporary files.
      # If the file doesn't exist, it will return false which will kick in
      # the regular system for the GET method.
      #
      # @param RequestInterface request
      # @param ResponseInterface h_r
      # @param string temp_location
      # @return bool
      def http_get(_request, h_r, temp_location)
        return nil unless ::File.exist?(temp_location)

        h_r.update_header('Content-Type', 'application/octet-stream')
        h_r.update_header('Content-Length', ::File.size(temp_location))
        h_r.update_header('X-Sabre-Temp', 'true')
        h_r.status = 200
        h_r.body = ::File.open(temp_location, 'r')
        false
      end

      # This method handles the PUT method.
      #
      # @param RequestInterface request
      # @param ResponseInterface h_r
      # @param string temp_location
      # @return bool
      def http_put(_request, h_r, temp_location)
        h_r.update_header('X-Sabre-Temp', 'true')

        new_file = !::File.exist?(temp_location)

        if !new_file && @server.http_request.header('If-None-Match')
          fail Exception::PreconditionFailed, 'The resource already exists, and an If-None-Match header was supplied'
        end

        ::File.open(temp_location, 'w') do |file|
          file.write(@server.http_request.body)
        end

        h_r.status = new_file ? 201 : 200
        false
      end

      # This method handles the DELETE method.
      #
      # If the file didn't exist, it will return false, which will make the
      # standard HTTP DELETE handler kick in.
      #
      # @param RequestInterface request
      # @param ResponseInterface h_r
      # @param string temp_location
      # @return bool
      def http_delete(_request, h_r, temp_location)
        return nil unless ::File.exist?(temp_location)

        ::File.unlink(temp_location)
        h_r.update_header('X-Sabre-Temp', 'true')
        h_r.status = 204
        false
      end

      # This method handles the PROPFIND method.
      #
      # It's a very lazy method, it won't bother checking the request body
      # for which properties were requested, and just sends back a default
      # set of properties.
      #
      # @param RequestInterface request
      # @param ResponseInterface h_r
      # @param string temp_location
      # @return bool
      def http_propfind(request, h_r, temp_location)
        return false unless ::File.exist?(temp_location)

        h_r.update_header('X-Sabre-Temp', 'true')
        h_r.status = 207
        h_r.update_header('Content-Type', 'application/xml; charset=utf-8')

        properties = {
          'href' => request.path,
          200    => {
            '{DAV:}getlastmodified'            => Xml::Property::GetLastModified.new(::File.mtime(temp_location)),
            '{DAV:}getcontentlength'           => ::File.size(temp_location),
            '{DAV:}resourcetype'               => Xml::Property::ResourceType.new(nil),
            "{#{Server::NS_SABREDAV}}tempFile" => true
          }
        }

        data = @server.generate_multi_status([properties])
        h_r.body = data
        false
      end

      protected

      # This method returns the directory where the temporary files should be stored.
      #
      # @return string
      attr_reader :data_dir
    end
  end
end
