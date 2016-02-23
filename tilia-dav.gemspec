require File.join(File.dirname(__FILE__), 'lib', 'tilia', 'dav', 'version')
Gem::Specification.new do |s|
  s.name        = 'tilia-dav'
  s.version     = Tilia::Dav::Version::VERSION
  s.licenses    = ['BSD-3-Clause']
  s.summary     = 'Port of the sabre-dav library to ruby'
  s.description = "Port of the sabre-dav library to ruby\n\nWebDAV Framework for ruby"
  s.author      = 'Jakob Sack'
  s.email       = 'tilia@jakobsack.de'
  s.files       = `git ls-files`.split("\n")
  s.homepage    = 'https://github.com/tilia/tilia-dav'

  s.add_runtime_dependency 'tilia-vobject', '~> 4.0.2'
  s.add_runtime_dependency 'tilia-event', '~> 2.0'
  s.add_runtime_dependency 'tilia-xml', '~> 1.2'
  s.add_runtime_dependency 'tilia-http', '~> 4.1'
  s.add_runtime_dependency 'tilia-uri', '~> 1.0'

  # External dependencies
  s.add_runtime_dependency 'activesupport', '>= 4.0'
  s.add_runtime_dependency 'sys-filesystem', '~> 1.1'
  s.add_runtime_dependency 'sequel', '~> 4.29'
  s.add_runtime_dependency 'sqlite3', '~> 1.3'
  s.add_runtime_dependency 'mysql2', '~> 0.4'
  s.add_runtime_dependency 'chronic', '~> 0.10'
  s.add_runtime_dependency 'mail', '~> 2.6'
  s.add_runtime_dependency 'rchardet', '~>1.6'
end
