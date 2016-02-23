#!/usr/bin/env ruby
# This server combines both CardDAV and CalDAV functionality into a single
# server. It is assumed that the server runs at the root of a HTTP domain (be
# that a domainname-based vhost or a specific TCP port.
#
# This example also assumes that you're using MySQL and the database has
# already been setup (along with the database tables).

# Expected to be called "bundle exec examples/addressbookserver.rb"
$LOAD_PATH.unshift './lib'

require 'tilia/dav'
require 'rack'
require 'yaml'
require 'sequel'

# UTC or GMT is easy to work with, and usually recommended for any
# application.
Time.zone = 'UTC'

# Database
database_file = File.join(File.dirname(__FILE__), 'database.yml')
fail 'could not load database file for mysql database' unless File.exist?(database_file)
config = YAML.load(File.read(database_file))
database = config.delete(:database)
sequel = Sequel.mysql2(database, config)

app = proc do |env|
  # The backends. Yes we do really need all of them.
  #
  # This allows any developer to subclass just any of them and hook into their
  # own backend systems.
  auth_backend      = Tilia::Dav::Auth::Backend::Sequel.new(sequel)
  principal_backend = Tilia::DavAcl::PrincipalBackend::Sequel.new(sequel)
  carddav_backend   = Tilia::CardDav::Backend::Sequel.new(sequel)
  caldav_backend    = Tilia::CalDav::Backend::Sequel.new(sequel)

  # The directory tree
  #
  # Basically this is an array which contains the 'top-level' directories in the
  # WebDAV server.
  nodes = [
    # /principals
    Tilia::CalDav::Principal::Collection.new(principal_backend),
    # /calendars
    Tilia::CalDav::CalendarRoot.new(principal_backend, caldav_backend),
    # /addressbook
    Tilia::CardDav::AddressBookRoot.new(principal_backend, carddav_backend)
  ]

  # The object tree needs in turn to be passed to the server class
  server = Tilia::Dav::Server.new(env, nodes)
  server.debug_exceptions = true

  # Plugins
  server.add_plugin(Tilia::Dav::Auth::Plugin.new(auth_backend))
  server.add_plugin(Tilia::Dav::Browser::Plugin.new)
  server.add_plugin(Tilia::CardDav::Plugin.new)
  server.add_plugin(Tilia::CalDav::Plugin.new)
  server.add_plugin(Tilia::CalDav::Subscriptions::Plugin.new)
  server.add_plugin(Tilia::CalDav::Schedule::Plugin.new)
  server.add_plugin(Tilia::DavAcl::Plugin.new)
  server.add_plugin(Tilia::Dav::Sync::Plugin.new)

  # And off we go!
  server.exec
end

Rack::Handler::WEBrick.run app
