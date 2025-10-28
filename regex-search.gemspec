# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'keyword_finder'
  spec.version       = '0.1.0'
  spec.authors       = ['Your Name']
  spec.email         = ['your.email@example.com']
  spec.summary       = 'A simple gem to search keywords in text files'
  spec.description   = 'Reads multiple text files and searches for user-specified keywords.'
  spec.homepage      = 'https://example.com/keyword_finder'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2'
  spec.files         = Dir['lib/**/*', 'test/**/*', 'Rakefile', 'README.md']
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
end
