#!/usr/bin/env ruby
# CalDAV server example
#
# This server features CalDAV support

# Expected to be called "bundle exec examples/calendarserver.rb"
$LOAD_PATH.unshift './lib'

require 'tilia/dav'
require 'rack'
require 'yaml'
require 'sequel'

Time.zone = 'Berlin'

# Load databases
database_file = File.join(File.dirname(__FILE__), 'database.yml')
fail 'could not load database file for mysql database' unless File.exist?(database_file)
config = YAML.load(File.read(database_file))
database = config.delete(:database)
sequel = Sequel.mysql2(database, config)

app = proc do |env|
  root = Tilia::Dav::Fs::Directory.new(testserver_root)
  server = Tilia::Dav::Server.new(env, [root])

  server.add_plugin(Tilia::Dav::Browser::Plugin.new)

  server.exec

  # Backends
  auth_backend      = Tilia::Dav::Auth::Backend::Sequel.new(sequel)
  principal_backend = Tilia::DavAcl::PrincipalBackend::Sequel.new(sequel)
  calendar_backend   = Tilia::CalDav::Backend::Sequel.new(sequel)

  # Setting up the directory tree //
  nodes = [
    Tilia::CalDav::Principal::Collection.new(principal_backend),
    Tilia::CalDav::CalendarRoot.new(principal_backend, calendar_backend)
  ]

  # The object tree needs in turn to be passed to the server class
  server = Tilia::Dav::Server.new(env, nodes)

  # Plugins
  server.add_plugin(Tilia::Dav::Auth::Plugin.new(auth_backend))
  server.add_plugin(Tilia::Dav::Browser::Plugin.new)
  server.add_plugin(Tilia::CalDav::Plugin.new)
  server.add_plugin(Tilia::DavAcl::Plugin.new)
  server.add_plugin(Tilia::Dav::Sync::Plugin.new)
  server.add_plugin(Tilia::CalDav::Subscriptions::Plugin.new)
  server.add_plugin(Tilia::CalDav::Schedule::Plugin.new)

  # And off we go!
  server.exec
end

Rack::Handler::WEBrick.run app
