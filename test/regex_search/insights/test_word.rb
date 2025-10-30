# frozen_string_literal: true

require 'test_helper'

class TestInsightsWord < Minitest::Test
  def setup
    @docx_file = File.join(__dir__, '../../fixtures/sample.docx')
  end

  def test_word_insights_identifies_section_and_paragraph
    match = { captures: [['Ruby programming']], line_number: 5, line: 'This document covers Ruby programming concepts.' }
    input = { path: @docx_file }
    result = RegexSearch::Insights::Word.call(input, match)

    assert result[:insights][:word_section]
    assert result[:insights][:word_paragraph].is_a?(Integer)
    assert result[:insights][:word_style]
  end

  def test_word_insights_detects_heading_style
    match = { captures: [['Introduction']], line_number: 1, line: 'Introduction' }
    input = { path: @docx_file }
    result = RegexSearch::Insights::Word.call(input, match)

    assert_match(/heading/i, result[:insights][:word_style]) if result[:insights][:word_style]
    assert_equal 'Introduction', result[:insights][:word_section]
  end

  def test_word_insights_builds_symbolic_path
    match = { captures: [['concepts']], line_number: 5, line: 'This document covers Ruby programming concepts.' }
    input = { path: @docx_file }
    result = RegexSearch::Insights::Word.call(input, match)

    assert result[:insights][:word_path]
    assert_match(/Paragraph\[\d+\]/, result[:insights][:word_path])
  end

  def test_word_insights_includes_paragraph_text
    match = { captures: [['programming']], line_number: 5, line: 'This document covers Ruby programming concepts.' }
    input = { path: @docx_file }
    result = RegexSearch::Insights::Word.call(input, match)

    assert result[:insights][:paragraph_text]
    assert result[:insights][:paragraph_text].include?('programming')
  end

  def test_word_insights_handles_multiple_sections
    match = { captures: [['advanced']], line_number: 10, line: 'Advanced topics include metaprogramming.' }
    input = { path: @docx_file }
    result = RegexSearch::Insights::Word.call(input, match)

    # Should find a section (either the match's section or a previous one)
    assert result[:insights].key?(:word_section)
  end

  def test_word_file_type_detection_and_integration
    # Test file type detection
    detected_type = RegexSearch::FileTypeDetector.detect(@docx_file)
    assert_equal :docx, detected_type

    # Test processor is registered
    processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:docx]
    assert_equal RegexSearch::Insights::Word, processor

    # Test .doc is also registered
    doc_processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:doc]
    assert_equal RegexSearch::Insights::Word, doc_processor
  end

  def test_word_insights_handles_document_without_match
    match = { captures: [['nonexistent']], line_number: 99, line: 'This text does not exist' }
    input = { path: @docx_file }
    result = RegexSearch::Insights::Word.call(input, match)

    # Should return nil values when no match found
    assert_nil result[:insights][:word_section]
    assert_nil result[:insights][:word_paragraph]
  end
end

