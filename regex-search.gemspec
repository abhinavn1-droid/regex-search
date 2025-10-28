# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'regex_search'
  spec.version       = '0.1.0'
  spec.authors       = ['Abhinav Nain']
  spec.email         = ['abhinav.n1@turing.com']
  spec.summary       = 'A simple gem to search keywords in text files'
  spec.description   = 'Reads multiple text files and searches for user-specified keywords.'
  spec.homepage      = 'https://example.com/keyword_finder'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2'
  spec.files         = Dir['lib/**/*', 'test/**/*', 'Rakefile', 'README.md']
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_dependency 'marcel', '~> 1.0' # For file type detection
end
