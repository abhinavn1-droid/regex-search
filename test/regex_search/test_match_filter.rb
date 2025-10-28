# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/regex_search/match_filter'

class TestMatchFilter < Minitest::Test
  def setup
    @result1 = RegexSearch::Result.new(
      match: {
        line_number: 1,
        line: 'important config setting',
        context_before: 'previous line',
        context_after: 'next line',
        captures: [['config']],
        tags: [:contains_number],
        enrichment: { context_density: 2 },
        insights: {}
      },
      input: { path: 'test.txt', filetype: :txt }
    )

    @result2 = RegexSearch::Result.new(
      match: {
        line_number: 2,
        line: 'https://example.com/settings',
        context_before: nil,
        context_after: nil,
        captures: [['settings']],
        tags: [:contains_url],
        enrichment: { context_density: 0 },
        insights: {}
      },
      input: { path: 'config.json', filetype: :json }
    )

    @search_results = [
      { result: [@result1], path: 'test.txt', filetype: :txt },
      { result: [@result2], path: 'config.json', filetype: :json }
    ]
  end

  def test_filter_by_keyword
    filtered = RegexSearch::MatchFilter.filter(@search_results, keyword: 'config')

    assert_equal 1, filtered.size
    assert_equal 'important config setting', filtered.first[:result].first.line
  end

  def test_filter_by_tags
    filtered = RegexSearch::MatchFilter.filter(@search_results, tags: [:contains_url])

    assert_equal 1, filtered.size
    assert_equal 'https://example.com/settings', filtered.first[:result].first.line
  end

  def test_filter_by_min_context_density
    filtered = RegexSearch::MatchFilter.filter(@search_results, min_context_density: 2)

    assert_equal 1, filtered.size
    assert_equal 'important config setting', filtered.first[:result].first.line
  end

  def test_filter_by_exclude_patterns
    filtered = RegexSearch::MatchFilter.filter(
      @search_results,
      exclude_patterns: [%r{https?://}]
    )

    assert_equal 1, filtered.size
    assert_equal 'important config setting', filtered.first[:result].first.line
  end

  def test_filter_by_file_type
    filtered = RegexSearch::MatchFilter.filter(@search_results, file_types: [:json])

    assert_equal 1, filtered.size
    assert_equal :json, filtered.first[:filetype]
  end

  def test_filter_with_multiple_criteria
    filtered = RegexSearch::MatchFilter.filter(
      @search_results,
      keyword: 'settings',
      tags: [:contains_url],
      file_types: [:json]
    )

    assert_equal 1, filtered.size
    assert_equal 'https://example.com/settings', filtered.first[:result].first.line
  end

  def test_filter_with_no_matches
    filtered = RegexSearch::MatchFilter.filter(
      @search_results,
      keyword: 'nonexistent'
    )

    assert_empty filtered
  end

  def test_filter_with_no_criteria_returns_all
    filtered = RegexSearch::MatchFilter.filter(@search_results)

    assert_equal @search_results, filtered
  end
end
