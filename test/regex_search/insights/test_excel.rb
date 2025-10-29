# frozen_string_literal: true

require 'test_helper'
require 'tempfile'
require 'roo'

class TestInsightsExcel < Minitest::Test
  def setup
    # Create a test Excel file with headers
    @xlsx_file_with_headers = Tempfile.new(['test', '.xlsx'])
    create_excel_with_headers(@xlsx_file_with_headers.path)
    
    # Create a test Excel file without headers
    @xlsx_file_without_headers = Tempfile.new(['test_no_headers', '.xlsx'])
    create_excel_without_headers(@xlsx_file_without_headers.path)
    
    # Create a multi-sheet Excel file
    @xlsx_file_multi_sheet = Tempfile.new(['test_multi', '.xlsx'])
    create_multi_sheet_excel(@xlsx_file_multi_sheet.path)
  end

  def teardown
    @xlsx_file_with_headers.close!
    @xlsx_file_without_headers.close!
    @xlsx_file_multi_sheet.close!
  end

  def test_excel_insights_with_headers_finds_cell_location
    match = { captures: [['john@example.com']], line_number: 2 }
    input = { path: @xlsx_file_with_headers.path }
    result = RegexSearch::Insights::Excel.call(input, match)

    assert_equal 'Sheet1', result[:insights][:sheet_name]
    assert_equal 0, result[:insights][:row_index]
    assert_equal 1, result[:insights][:column_index]
    assert_equal 'Email', result[:insights][:column_header]
    assert_equal true, result[:insights][:has_headers]
  end

  def test_excel_insights_builds_cell_reference
    match = { captures: [['john@example.com']], line_number: 2 }
    input = { path: @xlsx_file_with_headers.path }
    result = RegexSearch::Insights::Excel.call(input, match)

    assert_equal 'Sheet1!B2', result[:insights][:cell_reference]
    assert_equal 'workbook["Sheet1"][0]["Email"]', result[:insights][:excel_path]
  end

  def test_excel_insights_returns_full_row_data_as_hash
    match = { captures: [['jane@example.com']], line_number: 3 }
    input = { path: @xlsx_file_with_headers.path }
    result = RegexSearch::Insights::Excel.call(input, match)

    row_data = result[:insights][:row_data]
    assert_instance_of Hash, row_data
    assert_equal 'Jane Smith', row_data['Name']
    assert_equal 'jane@example.com', row_data['Email']
    assert_equal 30, row_data['Age']
  end

  def test_excel_insights_without_headers_uses_index_based_path
    match = { captures: [['Product B']], line_number: 2 }
    input = { path: @xlsx_file_without_headers.path }
    result = RegexSearch::Insights::Excel.call(input, match)

    assert_nil result[:insights][:column_header]
    assert_equal 1, result[:insights][:column_index]
    assert_equal false, result[:insights][:has_headers]
    assert_match(/workbook\["Sheet1"\]\[\d+\]\[\d+\]/, result[:insights][:excel_path])
    
    # Row data should be array
    assert_instance_of Array, result[:insights][:row_data]
  end

  def test_excel_insights_searches_across_multiple_sheets
    match = { captures: [['Sales']], line_number: 1 }
    input = { path: @xlsx_file_multi_sheet.path }
    result = RegexSearch::Insights::Excel.call(input, match)

    # Should find in one of the sheets (searches across all)
    assert_includes ['Employees', 'Departments'], result[:insights][:sheet_name]
    assert result[:insights][:cell_reference].include?('!')
  end

  def test_excel_insights_converts_column_index_to_letter
    match = { captures: [['30']], line_number: 3 }
    input = { path: @xlsx_file_with_headers.path }
    result = RegexSearch::Insights::Excel.call(input, match)

    # Column C (index 2) should be in the cell reference
    assert_match(/Sheet1![A-Z]\d+/, result[:insights][:cell_reference])
  end

  def test_excel_file_type_detection_and_integration
    # Test .xlsx detection
    detected_type = RegexSearch::FileTypeDetector.detect(@xlsx_file_with_headers.path)
    assert_equal :xlsx, detected_type

    # Test processor is registered
    processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:xlsx]
    assert_equal RegexSearch::Insights::Excel, processor
    
    # Also test .xls registration
    xls_processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:xls]
    assert_equal RegexSearch::Insights::Excel, xls_processor
  end

  private

  def create_excel_with_headers(path)
    require 'caxlsx'
    package = Axlsx::Package.new
    workbook = package.workbook
    
    workbook.add_worksheet(name: 'Sheet1') do |sheet|
      sheet.add_row ['Name', 'Email', 'Age']
      sheet.add_row ['John Doe', 'john@example.com', 25]
      sheet.add_row ['Jane Smith', 'jane@example.com', 30]
      sheet.add_row ['Bob Wilson', 'bob@test.org', 35]
    end
    
    package.serialize(path)
  end

  def create_excel_without_headers(path)
    require 'caxlsx'
    package = Axlsx::Package.new
    workbook = package.workbook
    
    workbook.add_worksheet(name: 'Sheet1') do |sheet|
      sheet.add_row [100, 'Product A', 299.99]
      sheet.add_row [101, 'Product B', 199.99]
      sheet.add_row [102, 'Product C', 399.99]
    end
    
    package.serialize(path)
  end

  def create_multi_sheet_excel(path)
    require 'caxlsx'
    package = Axlsx::Package.new
    workbook = package.workbook
    
    workbook.add_worksheet(name: 'Employees') do |sheet|
      sheet.add_row ['Name', 'Department']
      sheet.add_row ['Alice', 'Engineering']
      sheet.add_row ['Bob', 'Sales']
    end
    
    workbook.add_worksheet(name: 'Departments') do |sheet|
      sheet.add_row ['ID', 'Name']
      sheet.add_row [1, 'Engineering']
      sheet.add_row [2, 'Sales']
    end
    
    package.serialize(path)
  end
end

