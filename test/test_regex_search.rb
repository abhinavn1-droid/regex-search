# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class TestRegexSearch < Minitest::Test
  def test_find_in_string
    results = RegexSearch.find(input: 'Ruby is awesome', pattern: /Ruby/)

    assert_equal 1, results.first[:result].size
    assert_match(/Ruby/, results.first[:result].first[:line])
  end

  def test_find_in_file
    Tempfile.create(['sample', '.txt']) do |f|
      f.write("hello world\nruby is awesome\n")
      f.rewind

      results = RegexSearch.find_in_file(input: f.path, pattern: /ruby/)
      match = results.first[:result].first

      assert_equal 2, match[:line_number]
      assert_match(/ruby/, match[:line])
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

      results = RegexSearch.find_in_files(input: [file1.path, file2.path], pattern: /ruby/)

      assert_equal 2, results.size
      assert(results.any? { |fd| fd[:result].any? })
    ensure
      file1.close!
      file2.close!
    end
  end
end
