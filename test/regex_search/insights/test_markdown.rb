# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class TestInsightsMarkdown < Minitest::Test
  def setup
    @markdown_content = <<~MD
      # RegexSearch Documentation
      
      This is the main documentation file.
      
      ## Installation
      
      Run the following command:
      
      ```bash
      gem install regex_search
      ```
      
      Or add to your Gemfile:
      
      ```ruby
      gem 'regex_search', '~> 0.1.0'
      ```
      
      ## Usage
      
      ### Basic Search
      
      You can search in text:
      
      - String search
      - File search
      - Multiple files
      
      ### Advanced Features
      
      The gem supports:
      
      1. Pattern matching
      2. Context extraction
      3. Insights generation
      
      > **Note**: Remember to handle errors properly.
      
      ## API Reference
      
      See the full API documentation for details.
    MD
  end

  def test_markdown_insights_detects_heading_context
    match = { captures: [['gem install']], line_number: 10, line: 'gem install regex_search' }
    input = { data: @markdown_content }
    result = RegexSearch::Insights::Markdown.call(input, match)

    assert_equal 'Installation', result[:insights][:current_heading]
    assert_equal 2, result[:insights][:heading_level]
    assert_equal ['RegexSearch Documentation', 'Installation'], result[:insights][:heading_path]
  end

  def test_markdown_insights_identifies_code_blocks
    match = { captures: [['gem install']], line_number: 10, line: 'gem install regex_search' }
    input = { data: @markdown_content }
    result = RegexSearch::Insights::Markdown.call(input, match)

    assert_equal 'code_block', result[:insights][:block_type]
    assert_equal 'code', result[:insights][:line_type]
    assert_equal 'bash', result[:insights][:code_language]
  end

  def test_markdown_insights_handles_nested_headings
    match = { captures: [['String search']], line_number: 26, line: '- String search' }
    input = { data: @markdown_content }
    result = RegexSearch::Insights::Markdown.call(input, match)

    assert_equal 'Basic Search', result[:insights][:current_heading]
    assert_equal 3, result[:insights][:heading_level]
    assert_equal ['RegexSearch Documentation', 'Usage', 'Basic Search'], result[:insights][:heading_path]
  end

  def test_markdown_insights_identifies_list_items
    match = { captures: [['Pattern matching']], line_number: 34, line: '1. Pattern matching' }
    input = { data: @markdown_content }
    result = RegexSearch::Insights::Markdown.call(input, match)

    assert_equal 'list_item', result[:insights][:line_type]
    assert_equal 'list', result[:insights][:block_type]
    assert_equal 0, result[:insights][:list_level]
  end

  def test_markdown_insights_handles_paragraphs
    match = { captures: [['documentation']], line_number: 3, line: 'This is the main documentation file.' }
    input = { data: @markdown_content }
    result = RegexSearch::Insights::Markdown.call(input, match)

    assert_equal 'text', result[:insights][:line_type]
    assert_equal 'paragraph', result[:insights][:block_type]
    assert_equal 'RegexSearch Documentation', result[:insights][:current_heading]
  end

  def test_markdown_file_type_detection_and_integration
    Tempfile.create(['test', '.md']) do |f|
      f.write(@markdown_content)
      f.flush

      # Test file type detection
      detected_type = RegexSearch::FileTypeDetector.detect(f.path)
      assert_equal :md, detected_type

      # Test processor is registered
      processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:md]
      assert_equal RegexSearch::Insights::Markdown, processor

      # Test with actual file
      match = { captures: [['gem']], line_number: 10, line: 'gem install regex_search' }
      input = { path: f.path }
      result = RegexSearch::Insights::Markdown.call(input, match)

      assert_equal 'code_block', result[:insights][:block_type]
      assert_equal 'Installation', result[:insights][:current_heading]
    end
  end
end

