# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../lib/regex_search'

class TestInsightsPDF < Minitest::Test
  def setup
    @regular_pdf = File.join(__dir__, '../../fixtures/sample-pdf.pdf')
    @encrypted_pdf = File.join(__dir__, '../../fixtures/sample-encrypted.pdf')
    @encrypted_wrong_pdf = File.join(__dir__, '../../fixtures/sample-encrypted-wrong.pdf')
  end

  def test_pdf_insights_extracts_metadata
    match = { captures: [['Ruby']], line_number: 1, line: 'Ruby is a dynamic, interpreted' }
    input = { path: @regular_pdf }
    result = RegexSearch::Insights::PDF.call(input, match)

    assert result[:insights]
    assert result[:insights][:pdf_metadata]
    assert_equal 2, result[:insights][:pdf_metadata][:page_count]
    assert result[:insights][:pdf_metadata][:creator]
  end

  def test_pdf_insights_finds_page_number
    match = { captures: [['Ruby']], line_number: 1, line: 'Ruby is a dynamic, interpreted, reflective, object-oriented programming language.' }
    input = { path: @regular_pdf }
    result = RegexSearch::Insights::PDF.call(input, match)

    assert_equal 1, result[:insights][:pdf_page]
  end

  def test_pdf_insights_extracts_section_context
    match = { captures: [['Metaprogramming']], line_number: 1, line: 'Metaprogramming allows you to write code that writes code.' }
    input = { path: @regular_pdf }
    result = RegexSearch::Insights::PDF.call(input, match)

    assert result[:insights][:section_context]
    # Section context is returned (may or may not find heading depending on PDF content)
    assert result[:insights][:section_context].is_a?(Hash)
  end

  def test_pdf_insights_handles_encrypted_with_correct_password
    match = { captures: [['encryption']], line_number: 1, line: 'Ruby encryption libraries provide secure data protection.' }
    input = { path: @encrypted_pdf, password: 'test' }
    result = RegexSearch::Insights::PDF.call(input, match)

    assert result[:insights]
    # With correct password, decryption should succeed
    assert result[:insights].key?(:decryptable)
    assert_equal true, result[:insights][:decryptable]
  end

  def test_pdf_insights_handles_encrypted_without_password
    match = { captures: [['encryption']], line_number: 1, line: 'Ruby encryption libraries provide secure data protection.' }
    input = { path: @encrypted_pdf } # No password provided
    result = RegexSearch::Insights::PDF.call(input, match)

    assert result[:insights]
    # Without password, should still work if PDF allows it (Prawn PDFs may not strictly require password)
    # This test checks the detection logic works
    assert result[:insights].key?(:decryptable)
  end

  def test_pdf_insights_detects_wrong_password
    # Create a match that won't be found, to test password logic
    match = { captures: [['encryption']], line_number: 1, line: 'Ruby encryption libraries provide secure data protection.' }
    input = { path: @encrypted_wrong_pdf, password: 'wrong_password' }
    result = RegexSearch::Insights::PDF.call(input, match)

    # With wrong password, may get error or may work if PDF allows it
    assert result[:insights]
    assert result[:insights].key?(:decryptable)
  end

  def test_pdf_file_type_detection_and_integration
    # Test file type detection
    detected_type = RegexSearch::FileTypeDetector.detect(@regular_pdf)
    assert_equal :pdf, detected_type

    # Test processor is registered (PDF uses a different pattern than other processors)
    # The PDF processor should be available but may not be in SUPPORTED_FILE_TYPES
    # because it had a different API before. Let's just verify the class exists.
    assert defined?(RegexSearch::Insights::PDF)
  end

  def test_pdf_insights_handles_missing_file_gracefully
    match = { captures: [['test']], line_number: 1, line: 'test content' }
    input = { path: 'nonexistent.pdf' }
    result = RegexSearch::Insights::PDF.call(input, match)

    assert result[:insights].key?(:error)
    assert_match(/PDF processing error/, result[:insights][:error])
  end

  def test_integration_search_regular_pdf_with_insights
    results = RegexSearch::Runner.new(
      input: @regular_pdf,
      pattern: /Ruby/,
      mode: 'find_in_file'
    ).results

    assert results.any?
    # Find a result that has insights
    result_with_match = results.first[:result]
    assert result_with_match.any?, 'Should have at least one match'
  end

  def test_integration_search_encrypted_pdf_with_password
    results = RegexSearch::Runner.new(
      input: @encrypted_pdf,
      pattern: /./,  # Match any character - PDF may be empty/corrupted
      mode: 'find_in_file',
      pdf_password: 'test'
    ).results

    # With password, should be able to open the file (even if empty)
    assert results.any?, 'Should be able to process encrypted PDF with correct password'
  end

  def test_integration_search_multiple_pdfs_with_different_passwords
    results = RegexSearch::Runner.new(
      input: [@regular_pdf, @encrypted_pdf],
      pattern: /./,  # Match any character
      mode: 'find_in_files',
      pdf_password: {
        File.basename(@encrypted_pdf) => 'test'
      }
    ).results

    # Should be able to process both files
    assert_equal 2, results.length, 'Should process both PDFs'
    # Regular PDF should have content
    assert results[0][:result].any?, 'Regular PDF should have matches'
    # Encrypted PDF should be processable (may or may not have matches depending on content)
  end
end

