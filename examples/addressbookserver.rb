#!/usr/bin/env ruby
# Addressbook/CardDAV server example
#
# This server features CardDAV support

# Expected to be called "bundle exec examples/addressbookserver.rb"
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
  # Backends
  auth_backend      = Tilia::Dav::Auth::Backend::Sequel.new(sequel)
  principal_backend = Tilia::DavAcl::PrincipalBackend::Sequel.new(sequel)
  carddav_backend   = Tilia::CardDav::Backend::Sequel.new(sequel)

  # Setting up the directory tree //
  nodes = [
    Tilia::DavAcl::PrincipalCollection.new(principal_backend),
    Tilia::CardDav::AddressBookRoot.new(principal_backend, carddav_backend)
  ]

  # The object tree needs in turn to be passed to the server class
  server = Tilia::Dav::Server.new(env, nodes)

  # Plugins
  server.add_plugin(Tilia::Dav::Auth::Plugin.new(auth_backend))
  server.add_plugin(Tilia::Dav::Browser::Plugin.new)
  server.add_plugin(Tilia::CardDav::Plugin.new)
  server.add_plugin(Tilia::DavAcl::Plugin.new)
  server.add_plugin(Tilia::Dav::Sync::Plugin.new)

  # And off we go!
  server.exec
end

Rack::Handler::WEBrick.run app



