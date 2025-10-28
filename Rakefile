# frozen_string_literal: true

require 'rake/testtask'
require 'rubocop/rake_task'

Rake::TestTask.new do |t|
  t.libs << 'test'
  # Include all nested test files
  t.pattern = 'test/**/test_*.rb'
  # Run tests in verbose mode so each test name is printed
  # t.test_opts = '-v'
end

RuboCop::RakeTask.new

task default: %i[test rubocop]
