source 'https://rubygems.org'

gemspec

# The tilia gems are only released on github, not on rubygems.org.
gem 'tilia-event', git: 'https://github.com/tilia/tilia-event', branch: 'master'
gem 'tilia-http', git: 'https://github.com/tilia/tilia-http', branch: 'master'
gem 'tilia-uri', git: 'https://github.com/tilia/tilia-uri', branch: 'master'
gem 'tilia-vobject', git: 'https://github.com/tilia/tilia-vobject', branch: 'master'
gem 'tilia-xml', git: 'https://github.com/tilia/tilia-xml', branch: 'master'

# Testing
gem 'minitest', '~> 5.25'
gem 'rake', '~> 13.0'
# Hash.from_xml in the test helper; rexml is no longer a default gem
gem 'rexml', '~> 3.4'
gem 'rubocop', '~> 1.69'
gem 'simplecov', '~> 0.22'
# Databases used by the sequel backend tests
gem 'sqlite3', '~> 2.0'
# The tests use tz identifiers such as Canada/Eastern that debian moved into
# the separate tzdata-legacy package; ship the full tz database instead.
gem 'tzinfo-data'
gem 'yard', '~> 0.9'
