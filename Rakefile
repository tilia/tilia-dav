require 'rake'
require 'rake/testtask'
require 'rubocop/rake_task'
require 'yard'

Rake::TestTask.new do |t|
  t.test_files = Dir.glob('test/**/*_test.rb')
  t.libs << 'test'
end
RuboCop::RakeTask.new do |t|
  t.options = ['--format', 'html', '--out', 'coverage/rubocop.html']
end
YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb', '-', 'README.md']
  t.options = ['--private']
end

task(default: :test)
