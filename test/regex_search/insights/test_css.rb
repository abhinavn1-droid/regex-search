# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../lib/regex_search'

class TestInsightsCss < Minitest::Test
  def setup
    @css_content = <<~CSS
      /* Global styles */
      @import url("theme.css");

      .btn.primary {
        color: #fff;
        background: blue;
      }

      @media screen and (min-width: 768px) {
        .grid {
          display: grid;
        }
      }

      /* comment block
         continued */
      .note { /* inline comment */
        /* property comment */
        font-size: 14px;
      }
    CSS

    @tmp = Tempfile.new(['sample', '.css'])
    @tmp.write(@css_content)
    @tmp.flush
  end

  def teardown
    @tmp.close
    @tmp.unlink
  end

  def test_css_selector_and_property_in_simple_rule
    results = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /background/,
      mode: 'find_in_file'
    ).results

    match = results.first[:result].first
    insights = match.insights

    assert_equal '.btn.primary', insights[:selector]
    assert_equal 'background', insights[:property]
    assert_equal 'blue', insights[:declaration_value]
    assert_equal false, insights[:comment]
  end

  def test_css_media_query_context
    results = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /display/,
      mode: 'find_in_file'
    ).results

    match = results.first[:result].first
    insights = match.insights

    assert_equal '.grid', insights[:selector]
    assert_match(/@media/i, insights[:media_query])
  end

  def test_css_comment_detection
    results = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /property comment/,
      mode: 'find_in_file'
    ).results

    match = results.first[:result].first
    insights = match.insights

    assert_equal true, insights[:comment]
  end

  def test_css_import_source
    results = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /@import/,
      mode: 'find_in_file'
    ).results

    match = results.first[:result].first
    insights = match.insights

    assert_equal '"theme.css"', insights[:import_source]
  end
end


