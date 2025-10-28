# regex-search
A light weight ruby gem to search for a given regex pattern basically a `CTRL+F`. The main objective is to understand all file formats like, text(.txt|.text), log(.log), python(.py), ruby(.rb), pdf(.pdf), markdown(.md) etc. and give the matching text with a little bit of surrounding context, line number(s) and some information about it (applicable to program files). The gem uses traditional methods of file processing to understand the files better. I will add a bunch of improvements as we move ahead with the development.

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
    provide_insights: true, #                    
}
```

## Directory Structure
```
regex-search/
├── regex-search.gemspec
├── Rakefile
├── lib/
│   ├── regex_search.rb
│   └── regex_search/
│       └── searcher.rb
└── test/
    ├── test_helper.rb
    └── test_searcher.rb
```
