#!/usr/bin/env ruby

# Expected to be called "bundle exec examples/minimal.rb"
$LOAD_PATH.unshift './lib'

require 'tilia/dav'
require 'rack'

Time.zone = 'Berlin'

testserver_root = File.join(File.dirname(__FILE__), 'testserver_root')
Dir.mkdir(testserver_root) unless File.exist?(testserver_root)

fail "could not create root directory #{testserver_root}" unless File.directory?(testserver_root)

app = proc do |env|
  root = Tilia::Dav::Fs::Directory.new(testserver_root)
  server = Tilia::Dav::Server.new(env, [root])

  server.add_plugin(Tilia::Dav::Browser::Plugin.new)

  server.exec
end

Rack::Handler::WEBrick.run app
