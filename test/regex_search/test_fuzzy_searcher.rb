# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/regex_search/fuzzy_searcher'

class TestFuzzySearcher < Minitest::Test
  def setup
    @sample_text = <<~TEXT
      Here is a configuration file
      The config settings are important
      Please check your configs carefully
      This is a test of fuzzy matching
      Some other text without matches
      Here's a slightly different config
    TEXT

    @searcher = RegexSearch::FuzzySearcher.new('config', max_distance: 2)
  end

  def test_exact_match
    results = @searcher.search_text(@sample_text)

    assert_includes results.map { |r| r.line.strip },
                    'Here is a configuration file'
    assert_includes results.map { |r| r.line.strip },
                    'The config settings are important'
  end

  def test_fuzzy_match
    results = @searcher.search_text(@sample_text)

    assert_includes results.map { |r| r.line.strip },
                    'Please check your configs carefully'
  end

  def test_no_match_beyond_threshold
    searcher = RegexSearch::FuzzySearcher.new('config', max_distance: 1)
    results = searcher.search_text('This confuggggg is misspelled')

    assert_empty results
  end

  def test_case_insensitive_match
    searcher = RegexSearch::FuzzySearcher.new('CONFIG', max_distance: 2)
    results = searcher.search_text('This is a config file')

    refute_empty results
  end

  def test_match_with_context
    results = @searcher.search_text(@sample_text, context_lines: 1)
    result = results.find { |r| r.line.include?('config settings') }

    assert_equal 'Here is a configuration file', result.context_before.strip
    assert_equal 'Please check your configs carefully', result.context_after.strip
  end

  def test_match_enrichment
    results = @searcher.search_text('Here is a confg file')

    refute_empty results
    result = results.first

    assert_includes result.tags, :fuzzy_match
    assert_operator result.enrichment[:levenshtein_distance], :<=, 2
    assert_kind_of Integer, result.enrichment[:match_position]
  end

  def test_search_file
    filename = 'test_config.txt'
    File.write(filename, @sample_text)

    begin
      results = @searcher.search_file(filename)

      assert_equal 4, results.size
      assert_equal filename, results.first.path
    ensure
      File.unlink(filename)
    end
  end

  def test_custom_max_distance
    searcher = RegexSearch::FuzzySearcher.new('configuration', max_distance: 3)
    results = searcher.search_text('Here is a configuraton file')

    refute_empty results
  end

  def test_multiple_matches_per_line
    searcher = RegexSearch::FuzzySearcher.new('test', max_distance: 1)
    results = searcher.search_text('A test text with tests')

    assert_equal 1, results.size # We only want the best match per line
    assert_equal 0, results.first.enrichment[:levenshtein_distance] # Should find exact match
  end

  def test_empty_text
    results = @searcher.search_text('')

    assert_empty results
  end
end
