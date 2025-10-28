# frozen_string_literal: true

require_relative '../test_helper'

class TestRunner < Minitest::Test
  def setup
    @sample_text = "This is a configuration file\nIt has some config settings\n"
  end

  def test_fuzzy_search_in_string
    runner = RegexSearch::Runner.new(
      input: @sample_text,
      pattern: 'config',
      mode: 'fuzzy',
      max_distance: 2
    )

    assert_equal 2, runner.results.first[:result].size
    first_line = runner.results.first[:result].map(&:line).first

    assert_includes first_line, 'configuration file'
  end

  def test_fuzzy_search_in_file
    filename = 'test_fuzzy.txt'
    File.write(filename, @sample_text)

    begin
      runner = RegexSearch::Runner.new(
        input: filename,
        pattern: 'config',
        mode: 'fuzzy',
        max_distance: 2
      )

      assert_equal 1, runner.results.size
      assert_equal filename, runner.results.first[:path]
      assert_equal 2, runner.results.first[:result].size
      assert_includes runner.results.first[:result].map(&:line).join, 'config'
    ensure
      File.unlink(filename)
    end
  end

  def test_fuzzy_search_with_filters
    runner = RegexSearch::Runner.new(
      input: @sample_text,
      pattern: 'config',
      mode: 'fuzzy'
    )

    filtered = runner.filter(
      keyword: 'settings',
      tags: [:fuzzy_match]
    )

    assert_equal 1, filtered.size
    assert_equal 1, filtered.first[:result].size
    assert_includes filtered.first[:result].first.line, 'settings'
  end

  def test_fuzzy_search_with_custom_distance
    text = 'The confuggggg is misspelled'

    # Should not find with distance 1
    runner1 = RegexSearch::Runner.new(
      input: text,
      pattern: 'config',
      mode: 'fuzzy',
      max_distance: 1
    )

    assert_empty runner1.results.first[:result]

    # Should find with distance 2
    text2 = 'The confg is misspelled'
    runner2 = RegexSearch::Runner.new(
      input: text2,
      pattern: 'config',
      mode: 'fuzzy',
      max_distance: 2
    )

    refute_empty runner2.results.first[:result]
  end
end
