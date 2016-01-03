module Tilia
  module CalDav
    # This plugin implements support for caldav sharing.
    #
    # This spec is defined at:
    # http://svn.calendarserver.org/repository/calendarserver/CalendarServer/trunk/doc/Extensions/caldav-sharing.txt
    #
    # See:
    # Sabre\CalDAV\Backend\SharingSupport for all the documentation.
    #
    # Note: This feature is experimental, and may change in between different
    # SabreDAV versions.
    class SharingPlugin < Dav::ServerPlugin
      # These are the various status constants used by sharing-messages.
      STATUS_ACCEPTED = 1
      STATUS_DECLINED = 2
      STATUS_DELETED = 3
      STATUS_NORESPONSE = 4
      STATUS_INVALID = 5

      # @!attribute [r] server
      #   @!visibility private
      #   Reference to SabreDAV server object.
      #
      #   @var Sabre\DAV\Server

      # This method should return a list of server-features.
      #
      # This is for example 'versioning' and is added to the DAV: header
      # in an OPTIONS response.
      #
      # @return array
      def features
        ['calendarserver-sharing']
      end

      # Returns a plugin name.
      #
      # Using this name other plugins will be able to access other plugins
      # using Sabre\DAV\Server::getPlugin
      #
      # @return string
      def plugin_name
        'caldav-sharing'
      end

      # This initializes the plugin.
      #
      # This function is called by Sabre\DAV\Server, after
      # addPlugin is called.
      #
      # This method should set up the required event subscriptions.
      #
      # @param DAV\Server server
      # @return void
      def setup(server)
        @server = server
        server.resource_type_mapping[ISharedCalendar] = "{#{Plugin::NS_CALENDARSERVER}}shared"

        @server.protected_properties += [
          "{#{Plugin::NS_CALENDARSERVER}}invite",
          "{#{Plugin::NS_CALENDARSERVER}}allowed-sharing-modes",
          "{#{Plugin::NS_CALENDARSERVER}}shared-url"
        ]

        @server.xml.element_map["{#{Plugin::NS_CALENDARSERVER}}share"] = Xml::Request::Share
        @server.xml.element_map["{#{Plugin::NS_CALENDARSERVER}}invite-reply"] = Xml::Request::InviteReply

        @server.on('propFind',     method(:prop_find_early))
        @server.on('propFind',     method(:prop_find_late), 150)
        @server.on('propPatch',    method(:prop_patch), 40)
        @server.on('method:POST',  method(:http_post))
      end

      # This event is triggered when properties are requested for a certain
      # node.
      #
      # This allows us to inject any properties early.
      #
      # @param DAV\PropFind prop_find
      # @param DAV\INode node
      # @return void
      def prop_find_early(prop_find, node)
        if node.is_a?(IShareableCalendar)
          prop_find.handle(
            "{#{Plugin::NS_CALENDARSERVER}}invite",
            -> { Xml::Property::Invite.new(node.shares) }
          )
        end

        if node.is_a?(ISharedCalendar)
          prop_find.handle(
            "{#{Plugin::NS_CALENDARSERVER}}shared-url",
            -> { return Dav::Xml::Property::Href.new(node.shared_url) }
          )

          prop_find.handle(
            "{#{Plugin::NS_CALENDARSERVER}}invite",
            lambda do
              # Fetching owner information
              props = @server.properties_for_path(
                node.owner,
                [
                  '{http://sabredav.org/ns}email-address',
                  '{DAV:}displayname'
                ],
                0
              )

              owner_info = {
                'href' => node.owner
              }

              if props[0].key?(200)
                # We're mapping the internal webdav properties to the
                # elements caldav-sharing expects.
                if props[0][200].key?('{http://sabredav.org/ns}email-address')
                  owner_info['href'] = 'mailto:' + props[0][200]['{http://sabredav.org/ns}email-address']
                end

                if props[0][200].key?('{DAV:}displayname')
                  owner_info['commonName'] = props[0][200]['{DAV:}displayname']
                end
              end

              Xml::Property::Invite.new(
                node.shares,
                owner_info
              )
            end
          )
        end
      end

      # This method is triggered *after* all properties have been retrieved.
      # This allows us to inject the correct resourcetype for calendars that
      # have been shared.
      #
      # @param DAV\PropFind prop_find
      # @param DAV\INode node
      # @return void
      def prop_find_late(prop_find, node)
        if node.is_a?(IShareableCalendar)
          rt = prop_find.get('{DAV:}resourcetype')
          if rt
            if node.shares.size > 0
              rt.add("{#{Plugin::NS_CALENDARSERVER}}shared-owner")
            end
          end

          prop_find.handle(
            "{#{Plugin::NS_CALENDARSERVER}}allowed-sharing-modes",
            lambda do
              Xml::Property::AllowedSharingModes.new(true, false)
            end
          )
        end
      end

      # This method is trigged when a user attempts to update a node's
      # properties.
      #
      # A previous draft of the sharing spec stated that it was possible to use
      # PROPPATCH to remove 'shared-owner' from the resourcetype, thus unsharing
      # the calendar.
      #
      # Even though this is no longer in the current spec, we keep this around
      # because OS X 10.7 may still make use of this feature.
      #
      # @param string path
      # @param DAV\PropPatch prop_patch
      # @return void
      def prop_patch(path, prop_patch)
        node = @server.tree.node_for_path(path)
        return nil unless node.is_a?(IShareableCalendar)

        prop_patch.handle(
          '{DAV:}resourcetype',
          lambda do |value|
            return false if value.is("{#{Plugin::NS_CALENDARSERVER}}shared-owner")

            shares = node.shares
            remove = []
            shares.each do |share|
              remove << share['href']
            end
            node.update_shares([], remove)

            true
          end
        )
      end

      # We intercept this to handle POST requests on calendars.
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return null|bool
      def http_post(request, response)
        path = request.path

        # Only handling xml
        content_type = request.header('Content-Type')
        return nil unless content_type.index('application/xml') || content_type.index('text/xml')

        # Making sure the node exists
        begin
          node = @server.tree.node_for_path(path)
        rescue Dav::Exception::NotFound
          return nil
        end

        request_body = request.body_as_string

        # If this request handler could not deal with this POST request, it
        # will return 'null' and other plugins get a chance to handle the
        # request.
        #
        # However, we already requested the full body. This is a problem,
        # because a body can only be read once. This is why we preemptively
        # re-populated the request body with the existing data.
        request.body = request_body

        document_type_box = Box.new('')
        message = @server.xml.parse(request_body, request.url, document_type_box)
        document_type = document_type_box.value

        case document_type
        # Dealing with the 'share' document, which modified invitees on a
        # calendar.
        when "{#{Plugin::NS_CALENDARSERVER}}share"
          # We can only deal with IShareableCalendar objects
          return true unless node.is_a?(IShareableCalendar)

          @server.transaction_type = 'post-calendar-share'

          # Getting ACL info
          acl = @server.plugin('acl')

          # If there's no ACL support, we allow everything
          acl.check_privileges(path, '{DAV:}write') if acl

          node.update_shares(message.set, message.remove)

          response.status = 200
          # Adding this because sending a response body may cause issues,
          # and I wanted some type of indicator the response was handled.
          response.update_header('X-Sabre-Status', 'everything-went-well')

          # Breaking the event chain
          return false
        # The invite-reply document is sent when the user replies to an
        # invitation of a calendar share.
        when "{#{Plugin::NS_CALENDARSERVER}}invite-reply"

          # This only works on the calendar-home-root node.
          return true unless node.is_a?(CalendarHome)

          @server.transaction_type = 'post-invite-reply'

          # Getting ACL info
          acl = @server.plugin('acl')

          # If there's no ACL support, we allow everything
          acl.check_privileges(path, '{DAV:}write') if acl

          url = node.share_reply(
            message.href,
            message.status,
            message.calendar_uri,
            message.in_reply_to,
            message.summary
          )

          response.status = 200
          # Adding this because sending a response body may cause issues,
          # and I wanted some type of indicator the response was handled.
          response.update_header('X-Sabre-Status', 'everything-went-well')

          if url
            writer = @server.xml.writer
            writer.open_memory
            writer.start_document
            writer.start_element("{#{Plugin::NS_CALENDARSERVER}}shared-as")
            writer.write(Dav::Xml::Property::Href.new(url))
            writer.end_element
            response.update_header('Content-Type', 'application/xml')
            response.body = writer.output_memory
          end

          # Breaking the event chain
          return false
        when "{#{Plugin::NS_CALENDARSERVER}}publish-calendar"
          # We can only deal with IShareableCalendar objects
          return true unless node.is_a?(IShareableCalendar)

          @server.transaction_type = 'post-publish-calendar'

          # Getting ACL info
          acl = @server.plugin('acl')

          # If there's no ACL support, we allow everything
          acl.check_privileges(path, '{DAV:}write') if acl

          node.publish_status = true

          # iCloud sends back the 202, so we will too.
          response.status = 202

          # Adding this because sending a response body may cause issues,
          # and I wanted some type of indicator the response was handled.
          response.update_header('X-Sabre-Status', 'everything-went-well')

          # Breaking the event chain
          return false
        when "{#{Plugin::NS_CALENDARSERVER}}unpublish-calendar"
          # We can only deal with IShareableCalendar objects
          return true unless node.is_a?(IShareableCalendar)

          @server.transaction_type = 'post-unpublish-calendar'

          # Getting ACL info
          acl = @server.plugin('acl')

          # If there's no ACL support, we allow everything
          acl.check_privileges(path, '{DAV:}write') if acl

          node.publish_status = false

          response.status = 200

          # Adding this because sending a response body may cause issues,
          # and I wanted some type of indicator the response was handled.
          response.update_header('X-Sabre-Status', 'everything-went-well')

          # Breaking the event chain
          return false
        end
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
          'description' => 'Adds support for caldav-sharing.',
          'link'        => 'http://sabre.io/dav/caldav-sharing/'
        }
      end
    end
  end
end
