# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class TestInsightsMarkup < Minitest::Test
  def setup
    @html_content = <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Test Page</title></head>
      <body>
        <div class="container">
          <h1 id="main-title">User Directory</h1>
          <div class="user" data-id="1">
            <p class="name">John Doe</p>
            <p class="email">Contact: john@example.com</p>
          </div>
          <div class="user" data-id="2">
            <p class="name">Jane Smith</p>
            <p class="email">Contact: jane@example.com</p>
          </div>
        </div>
      </body>
      </html>
    HTML

    @xml_content = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <users>
        <user id="1" status="active">
          <name>John Doe</name>
          <email>john@example.com</email>
          <age>25</age>
        </user>
        <user id="2" status="inactive">
          <name>Jane Smith</name>
          <email>jane@example.com</email>
          <age>30</age>
        </user>
      </users>
    XML

    @xml_with_namespaces = <<~XML
      <?xml version="1.0"?>
      <catalog xmlns:book="http://example.com/book">
        <book:item isbn="123456">
          <book:title>Ruby Programming</book:title>
          <book:author>John Developer</book:author>
        </book:item>
      </catalog>
    XML
  end

  def test_html_insights_finds_element_and_path
    match = { captures: [['john@example.com']], line: 'Contact: john@example.com' }
    input = { data: @html_content }
    result = RegexSearch::Insights::Html.call(input, match)

    assert_equal 'p', result[:insights][:element_tag]
    assert_equal 'Contact: john@example.com', result[:insights][:element_text]
    assert result[:insights][:css_path].include?('p')
    assert result[:insights][:xpath].include?('/p')
  end

  def test_html_insights_extracts_element_attributes
    match = { captures: [['User Directory']], line: 'User Directory' }
    input = { data: @html_content }
    result = RegexSearch::Insights::Html.call(input, match)

    assert_equal 'h1', result[:insights][:element_tag]
    assert_equal 'main-title', result[:insights][:element_attributes]['id']
  end

  def test_html_insights_includes_parent_context
    match = { captures: [['john@example.com']], line: 'Contact: john@example.com' }
    input = { data: @html_content }
    result = RegexSearch::Insights::Html.call(input, match)

    assert_equal 'div', result[:insights][:parent_tag]
    assert_equal 'user', result[:insights][:parent_attributes]['class']
    assert_equal '1', result[:insights][:parent_attributes]['data-id']
  end

  def test_xml_insights_finds_element_and_xpath
    match = { captures: [['john@example.com']], line: '<email>john@example.com</email>' }
    input = { data: @xml_content }
    result = RegexSearch::Insights::Xml.call(input, match)

    assert_equal 'email', result[:insights][:element_tag]
    assert_equal 'john@example.com', result[:insights][:element_text]
    assert result[:insights][:xpath].include?('/email')
  end

  def test_xml_insights_extracts_element_attributes
    match = { captures: [['John Doe']], line: '<name>John Doe</name>' }
    input = { data: @xml_content }
    result = RegexSearch::Insights::Xml.call(input, match)

    assert_equal 'user', result[:insights][:parent_tag]
    assert_equal '1', result[:insights][:parent_attributes]['id']
    assert_equal 'active', result[:insights][:parent_attributes]['status']
  end

  def test_xml_insights_handles_namespaces
    match = { captures: [['Ruby Programming']], line: '<book:title>Ruby Programming</book:title>' }
    input = { data: @xml_with_namespaces }
    result = RegexSearch::Insights::Xml.call(input, match)

    assert_equal 'title', result[:insights][:element_tag]
    assert result[:insights][:namespaces].key?('xmlns:book')
    assert_equal 'http://example.com/book', result[:insights][:namespaces]['xmlns:book']
  end

  def test_xml_insights_handles_malformed_xml
    malformed_xml = "<?xml version='1.0'?><users><user><name>John</user></users>"
    match = { captures: [['John']], line: '<name>John</user>' }
    input = { data: malformed_xml }
    result = RegexSearch::Insights::Xml.call(input, match)

    assert result[:insights].key?(:error)
    assert_match(/Malformed XML|XML syntax error/, result[:insights][:error])
  end

  def test_markup_file_type_detection_and_integration
    # Test HTML file detection
    Tempfile.create(['sample', '.html']) do |f|
      f.write(@html_content)
      f.flush

      detected_type = RegexSearch::FileTypeDetector.detect(f.path)
      assert_equal :html, detected_type

      # Test HTML processor is registered
      processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:html]
      assert_equal RegexSearch::Insights::Html, processor
    end

    # Test XML file detection
    Tempfile.create(['sample', '.xml']) do |f|
      f.write(@xml_content)
      f.flush

      detected_type = RegexSearch::FileTypeDetector.detect(f.path)
      assert_equal :xml, detected_type

      # Test XML processor is registered
      processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:xml]
      assert_equal RegexSearch::Insights::Xml, processor
    end
  end
end

