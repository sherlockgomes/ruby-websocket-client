# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

desc 'Run tests'
task test: :check_loaded

desc 'Run RuboCop'
task :rubocop do
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
end

desc 'Run all checks'
task check: %i[test rubocop]

desc 'Build the gem'
task build: :check

desc 'Install the gem locally'
task install: :build do
  sh 'gem install pkg/ruby_websocket_client-*.gem'
end

desc 'Push the gem to RubyGems'
task release: :check do
  sh 'gem push pkg/ruby_websocket_client-*.gem'
end

task :check_loaded do
  require_relative 'lib/ruby_websocket_client'
end

task default: :check
