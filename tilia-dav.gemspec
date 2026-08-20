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
  s.required_ruby_version = '>= 3.1.0'

  # Not raised to 2.0.2.2: tilia-event is the only tilia gem still available on
  # rubygems.org, keep it installable without a git checkout.
  s.add_dependency 'tilia-event', '~> 2.0'
  s.add_dependency 'tilia-http', '~> 4.2', '>= 4.2.1.5'
  s.add_dependency 'tilia-uri', '~> 1.0', '>= 1.0.1.3'
  s.add_dependency 'tilia-vobject', '~> 4.0', '>= 4.0.2.4'
  s.add_dependency 'tilia-xml', '~> 1.3', '>= 1.3.0.3'

  # External dependencies
  s.add_dependency 'activesupport', '>= 6.0'
  s.add_dependency 'chronic', '~> 0.10'
  # 3.0 is the first release shipping lib/libxml-ruby.rb, the only entry point
  # that still exists in libxml-ruby 6.
  s.add_dependency 'libxml-ruby', '>= 3.0'
  s.add_dependency 'mail', '~> 2.8'
  s.add_dependency 'rchardet', '>= 1.8'
  s.add_dependency 'sequel', '>= 5.0'
  s.add_dependency 'sys-filesystem', '~> 1.4'
end
