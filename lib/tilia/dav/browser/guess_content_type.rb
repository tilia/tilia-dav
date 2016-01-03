module Tilia
  module Dav
    module Browser
      # GuessContentType plugin
      #
      # A lot of the built-in File objects just return application/octet-stream
      # as a content-type by default. This is a problem for some clients, because
      # they expect a correct contenttype.
      #
      # There's really no accurate, fast and portable way to determine the contenttype
      # so this extension does what the rest of the world does, and guesses it based
      # on the file extension.
      class GuessContentType < ServerPlugin
        # List of recognized file extensions
        #
        # Feel free to add more
        #
        # @var array
        attr_accessor :extension_map

        # Initializes the plugin
        #
        # @param DAV\Server server
        # @return void
        def setup(server)
          # Using a relatively low priority (200) to allow other extensions
          # to set the content-type first.
          server.on('propFind', method(:prop_find), 200)
        end

        # Our PROPFIND handler
        #
        # Here we set a contenttype, if the node didn't already have one.
        #
        # @param PropFind prop_find
        # @param INode node
        # @return void
        def prop_find(prop_find, _node)
          prop_find.handle(
            '{DAV:}getcontenttype',
            lambda do
              file_name = Http::UrlUtil.split_path(prop_find.path)[1]
              return content_type(file_name)
            end
          )
        end

        protected

        # Simple method to return the contenttype
        #
        # @param string file_name
        # @return string
        def content_type(file_name)
          # Just grabbing the extension
          extension = ::File.extname(file_name.downcase)[1..-1]
          return @extension_map[extension] if @extension_map.key?(extension)
          'application/octet-stream'
        end

        # TODO: document
        def initialize
          @extension_map = {
            # images
            'jpg' => 'image/jpeg',
            'gif' => 'image/gif',
            'png' => 'image/png',

            # groupware
            'ics' => 'text/calendar',
            'vcf' => 'text/vcard',

            # text
            'txt' => 'text/plain'
          }
        end
      end
    end
  end
end
