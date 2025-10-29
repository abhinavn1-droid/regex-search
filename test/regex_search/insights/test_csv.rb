# frozen_string_literal: true

require 'test_helper'
require 'tempfile'
require 'csv'

class TestInsightsCsv < Minitest::Test
  def setup
    @csv_with_headers = <<~CSV
      name,email,age,city
      John Doe,john@example.com,25,New York
      Jane Smith,jane@example.com,30,Los Angeles
      Bob Wilson,bob@test.org,35,Chicago
      Alice Johnson,alice@demo.com,28,Seattle
    CSV

    @csv_without_headers = <<~CSV
      100,Product A,299.99,In Stock
      101,Product B,199.99,Out of Stock
      102,Product C,399.99,In Stock
    CSV

    @complex_csv = <<~CSV
      id,product,price,tags,notes
      1,Widget,49.99,"hardware,tools","High quality widget"
      2,Gadget,99.99,"electronics,tools","Latest model with warranty"
      3,Gizmo,29.99,"accessories","Compact and portable"
    CSV
  end

  def test_csv_insights_with_headers_provides_complete_metadata
    match = { captures: [['john@example.com']], line_number: 2, line: 'John Doe,john@example.com,25,New York' }
    input = { data: @csv_with_headers }
    result = RegexSearch::Insights::Csv.call(input, match)

    # Verify all key fields are present and correct
    assert_equal 'email', result[:insights][:column_name]
    assert_equal 0, result[:insights][:row_index]
    assert_equal 1, result[:insights][:column_index]
    assert_equal 'data[0]["email"]', result[:insights][:csv_path]
    assert_equal true, result[:insights][:has_headers]
    
    # Verify row data is returned as hash with headers
    expected_row = {
      'name' => 'John Doe',
      'email' => 'john@example.com',
      'age' => '25',
      'city' => 'New York'
    }
    assert_equal expected_row, result[:insights][:row_data]
  end

  def test_csv_insights_without_headers_uses_index_based_path
    match = { captures: [['Product B']], line_number: 2, line: '101,Product B,199.99,Out of Stock' }
    input = { data: @csv_without_headers }
    result = RegexSearch::Insights::Csv.call(input, match)

    assert_nil result[:insights][:column_name]
    assert_equal 1, result[:insights][:column_index]
    assert_equal 'data[1][1]', result[:insights][:csv_path]
    assert_equal false, result[:insights][:has_headers]
    assert_instance_of Array, result[:insights][:row_data]
    assert_equal '101', result[:insights][:row_data][0]
  end

  def test_csv_insights_handles_quoted_fields_with_commas
    match = { captures: [['hardware,tools']], line_number: 2, line: '1,Widget,49.99,"hardware,tools","High quality widget"' }
    input = { data: @complex_csv }
    result = RegexSearch::Insights::Csv.call(input, match)

    assert_equal 'tags', result[:insights][:column_name]
    assert_equal 3, result[:insights][:column_index]
    assert_equal 'data[0]["tags"]', result[:insights][:csv_path]
    assert_equal 'hardware,tools', result[:insights][:row_data]['tags']
  end

  def test_csv_insights_finds_match_across_different_rows
    match = { captures: [['Seattle']], line_number: 5, line: 'Alice Johnson,alice@demo.com,28,Seattle' }
    input = { data: @csv_with_headers }
    result = RegexSearch::Insights::Csv.call(input, match)

    assert_equal 3, result[:insights][:row_index]
    assert_equal 'city', result[:insights][:column_name]
    assert_equal 'Alice Johnson', result[:insights][:row_data]['name']
  end

  def test_csv_insights_handles_malformed_csv_gracefully
    malformed_csv = "name,email\n\"unclosed quote,john@example.com"
    match = { captures: [['john']], line_number: 2, line: '"unclosed quote,john@example.com' }
    input = { data: malformed_csv }
    result = RegexSearch::Insights::Csv.call(input, match)

    assert result[:insights].key?(:error)
    assert_match(/Malformed CSV/, result[:insights][:error])
  end

  def test_csv_insights_handles_empty_csv
    empty_csv = ""
    match = { captures: [['test']], line_number: 1, line: '' }
    input = { data: empty_csv }
    result = RegexSearch::Insights::Csv.call(input, match)

    assert_equal 'Empty CSV', result[:insights][:error]
  end

  def test_csv_file_type_detection_and_integration
    Tempfile.create(['sample', '.csv']) do |f|
      f.write(@csv_with_headers)
      f.flush

      # Test file type detection
      detected_type = RegexSearch::FileTypeDetector.detect(f.path)
      assert_equal :csv, detected_type

      # Test insights processor is registered
      processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:csv]
      assert_equal RegexSearch::Insights::Csv, processor

      # Test end-to-end with file path
      match = { captures: [['bob@test.org']], line_number: 4, line: 'Bob Wilson,bob@test.org,35,Chicago' }
      input = { path: f.path }
      result = RegexSearch::Insights::Csv.call(input, match)

      assert_equal 'email', result[:insights][:column_name]
      assert_equal 2, result[:insights][:row_index]
      assert_equal 'data[2]["email"]', result[:insights][:csv_path]
    end
  end
end
