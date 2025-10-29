# regex-search
A light weight ruby gem to search for a given regex pattern basically a `CTRL+F`. The main objective is to understand all file formats like text(.txt|.text), log(.log), python(.py), ruby(.rb), PDF(.pdf), markdown(.md) etc. and give the matching text with a little bit of surrounding context, line number(s) and some information about it (applicable to program files). The gem uses traditional methods of file processing to understand the files better.

## Features

- **Multiple File Format Support**: Text, JSON, YAML, PDF and more
- **Rich Context**: Get surrounding context for each match
- **File Type Detection**: Automatic detection and appropriate handling of different file types
- **Insights**: File type specific metadata and context enrichment
- **PDF Support**: Full text search in PDF documents with page numbers and section context

## Usage

```ruby
require 'regex-search'

# Search in text
RegexSearch.find(text, pattern, **options)

# Search in a single file
RegexSearch.find_in_file(file_path_or_object, pattern, **options)

# Search in a collection of files
RegexSearch.find_in_files(collection_of_file_paths_or_objects, pattern, **options)
```

### Default (and configurable) Options

```ruby
options = {
    stop_at_first_match: false, # By default gives all matches 
    provide_insights: true,     # Enable metadata and context enrichment
    context_lines: 2           # Number of context lines before/after match
}
```

### PDF Support

When searching PDF files, the gem provides additional insights:

```ruby
# Search in a PDF file
results = RegexSearch.find_in_file("document.pdf", /important/, provide_insights: true)

# Each match includes PDF-specific metadata
results.each do |result|
  match = result[:result].first
  
  # Page information
  page_number = match.insights[:pdf_page]
  
  # Document metadata
  metadata = match.insights[:pdf_metadata]
  puts "Title: #{metadata[:title]}"
  puts "Author: #{metadata[:author]}"
  puts "Total pages: #{metadata[:page_count]}"
  
  # Section context
  context = match.insights[:section_context]
  puts "Found in section: #{context[:nearest_heading]}"
  puts "Position on page: #{context[:page_position]}" # :top, :middle, or :bottom
end
```

## Documentation

The project uses YARD for documentation. To generate and view the documentation:

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Generate the docs:
   ```bash
   yard doc
   ```

3. View in your browser:
   ```bash
   yard server
   ```
   Then visit http://localhost:8808

The documentation includes:
- Detailed API reference
- Usage examples
- Type information
- Private APIs (marked with @api private)

## Directory Structure
```
regex-search/
├── regex-search.gemspec
├── Rakefile
├── Gemfile
├── Gemfile.lock
├── .rubocop.yml
│
├── lib/
│   ├── regex_search.rb
│   └── regex_search/
│       ├── searcher.rb
│       ├── insights.rb
│       └── insights/
│           ├── base.rb
│           └── json.rb
│
└── test/
    ├── test_helper.rb
    ├── test_regex_search.rb
    └── regex_search/
        ├── test_searcher.rb
        └── insights/
            ├── test_base.rb
            └── test_json.rb
```
