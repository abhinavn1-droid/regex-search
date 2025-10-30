# frozen_string_literal: true

require 'test_helper'

class TestInsightsRtf < Minitest::Test
  def setup
    @rtf_file = File.join(__dir__, '../../fixtures/sample.rtf')
  end

  def test_rtf_insights_identifies_section_and_paragraph
    match = { captures: [['Ruby programming']], line_number: 5, line: 'This document covers Ruby programming concepts.' }
    input = { path: @rtf_file }
    result = RegexSearch::Insights::Rtf.call(input, match)

    assert result[:insights][:rtf_section]
    assert result[:insights][:rtf_paragraph].is_a?(Integer)
    assert result[:insights][:rtf_style]
  end

  def test_rtf_insights_builds_symbolic_path
    match = { captures: [['concepts']], line_number: 5, line: 'This document covers Ruby programming concepts.' }
    input = { path: @rtf_file }
    result = RegexSearch::Insights::Rtf.call(input, match)

    assert result[:insights][:rtf_path]
    assert_match(/section\[\d+\]\.paragraph\[\d+\]/, result[:insights][:rtf_path])
  end

  def test_rtf_insights_includes_paragraph_text
    match = { captures: [['programming']], line_number: 5, line: 'This document covers Ruby programming concepts.' }
    input = { path: @rtf_file }
    result = RegexSearch::Insights::Rtf.call(input, match)

    assert result[:insights][:paragraph_text]
    assert result[:insights][:paragraph_text].include?('programming')
  end

  def test_rtf_insights_handles_multiple_sections
    match = { captures: [['advanced']], line_number: 10, line: 'Advanced topics include metaprogramming.' }
    input = { path: @rtf_file }
    result = RegexSearch::Insights::Rtf.call(input, match)

    # Should find a section
    assert result[:insights].key?(:rtf_section)
    assert result[:insights][:rtf_section].is_a?(Integer)
  end

  def test_rtf_file_type_detection_and_integration
    # Test file type detection
    detected_type = RegexSearch::FileTypeDetector.detect(@rtf_file)
    assert_equal :rtf, detected_type

    # Test processor is registered
    processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:rtf]
    assert_equal RegexSearch::Insights::Rtf, processor
  end

  def test_rtf_insights_handles_document_without_match
    match = { captures: [['nonexistent']], line_number: 99, line: 'This text does not exist' }
    input = { path: @rtf_file }
    result = RegexSearch::Insights::Rtf.call(input, match)

    # Should return nil values when no match found
    assert_nil result[:insights][:rtf_section]
    assert_nil result[:insights][:rtf_paragraph]
  end

  def test_rtf_insights_extracts_formatting_metadata
    match = { captures: [['Introduction']], line_number: 1, line: 'Introduction' }
    input = { path: @rtf_file }
    result = RegexSearch::Insights::Rtf.call(input, match)

    # Should have style information
    assert result[:insights][:rtf_style]
    assert result[:insights][:rtf_style].is_a?(String)
  end
end

