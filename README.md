# regex-search
A light weight ruby gem to search for a given regex pattern basically a `CTRL+F`. The main objective is to understand all file formats like text(.txt|.text), log(.log), python(.py), ruby(.rb), PDF(.pdf), markdown(.md) etc. and give the matching text with a little bit of surrounding context, line number(s) and some information about it (applicable to program files). The gem uses traditional methods of file processing to understand the files better.

## Features

 **Multiple File Format Support**: Text, JSON, YAML (.yaml|.yml), CSV, HTML, XML, Markdown, Word (DOC/DOCX), Excel (XLSX/XLS), PDF and more
- **Rich Context**: Get surrounding context for each match
- **File Type Detection**: Automatic detection and appropriate handling of different file types
- **Insights**: File type specific metadata and context enrichment
- **PDF Support**: Full text search in PDF documents with page numbers and section context
- **CSV Support**: Full text search in CSV files with row and column context
- **Markup Support**: Full text search in HTML/XML files with element paths and structure
- **Markdown Support**: Full text search in Markdown files with heading hierarchy and block context
- **Word Support**: Full text search in Word documents with section and paragraph context
- **Excel Support**: Full text search in Excel spreadsheets with sheet and cell context



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

### YAML Support

The gem now recognizes `.yaml` and `.yml` files and applies regex matching over their textual content. When `provide_insights: true`, YAML matches are annotated with structural context so you can locate the match inside the YAML hierarchy.

Example usage:

```ruby
# Search a YAML file and get structural insights
results = RegexSearch.find_in_file('config/sample.yaml', /admin/, provide_insights: true)

results.each do |file_result|
   file_result[:result].each do |match|
      insights = match[:insights]
      puts "Matched YAML path: #{insights[:yaml_path]}" # e.g. "server.database.credentials.username"
      puts "Parent structure: #{insights[:parent_structure].inspect}"
   end
end
```

Notes:
- `:yaml_path` is a dotted path representing the key path to the matched value (arrays use numeric indexes: `features.1`).
- `:parent_structure` is the parent Hash/Array that contains the matched value (suitable for contextual extraction).
- Invalid or malformed YAML is handled gracefully; insights will be empty rather than raising.

### CSV Support

The gem recognizes `.csv` files and applies regex matching over their content. When `provide_insights: true`, CSV matches are annotated with row and column metadata including symbolic paths.

Example usage:

```ruby
# Search a CSV file and get row/column context
results = RegexSearch.find_in_file('data/users.csv', /john@example\.com/, provide_insights: true)

results.each do |file_result|
  file_result[:result].each do |match|
    insights = match.insights
    puts "Row Index: #{insights[:row_index]}"           # e.g. 0 (zero-based, excluding headers)
    puts "Column Name: #{insights[:column_name]}"       # e.g. "email" (if headers exist)
    puts "Column Index: #{insights[:column_index]}"     # e.g. 1 (zero-based)
    puts "CSV Path: #{insights[:csv_path]}"             # e.g. 'data[0]["email"]'
    puts "Row Data: #{insights[:row_data].inspect}"     # Full row as Hash (with headers) or Array
    puts "Has Headers: #{insights[:has_headers]}"       # true/false
  end
end
```

Notes:
- `:csv_path` is a symbolic path to the matched cell. Format is `data[row_index]["column_name"]` for CSV with headers, or `data[row_index][column_index]` for headerless CSV.
- `:row_data` returns the full row as a Hash (with column names as keys) if headers are detected, or as an Array otherwise.
- `:has_headers` indicates whether the CSV was detected to have a header row.
- The gem automatically detects headers using heuristics (checks if first row contains non-numeric values).
- Malformed CSV is handled gracefully with error messages in insights rather than raising exceptions.

### HTML/XML Support

The gem recognizes `.html` and `.xml` files and provides structural context for matches. When `provide_insights: true`, markup matches include element paths, attributes, and parent context.

Example usage:

```ruby
# Search an HTML file
results = RegexSearch.find_in_file('page.html', /contact@example\.com/, provide_insights: true)

results.each do |file_result|
  file_result[:result].each do |match|
    insights = match.insights
    puts "Element: #{insights[:element_tag]}"          # e.g. "p"
    puts "CSS Path: #{insights[:css_path]}"            # e.g. "div.user > p.email"
    puts "XPath: #{insights[:xpath]}"                  # e.g. "//div[@class='user']/p"
    puts "Attributes: #{insights[:element_attributes]}" # e.g. {"class"=>"email"}
    puts "Parent: #{insights[:parent_tag]}"            # e.g. "div"
  end
end

# Search an XML file
results = RegexSearch.find_in_file('config.xml', /production/, provide_insights: true)

results.each do |file_result|
  file_result[:result].each do |match|
    insights = match.insights
    puts "Element: #{insights[:element_tag]}"
    puts "XPath: #{insights[:xpath]}"
    puts "Namespaces: #{insights[:namespaces]}"
  end
end
```

Notes:
- HTML insights include CSS selector paths and XPath for easy element location
- XML insights include XPath, namespaces, and element attributes
- Both provide parent element context and attributes
- Malformed markup is handled gracefully with error messages

### Excel Support

The gem recognizes `.xlsx` and `.xls` files and provides spreadsheet context for matches. When `provide_insights: true`, Excel matches include sheet names, cell references, and row/column metadata.

Example usage:

```ruby
# Search an Excel file
results = RegexSearch.find_in_file('data.xlsx', /john@example\.com/, provide_insights: true)

results.each do |file_result|
  file_result[:result].each do |match|
    insights = match.insights
    puts "Sheet: #{insights[:sheet_name]}"           # e.g. "Users"
    puts "Cell: #{insights[:cell_reference]}"        # e.g. "Users!B2"
    puts "Row: #{insights[:row_index]}"              # e.g. 0 (zero-based, excluding headers)
    puts "Column: #{insights[:column_header]}"       # e.g. "Email"
    puts "Path: #{insights[:excel_path]}"            # e.g. 'workbook["Users"][0]["Email"]'
    puts "Row Data: #{insights[:row_data]}"          # Full row as Hash or Array
  end
end
```

Notes:
- `:excel_path` is a symbolic path to the matched cell. Format is `workbook["SheetName"][row_index]["ColumnHeader"]` for sheets with headers, or `workbook["SheetName"][row_index][column_index]` for headerless sheets.
- `:cell_reference` provides standard Excel notation (e.g., "Sheet1!B2")
- `:row_data` returns the full row as a Hash (with headers) or Array (without)
- Searches across all sheets in the workbook
- Automatic header detection using row pattern analysis
- Supports both `.xlsx` and `.xls` formats

### Markdown Support

The gem recognizes `.md` and `.markdown` files and provides structural context for matches. When `provide_insights: true`, Markdown matches include heading hierarchy, block types, and section paths.

Example usage:

```ruby
# Search a Markdown file
results = RegexSearch.find_in_file('README.md', /installation/, provide_insights: true)

results.each do |file_result|
  file_result[:result].each do |match|
    insights = match.insights
    puts "Heading: #{insights[:current_heading]}"     # e.g. "Getting Started"
    puts "Level: #{insights[:heading_level]}"         # e.g. 2
    puts "Path: #{insights[:heading_path]}"           # e.g. ["Documentation", "Getting Started"]
    puts "Block: #{insights[:block_type]}"            # e.g. "code_block", "paragraph", "list"
    puts "Line Type: #{insights[:line_type]}"         # e.g. "code", "text", "heading"
  end
end
```

Notes:
- `:heading_path` shows the full hierarchy of headings leading to the match
- `:block_type` identifies the Markdown construct (paragraph, code_block, list, blockquote, etc.)
- `:line_type` specifies the exact line type (text, code, heading, list_item, etc.)
- `:code_language` is provided for code blocks (e.g., "ruby", "bash")
- `:list_level` indicates nesting depth for list items
- Supports all standard Markdown elements (headings, code blocks, lists, blockquotes, horizontal rules)

### Word Document Support

The gem recognizes `.doc` and `.docx` files and provides document structure context for matches. When `provide_insights: true`, Word matches include section headings, paragraph indices, and style information.

Example usage:

```ruby
# Search a Word document
results = RegexSearch.find_in_file('report.docx', /conclusion/, provide_insights: true)

results.each do |file_result|
  file_result[:result].each do |match|
    insights = match.insights
    puts "Section: #{insights[:word_section]}"        # e.g. "Introduction"
    puts "Paragraph: #{insights[:word_paragraph]}"    # e.g. 4
    puts "Style: #{insights[:word_style]}"            # e.g. "Heading 1", "Normal"
    puts "Path: #{insights[:word_path]}"              # e.g. "Section[1].Paragraph[4]"
    puts "Text: #{insights[:paragraph_text]}"         # Full paragraph text
  end
end
```

Notes:
- `:word_section` shows the current or most recent heading
- `:word_paragraph` is the zero-based paragraph index
- `:word_style` indicates the paragraph style (Heading 1-6, Normal, Quote, etc.)
- `:word_path` provides a symbolic path to the paragraph
- `:paragraph_text` contains the full paragraph text
- Supports both `.docx` (modern) and `.doc` (legacy) formats

Dependency note:
- YAML parsing is provided via `psych` (the YAML parser used by Ruby). If your environment attempts to build native extensions for `psych` and fails, run:

```powershell
bundle config set force_ruby_platform true
bundle install
```

This forces pure-Ruby platform gems and avoids native compilation issues on some Windows systems.

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
│   ├── regex_search.rb New way 
│   └── regex_search/
|       ├── runner merge the search and runner
|             ├── base.rb -> add old runner changes here as is.
|             ├── content.rb -> add searcher changes here.
│       ├── runner.rb -> Init from here a base on mode select correct class child class for processing the request.
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
