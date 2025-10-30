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
  spec.add_dependency 'pdf-reader', '~> 2.11' # For PDF text extraction and metadata
  spec.add_dependency 'psych', '~> 5.1' # For YAML parsing
  spec.add_dependency 'nokogiri', '~> 1.16' # For HTML/XML parsing
  spec.add_dependency 'roo', '~> 2.10' # For Excel spreadsheet parsing
  spec.add_dependency 'docx', '~> 0.8' # For Word document parsing
  spec.add_dependency 'rtf', '~> 0.3' # For RTF document parsing
  spec.add_dependency 'ruby-msg', '~> 1.5' # For MSG email message parsing
end
