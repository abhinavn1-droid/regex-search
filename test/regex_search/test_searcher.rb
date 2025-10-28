# frozen_string_literal: true

require 'test_helper'

class TestSearcher < Minitest::Test
  def test_search_finds_match
    inputs = [{ data: "hello\nruby\n", path: 'sample.txt',
                insights_klass: RegexSearch::Insights::Base }]
    results = RegexSearch::Searcher.search(inputs, /ruby/)
    match = results.first[:result].first

    assert_equal 'ruby', match[:line]
    assert_equal 2, match[:line_number]
  end

  def test_search_returns_empty_when_no_match
    inputs = [{ data: "hello\nworld\n", path: 'sample.txt',
                insights_klass: RegexSearch::Insights::Base }]
    results = RegexSearch::Searcher.search(inputs, /python/)

    assert_empty results.first[:result]
  end
end
