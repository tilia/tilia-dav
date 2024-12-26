require 'cgi'
require 'uri'
require 'fileutils'
require 'pathname'

module Tilia
  module Dav
    module Browser
      # Browser Plugin
      #
      # This plugin provides a html representation, so that a WebDAV server may be accessed
      # using a browser.
      #
      # The class intercepts GET requests to collection resources and generates a simple
      # html index.
      class Plugin < ServerPlugin
        # reference to server class
        #
        # @var Sabre\DAV\Server
        # RUBY: attr_accessor :server

        # enablePost turns on the 'actions' panel, which allows people to create
        # folders and upload files straight from a browser.
        #
        # @var bool
        # RUBY: attr_accessor :enable_post

        # A list of properties that are usually not interesting. This can cut down
        # the browser output a bit by removing the properties that most people
        # will likely not want to see.
        #
        # @var array
        attr_accessor :uninteresting_properties

        # Creates the object.
        #
        # By default it will allow file creation and uploads.
        # Specify the first argument as false to disable this
        #
        # @param bool enable_post
        def initialize(enable_post = true)
          @enable_post = true
          @uninteresting_properties = [
            '{DAV:}supportedlock',
            '{DAV:}acl-restrictions',
            '{DAV:}supported-privilege-set',
            '{DAV:}supported-method-set'
          ]
          @enable_post = enable_post
        end

        # Initializes the plugin and subscribes to events
        #
        # @param DAV\Server server
        # @return void
        def setup(server)
          @server = server
          @server.on('method:GET', method(:http_get_early), 90)
          @server.on('method:GET', method(:http_get), 200)
          @server.on('onHTMLActionsPanel', method(:html_actions_panel), 200)

          @server.on('method:POST', method(:http_post)) if @enable_post
        end

        # This method intercepts GET requests that have ?sabreAction=info
        # appended to the URL
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return bool
        def http_get_early(request, response)
          params = request.query_parameters
          return http_get(request, response) if params['sabreAction'] == 'info'
        end

        # This method intercepts GET requests to collections and returns the html
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return bool
        def http_get(request, response)
          # We're not using straight-up $_GET, because we want everything to be
          # unit testable.
          get_vars = request.query_parameters

          # CSP headers
          @server.http_response.update_header('Content-Security-Policy', "img-src 'self'; style-src 'self';")

          sabre_action = get_vars['sabreAction']

          case sabre_action
          when 'asset'
            # Asset handling, such as images
            serve_asset(get_vars['assetName'])
            return false
          when 'plugins'
            response.status = 200
            response.update_header('Content-Type', 'text/html; charset=utf-8')

            response.body = generate_plugin_listing
            return false
          else # includes "when 'info'"
            begin
              @server.tree.node_for_path(request.path)
            rescue Exception::NotFound => e
              # We're simply stopping when the file isn't found to not interfere
              # with other plugins.
              return nil
            end

            response.status = 200
            response.update_header('Content-Type', 'text/html; charset=utf-8')

            response.body = generate_directory_index(request.path)

            return false
          end
        end

        # Handles POST requests for tree operations.
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return bool
        def http_post(request, response)
          content_type = request.header('Content-Type')
          content_type = content_type.split(';').first

          if content_type != 'application/x-www-form-urlencoded' &&
             content_type != 'multipart/form-data'
            return nil
          end

          post_vars = request.post_data
          return nil unless post_vars.key?('sabreAction')

          uri = request.path

          if @server.emit('onBrowserPostAction', [uri, post_vars['sabreAction'], post_vars])

            case post_vars['sabreAction']
            when 'mkcol'
              if post_vars.key?('name') && !post_vars['name'].blank?
                # Using basename because we won't allow slashes
                folder_name = Http::UrlUtil.split_path(post_vars['name'].strip)[1]

                if post_vars.key?('resourceType')
                  resource_type = post_vars['resourceType'].split(',')
                else
                  resource_type = ['{DAV:}collection']
                end

                properties = {}
                post_vars.each do |var_name, var_value|
                  # Any _POST variable in clark notation is treated
                  # like a property.
                  next unless var_name[0] == '{'
                  var_name = var_name.gsub('*DOT*')
                  properties[var_name] = var_value
                end

                mk_col = MkCol.new(resource_type, properties)
                @server.create_collection(uri + '/' + folder_name, mk_col)
              end
            when 'put' # FIXME
              # USE server.http_request.post_data (Rack.POST)
              file = nil
              server.http_request.params.each do |_, value|
                if value.is_a?(Rack::Multipart::UploadedFile)
                  file = value
                  break
                end
              end

              if file
                # Making sure we only have a 'basename' component
                new_name = ::File.basename(file.original_filename).strip

                if post_vars.key?('name') && !post_vars['name'].blank?
                  new_name = ::File.basename(post_vars['name']).strip
                end

                # is there a necessary equivalent in ruby?
                # if (is_uploaded_file(file['tmp_name'])) {
                @server.create_file("#{uri}/#{new_name}", ::File.open(file.path), 'r')
                # end
              end
            end
          end

          response.update_header('Location', request.url)
          response.status = 302
          false
        end

        # Escapes a string for html.
        #
        # @param string value
        # @return string
        def escape_html(value)
          CGI.escapeHTML(value)
        end

        # Generates the html directory index for a given url
        #
        # @param string path
        # @return string
        def generate_directory_index(path)
          html = generate_header(path.blank? ? '/' : path, path)

          node = @server.tree.node_for_path(path)
          if node.is_a?(ICollection)
            html << '<section><h1>Nodes</h1>'
            html << '<table class="nodeTable">'

            sub_nodes = @server.properties_for_children(
              path,
              [
                '{DAV:}displayname',
                '{DAV:}resourcetype',
                '{DAV:}getcontenttype',
                '{DAV:}getcontentlength',
                '{DAV:}getlastmodified'
              ]
            )

            sub_nodes.each do |sub_path, _sub_props|
              sub_node = @server.tree.node_for_path(sub_path)
              full_path = @server.base_uri + Http::UrlUtil.encode_path(sub_path)
              (_, display_path) = Http::UrlUtil.split_path(sub_path)

              sub_nodes[sub_path]['subNode'] = sub_node
              sub_nodes[sub_path]['fullPath'] = full_path
              sub_nodes[sub_path]['displayPath'] = display_path
            end
            sub_nodes.sort { |a, b| compare_nodes(a, b) }

            sub_nodes.each do |_, sub_props|
              type = {
                'string' => 'Unknown',
                'icon'   => 'cog'
              }
              if sub_props.key?('{DAV:}resourcetype')
                type = map_resource_type(sub_props['{DAV:}resourcetype'].value, sub_props['subNode'])
              end

              html << '<tr>'
              html << '<td class="nameColumn"><a href="' + escape_html(sub_props['fullPath']) + '"><span class="oi" data-glyph="' + escape_html(type['icon']) + '"></span> ' + escape_html(sub_props['displayPath']) + '</a></td>'
              html << '<td class="typeColumn">' + escape_html(type['string']) + '</td>'
              html << '<td>'
              if sub_props.key?('{DAV:}getcontentlength')
                html << escape_html(sub_props['{DAV:}getcontentlength'].to_s + ' bytes')
              end
              html << '</td><td>'
              if sub_props.key?('{DAV:}getlastmodified')
                last_mod = sub_props['{DAV:}getlastmodified'].time
                html << escape_html(last_mod.strftime('%B %e, %Y, %l:%M %P'))
              end
              html << '</td>'

              button_actions = ''
              if sub_props['sub_node'].is_a?(IFile)
                button_actions = '<a href="' + escape_html(sub_props['fullPath']) + '?sabreAction=info"><span class="oi" data-glyph="info"></span></a>'
              end

              box = Box.new(button_actions)
              @server.emit('browserButtonActions', [sub_props['fullPath'], sub_props['subNode'], box])
              button_actions = box.value

              html << "<td>#{button_actions}</td>"
              html << '</tr>'
            end

            html << '</table>'

          end

          html << '</section>'
          html << '<section><h1>Properties</h1>'
          html << '<table class="propTable">'

          # Allprops request
          prop_find = PropFindAll.new(path)
          properties = @server.properties_by_node(prop_find, node)

          properties = prop_find.result_for_multi_status[200]

          properties.each do |prop_name, prop_value|
            if @uninteresting_properties.include?(prop_name)
              html << draw_property_row(prop_name, prop_value)
            end
          end

          html << '</table>'
          html << '</section>'

          # Start of generating actions

          output = ''
          if @enable_post
            box = Box.new(output)
            @server.emit('onHTMLActionsPanel', [node, box])
            output = box.value
          end

          if output
            html << '<section><h1>Actions</h1>'
            html << '<div class="actions">'
            html << output
            html << '</div>'
            html << '</section>'
          end

          html << generate_footer

          @server.http_response.update_header('Content-Security-Policy', "img-src 'self'; style-src 'self';")

          html
        end

        # Generates the 'plugins' page.
        #
        # @return string
        def generate_plugin_listing
          html = generate_header('Plugins')

          html << '<section><h1>Plugins</h1>'
          html << '<table class="propTable">'
          @server.plugins.each do |_, plugin|
            info = plugin.plugin_info
            html << "<tr><th>#{info['name']}</th>"
            html << "<td>#{info['description']}</td>"
            html << '<td>'
            if info.key?('link') && !info['link'].blank?
              html << "<a href=\"#{escape_html(info['link'])}\"><span class=\"oi\" data-glyph=\"book\"></span></a>"
            end
            html << '</td></tr>'
          end
          html << '</table>'
          html << '</section>'

          html << generate_footer

          html
        end

        # Generates the first block of HTML, including the <head> tag and page
        # header.
        #
        # Returns footer.
        #
        # @param string title
        # @param string path
        # @return void
        def generate_header(title, path = nil)
          version = Version::VERSION

          vars = {
            'title'     => escape_html(title),
            'favicon'   => escape_html(asset_url('favicon.ico')),
            'style'     => escape_html(asset_url('sabredav.css')),
            'iconstyle' => escape_html(asset_url('openiconic/open-iconic.css')),
            'logo'      => escape_html(asset_url('sabredav.png')),
            'baseUrl'   => @server.base_uri
          }

          html = <<HTML
<!DOCTYPE html>
<html>
<head>
  <title>#{vars['title']} - tilia/dav #{version}</title>
  <link rel="shortcut icon" href="#{vars['favicon']}"   type="image/vnd.microsoft.icon" />
  <link rel="stylesheet"    href="#{vars['style']}"     type="text/css" />
  <link rel="stylesheet"    href="#{vars['iconstyle']}" type="text/css" />
</head>
<body>
  <header>
      <div class="logo">
          <a href="#{vars['baseUrl']}"><img src="#{vars['logo']}" alt="tilia/dav" /> #{vars['title']}</a>
      </div>
  </header>
  <nav>
HTML

          # If the path is empty, there's no parent.
          if !path.blank?
            parent_uri = Http::UrlUtil.split_path(path).first
            full_path = @server.base_uri + Http::UrlUtil.encode_path(parent_uri)
            html << "<a href=\"#{full_path}\" class=\"btn\">⇤ Go to parent</a>"
          else
            html << '<span class="btn disabled">⇤ Go to parent</span>'
          end

          html << ' <a href="?sabreAction=plugins" class="btn"><span class="oi" data-glyph="puzzle-piece"></span> Plugins</a>'
          html << '</nav>'

          html
        end

        # Generates the page footer.
        #
        # Returns html.
        #
        # @return string
        def generate_footer
          version = Version::VERSION
          <<HTML
    <footer>Generated by TiliaDAV #{version} (c)2015-2015 <a href="http://tiliadav.github.io/">http://tiliadav.github.io/</a></footer>
  </body>
</html>
HTML
        end

        # This method is used to generate the 'actions panel' output for
        # collections.
        #
        # This specifically generates the interfaces for creating new files, and
        # creating new directories.
        #
        # @param DAV\INode node
        # @param mixed output
        # @return void
        def html_actions_panel(node, output)
          return nil unless node.is_a?(ICollection)

          # We also know fairly certain that if an object is a non-extended
          # SimpleCollection, we won't need to show the panel either.
          return nil if node.class == Tilia::Dav::SimpleCollection

          output.value << <<FORM
<form method="post" action="">
  <h3>Create new folder</h3>
  <input type="hidden" name="sabreAction" value="mkcol" />
  <label>Name:</label> <input type="text" name="name" /><br />
  <input type="submit" value="create" />
</form>
<form method="post" action="" enctype="multipart/form-data">
  <h3>Upload file</h3>
  <input type="hidden" name="sabreAction" value="put" />
  <label>Name (optional):</label> <input type="text" name="name" /><br />
  <label>File:</label> <input type="file" name="file" /><br />
  <input type="submit" value="upload" />
</form>
FORM
        end

        protected

        # This method takes a path/name of an asset and turns it into url
        # suiteable for http access.
        #
        # @param string asset_name
        # @return string
        def asset_url(asset_name)
          "#{@server.base_uri}?sabreAction=asset&assetName=#{URI::DEFAULT_PARSER.escape(asset_name)}"
        end

        # This method returns a local pathname to an asset.
        #
        # @param string asset_name
        # @return string
        # @throws DAV\Exception\NotFound
        def local_asset_path(asset_name)
          asset_dir = ::File.join(::File.dirname(__FILE__), 'assets', '')
          path = asset_dir + asset_name

          # Making sure people aren't trying to escape from the base path.
          path = path.tr('\\', '/')
          if path.index('/../') || path[-3..-2] == '/..'
            fail Exception::NotFound, 'Path does not exist, or escaping from the base path was detected'
          end

          begin
            pathname = Pathname.new(path)
            asset_path = Pathname.new(asset_dir)
            if pathname.realpath.to_s.index(asset_path.realpath.to_s) == 0 && ::File.exist?(path)
              return path
            end
          rescue Errno::ENOENT
            raise Exception::NotFound, 'Path does not exist, or escaping from the base path was detected'
          end

          fail Exception::NotFound, 'Path does not exist, or escaping from the base path was detected'
        end

        # This method reads an asset from disk and generates a full http response.
        #
        # @param string asset_name
        # @return void
        def serve_asset(asset_name)
          asset_path = local_asset_path(asset_name)

          # Rudimentary mime type detection
          mime = 'application/octet-stream'
          map = {
            'ico'  => 'image/vnd.microsoft.icon',
            'png'  => 'image/png',
            'css'  => 'text/css'
          }

          ext = ::File.extname(asset_name)[1..-1]
          mime = map[ext] if map.key?(ext)

          @server.http_response.update_header('Content-Type', mime)
          @server.http_response.update_header('Content-Length', ::File.size(asset_path))
          @server.http_response.update_header('Cache-Control', 'public, max-age=1209600')
          @server.http_response.status = 200
          @server.http_response.body = ::File.open(asset_path, 'r')
        end

        # Sort helper function: compares two directory entries based on type and
        # display name. Collections sort above other types.
        #
        # @param array a
        # @param array b
        # @return int
        def compare_nodes(a, b) # FIXME: WTF?
          a = a[1]
          b = b[1]
          type_a = 0
          type_b = 0
          type_a = 1 if a.key?('{DAV:}resourcetype') && a['{DAV:}resourcetype'].value.include?('{DAV:}collection')
          type_b = 1 if b.key?('{DAV:}resourcetype') && b['{DAV:}resourcetype'].value.include?('{DAV:}collection')

          # If same type, sort alphabetically by filename:
          return (a['displayPath'] <=> b['displayPath']) if type_a == type_b
          ((type_a < type_b) ? 1 : -1)
        end

        private

        # Maps a resource type to a human-readable string and icon.
        #
        # @param array resource_types
        # @param INode node
        # @return array
        def map_resource_type(resource_types, node)
          if resource_types.empty?
            if node.is_a?(IFile)
              return {
                'string' => 'File',
                'icon'   => 'file'
              }
            else
              return {
                'string' => 'Unknown',
                'icon'   => 'cog'
              }
            end
          end

          types = {
            '{http://calendarserver.org/ns/}calendar-proxy-write' => {
              'string' => 'Proxy-Write',
              'icon'   => 'people'
            },
            '{http://calendarserver.org/ns/}calendar-proxy-read' => {
              'string' => 'Proxy-Read',
              'icon'   => 'people'
            },
            '{urn:ietf:params:xml:ns:caldav}schedule-outbox' => {
              'string' => 'Outbox',
              'icon'   => 'inbox'
            },
            '{urn:ietf:params:xml:ns:caldav}schedule-inbox' => {
              'string' => 'Inbox',
              'icon'   => 'inbox'
            },
            '{urn:ietf:params:xml:ns:caldav}calendar' => {
              'string' => 'Calendar',
              'icon'   => 'calendar'
            },
            '{http://calendarserver.org/ns/}shared-owner' => {
              'string' => 'Shared',
              'icon'   => 'calendar'
            },
            '{http://calendarserver.org/ns/}subscribed' => {
              'string' => 'Subscription',
              'icon'   => 'calendar'
            },
            '{urn:ietf:params:xml:ns:carddav}directory' => {
              'string' => 'Directory',
              'icon'   => 'globe'
            },
            '{urn:ietf:params:xml:ns:carddav}addressbook' => {
              'string' => 'Address book',
              'icon'   => 'book'
            },
            '{DAV:}principal' => {
              'string' => 'Principal',
              'icon'   => 'person'
            },
            '{DAV:}collection' => {
              'string' => 'Collection',
              'icon'   => 'folder'
            }
          }

          info = {
            'string' => [],
            'icon'   => 'cog'
          }

          resource_types.each do |resource_type|
            if types.key?(resource_type)
              info['string'] << types[resource_type]['string']
            else
              info['string'] << resource_type
            end
          end

          types.each do |key, resource_info|
            if resource_types.include?(key)
              info['icon'] = resource_info['icon']
              break
            end
          end

          info['string'] = info['string'].join(', ')

          info
        end

        # Draws a table row for a property
        #
        # @param string name
        # @param mixed value
        # @return string
        def draw_property_row(name, value)
          html = HtmlOutputHelper.new(
            @server.base_uri,
            @server.xml.namespace_map
          )

          "<tr><th>#{html.xml_name(name)}</th><td>#{draw_property_value(html, value)}</td></tr>"
        end

        # Draws a table row for a property
        #
        # @param HtmlOutputHelper html
        # @param mixed value
        # @return string
        def draw_property_value(html, value)
          if value.scalar?
            return html.h(value)
          elsif value.is_a?(HtmlOutput)
            return value.to_html(html)
          elsif value.is_a?(Tilia::Xml::XmlSerializable)
            # There's no default html output for this property, we're going
            # to output the actual xml serialization instead.
            xml = @server.xml.write('{DAV:}root', value, @server.base_uri)
            # removing first and last line, as they contain our root
            # element.
            xml = xml.split("\n")
            xml = xml[2, 2]
            return "<pre>#{html.h(xml.join("\n"))}</pre>"
          else
            return '<em>unknown</em>'
          end
        end

        public

        # Returns a plugin name.
        #
        # Using this name other plugins will be able to access other plugins
        # using \Sabre\DAV\Server::getPlugin
        #
        # @return string
        def plugin_name
          'browser'
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
            'description' => 'Generates HTML indexes and debug information for your sabre/dav server',
            'link'        => 'http://sabre.io/dav/browser-plugin/'
          }
        end
      end
    end
  end
end
