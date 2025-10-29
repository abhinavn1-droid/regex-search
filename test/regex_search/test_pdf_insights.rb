# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/regex_search'
require_relative '../../lib/regex_search/insights/pdf'
require 'pdf-reader'
require 'tempfile'

class TestPDFInsights < Minitest::Test
  def setup
    @insights = RegexSearch::Insights::PDF.new
    @tempfile = Tempfile.new(['test', '.pdf'])
    create_test_pdf(@tempfile.path)
    @pdf_path = @tempfile.path
  end

  def teardown
    # debug_pdf_contents
    @tempfile.close
    @tempfile.unlink
  end

  def debug_pdf_contents
    return unless @pdf_path && File.exist?(@pdf_path)

    puts "\nDEBUG PDF CONTENTS:"
    reader = PDF::Reader.new(@pdf_path)
    reader.pages.each_with_index do |page, idx|
      puts "\nPage #{idx + 1}:"
      puts page.text
    end
    puts "\nPDF Metadata:"
    pp reader.info
  end

  def test_process_match_adds_pdf_metadata
    match = basic_match_data
    result = @insights.process_match(match, input_path: @pdf_path)

    assert_includes result.tags, :pdf_content
    assert result.insights[:pdf_metadata]
    assert_equal 1, result.insights[:pdf_page]
  end

  def test_process_match_finds_correct_page
    match = basic_match_data
    result = @insights.process_match(match, input_path: @pdf_path)

    assert_equal 1, result.insights[:pdf_page]
  end

  def test_process_match_adds_section_context
    match = basic_match_data
    result = @insights.process_match(match, input_path: @pdf_path)

    assert result.insights[:section_context]
    assert_includes %i[top middle bottom], result.insights[:section_context][:page_position]
  end

  def test_process_match_handles_missing_file
    match = basic_match_data
    result = @insights.process_match(match, input_path: 'nonexistent.pdf')

    assert_equal match, result
  end

  def test_process_match_handles_non_pdf_file
    match = basic_match_data
    txt = Tempfile.new(['test', '.txt'])
    begin
      txt.write('Some text')
      txt.flush
      result = @insights.process_match(match, input_path: txt.path)

      assert_equal match, result
    ensure
      txt.close
      txt.unlink
    end
  end

  def test_process_match_caches_page_content
    match = basic_match_data
    @insights.process_match(match, input_path: @pdf_path)

    # Second call should use cached content
    start_time = Time.now
    @insights.process_match(match, input_path: @pdf_path)

    assert_operator Time.now - start_time, :<, 0.1
  end

  private

  def create_test_pdf(path)
    require 'prawn'

    Prawn::Document.generate(path, info: {
                               Title: 'Test Document',
                               Author: 'Test Author',
                               Creator: 'Prawn',
                               Producer: 'Prawn'
                             }) do |pdf|
      # First page
      pdf.font_size(14)
      pdf.text "SECTION 1. INTRODUCTION\n"
      pdf.font_size(12)
      pdf.move_down 10
      pdf.text 'This is a test document'
      pdf.move_down 5
      pdf.text 'It contains some searchable text'

      # Second page
      pdf.start_new_page
      pdf.font_size(14)
      pdf.text "SECTION 2. DETAILS\n"
      pdf.font_size(12)
      pdf.move_down 10
      pdf.text 'More content on page 2'
    end
  end

  def basic_match_data
    RegexSearch::Result.new(
      match: {
        line_number: 1,
        line: 'This is a test document',
        context_before: nil,
        context_after: nil,
        captures: [['test']],
        insights: {},
        tags: [],
        enrichment: {}
      },
      input: { path: nil, filetype: :txt }
    )
  end
end
