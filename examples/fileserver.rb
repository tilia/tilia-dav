#!/usr/bin/env ruby
# This is the best starting point if you're just interested in setting up a fileserver.
#
# Make sure that the 'public' and 'tmpdata' exists, with write permissions
# for your server.

# Expected to be called "bundle exec examples/minimal.rb"
$LOAD_PATH.unshift './lib'

require 'tilia/dav'
require 'rack'
require 'yaml'
require 'sequel'

Time.zone = 'Berlin'

testserver_root = File.join(File.dirname(__FILE__), 'testserver_root')
Dir.mkdir(testserver_root) unless File.exist?(testserver_root)
testserver_tmp = File.join(File.dirname(__FILE__), 'testserver_tmp')
Dir.mkdir(testserver_tmp) unless File.exist?(testserver_tmp)

fail "could not create root directory #{testserver_root}" unless File.directory?(testserver_root)
fail "could not create root directory #{testserver_root}" unless File.directory?(testserver_tmp)

app = proc do |env|
  # Create the root node
  root = Tilia::Dav::Fs::Directory.new(testserver_root)

  # The rootnode needs in turn to be passed to the server class
  server = Tilia::Dav::Server.new(env, [root])
  server.debug_exceptions = true

  # Support for LOCK and UNLOCK
  lock_backend = Tilia::Dav::Locks::Backend::File.new(testserver_tmp + '/locksdb')
  lock_plugin = Tilia::Dav::Locks::Plugin.new(lock_backend)
  server.add_plugin(lock_plugin)

  # Support for html frontend
  browser = Tilia::Dav::Browser::Plugin.new
  server.add_plugin(browser)

  # Automatically guess (some) contenttypes, based on extesion
  server.add_plugin(Tilia::Dav::Browser::GuessContentType.new)

  # Authentication backend
  auth_backend = Tilia::Dav::Auth::Backend::File.new(testserver_tmp + '.htdigest')
  auth = Tilia::Dav::Auth::Plugin.new(auth_backend)
  server.add_plugin(auth)

  # Temporary file filter
  temp_ff = Tilia::Dav::TemporaryFileFilterPlugin.new(testserver_tmp)
  server.add_plugin(temp_ff)

  server.exec
end

Rack::Handler::WEBrick.run app
