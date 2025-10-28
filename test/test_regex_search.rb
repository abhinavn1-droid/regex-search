# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class TestRegexSearch < Minitest::Test
  def test_find_in_string
    inputs = [{ data: 'Ruby is awesome', path: nil, insights_klass: RegexSearch::Insights::Base }]
    results = RegexSearch::Searcher.search(inputs, /(Ruby)/)

    assert_equal 1, results.first[:result].size
    assert_match(/Ruby/, results.first[:result].first.line)
  end

  def test_find_in_file
    Tempfile.create(['sample', '.txt']) do |f|
      f.write("hello world\nruby is awesome\n")
      f.rewind

      inputs = [{ data: File.read(f.path), path: f.path,
                  insights_klass: RegexSearch::Insights::Base }]
      results = RegexSearch::Searcher.search(inputs, /(ruby)/)
      match = results.first[:result].first

      assert_equal 2, match.line_number
      assert_match(/ruby/, match.line)
    end
  end

  def test_find_in_files
    file1 = Tempfile.new(['f1', '.txt'])
    file2 = Tempfile.new(['f2', '.txt'])
    begin
      file1.write("hello world\n")
      file2.write("ruby is awesome\n")
      file1.rewind
      file2.rewind

      inputs = [
        { data: File.read(file1.path), path: file1.path,
          insights_klass: RegexSearch::Insights::Base },
        { data: File.read(file2.path), path: file2.path, insights_klass: RegexSearch::Insights::Base }
      ]

      results = RegexSearch::Searcher.search(inputs, /(ruby)/)

      assert_equal 2, results.size
      assert(results.any? { |fd| fd[:result].any? })
    ensure
      file1.close!
      file2.close!
    end
  end
end
