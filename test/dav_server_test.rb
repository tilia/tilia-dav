require 'test_helper'
require 'http/sapi_mock'
require 'http/response_mock'
require 'dav/auth/backend/mock'

# This class may be used as a basis for other webdav-related unittests.
#
# This class is supposed to provide a reasonably big framework to quickly get
# a testing environment running.
module Tilia
  class DavServerTest < Minitest::Test
    attr_accessor :setup_cal_dav
    attr_accessor :setup_card_dav
    attr_accessor :setup_acl
    attr_accessor :setup_cal_dav_sharing
    attr_accessor :setup_cal_dav_scheduling
    attr_accessor :setup_cal_dav_subscriptions
    attr_accessor :setup_cal_davics_export
    attr_accessor :setup_locks
    attr_accessor :setup_files
    attr_accessor :setup_property_storage

    # An array with calendars. Every calendar should have
    #   - principaluri
    #   - uri
    attr_accessor :caldav_calendars
    attr_accessor :caldav_calendar_objects

    attr_accessor :carddav_address_books
    attr_accessor :carddav_cards

    # @var Sabre::Dav::Server
    attr_accessor :server
    attr_accessor :tree

    attr_accessor :caldav_backend
    attr_accessor :carddav_backend
    attr_accessor :principal_backend
    attr_accessor :locks_backend
    attr_accessor :property_storage_backend

    # @var Sabre::CalDav::Plugin
    attr_accessor :caldav_plugin

    # @var Sabre::CardDav::Plugin
    attr_accessor :carddav_plugin

    # @var Sabre::DavAcl::Plugin
    attr_accessor :acl_plugin

    # @var Sabre::CalDav::SharingPlugin
    attr_accessor :caldav_sharing_plugin

    # CalDAV scheduling plugin
    #
    # @var CalDav::Schedule::Plugin
    attr_accessor :caldav_schedule_plugin

    # @var Sabre::Dav::Auth::Plugin
    attr_accessor :auth_plugin

    # @var Sabre::Dav::Locks::Plugin
    attr_accessor :locks_plugin

    # @var Sabre::Dav::PropertyStorage::Plugin
    attr_accessor :property_storage_plugin

    # If this string is set, we will automatically log in the user with this
    # name.
    attr_accessor :auto_login

    attr_accessor :temp_dir

    def setup
      @temp_dir = Dir.mktmpdir

      @setup_cal_dav ||= false
      @setup_card_dav ||= false
      @setup_acl ||= false
      @setup_cal_dav_sharing ||= false
      @setup_cal_dav_scheduling ||= false
      @setup_cal_dav_subscriptions ||= false
      @setup_cal_davics_export ||= false
      @setup_locks ||= false
      @setup_files ||= false
      @setup_property_storage ||= false
      @caldav_calendars ||= []
      @caldav_calendar_objects ||= {}
      @carddav_address_books ||= []
      @carddav_cards ||= []
      @tree ||= []

      set_up_backends
      set_up_tree

      @server = Dav::Server.new(TestUtil.mock_rack_env, @tree)
      @server.sapi = Http::SapiMock.new
      @server.debug_exceptions = true

      if @setup_cal_dav
        @caldav_plugin = CalDav::Plugin.new
        @server.add_plugin(@caldav_plugin)
      end
      if @setup_cal_dav_sharing
        @caldav_sharing_plugin = CalDav::SharingPlugin.new
        @server.add_plugin(@caldav_sharing_plugin)
      end
      if @setup_cal_dav_scheduling
        @caldav_schedule_plugin = CalDav::Schedule::Plugin.new
        @server.add_plugin(@caldav_schedule_plugin)
      end
      if @setup_cal_dav_subscriptions
        @server.add_plugin(CalDav::Subscriptions::Plugin.new)
      end
      if @setup_cal_davics_export
        @caldav_ics_export_plugin = CalDav::IcsExportPlugin.new
        @server.add_plugin(@caldav_ics_export_plugin)
      end
      if @setup_card_dav
        @carddav_plugin = CardDav::Plugin.new
        @server.add_plugin(@carddav_plugin)
      end
      if @setup_acl
        @acl_plugin = DavAcl::Plugin.new
        @server.add_plugin(@acl_plugin)
      end
      if @setup_locks
        @locks_plugin = Dav::Locks::Plugin.new(@locks_backend)
        @server.add_plugin(@locks_plugin)
      end
      if @setup_property_storage
        @property_storage_plugin = Dav::PropertyStorage::Plugin.new(@property_storage_backend)
        @server.add_plugin(@property_storage_plugin)
      end
      if @auto_login
        auth_backend = Dav::Auth::Backend::Mock.new
        auth_backend.principal = "principals/#{@auto_login}"
        @auth_plugin = Dav::Auth::Plugin.new(auth_backend)
        @server.add_plugin(@auth_plugin)

        # This will trigger the actual login procedure
        @auth_plugin.before_method(Http::Request.new, Http::Response.new)
      end
    end

    def teardown
      FileUtils.remove_entry @temp_dir
    end

    # Makes a request, and returns a response object.
    #
    # You can either pass an instance of Sabre::HTTP::Request, or an array,
    # which will then be used as the _SERVER array.
    #
    # @param array|::Sabre::HTTP::Request request
    # @return ::Sabre::HTTP::Response
    def request(request)
      if request.is_a?(Hash)
        request = Http::Request.create_from_server_array(request)
      end

      @server.http_request = request
      @server.http_response = Http::ResponseMock.new
      @server.exec

      @server.http_response
    end

    # Override this to provide your own Tree for your test-case.
    def set_up_tree
      if @setup_cal_dav
        @tree << CalDav::CalendarRoot.new(
          @principal_backend,
          @caldav_backend
        )
      end
      if @setup_card_dav
        @tree << CardDav::AddressBookRoot.new(
          @principal_backend,
          @carddav_backend
        )
      end

      if @setup_card_dav || @setup_cal_dav
        @tree << CalDav::Principal::Collection.new(
          @principal_backend
        )
      end
      @tree << Dav::Mock::Collection.new('files') if @setup_files
    end

    def set_up_backends
      if @setup_cal_dav_sharing && @caldav_backend.nil?
        @caldav_backend = CalDav::Backend::MockSharing.new(@caldav_calendars, @caldav_calendar_objects)
      end
      if @setup_cal_dav_subscriptions && @caldav_backend.nil?
        @caldav_backend = CalDav::Backend::MockSubscriptionSupport.new(@caldav_calendars, @caldav_calendar_objects)
      end
      if @setup_cal_dav && @caldav_backend.nil?
        if @setup_cal_dav_scheduling
          @caldav_backend = CalDav::Backend::MockScheduling.new(@caldav_calendars, @caldav_calendar_objects)
        else
          @caldav_backend = CalDav::Backend::Mock.new(@caldav_calendars, @caldav_calendar_objects)
        end
      end

      if @setup_card_dav && @carddav_backend.nil?
        @carddav_backend = CardDav::Backend::Mock.new(@carddav_address_books, @carddav_cards)
      end
      if @setup_card_dav || @setup_cal_dav
        @principal_backend = DavAcl::PrincipalBackend::Mock.new
      end

      @locks_backend = Dav::Locks::Backend::Mock.new if @setup_locks
      if @setup_property_storage
        @property_storage_backend = Dav::PropertyStorage::Backend::Mock.new
      end
    end

    def assert_http_status(expected_status, req)
      resp = request(req)
      assert_equal(expected_status.to_i, resp.status.to_i, "Incorrect HTTP status received: #{resp.body}")
    end
  end
end
