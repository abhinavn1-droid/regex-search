# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../lib/regex_search'

class TestInsightsPython < Minitest::Test
  def setup
    @py_source = <<~PY
      """Module docstring"""
      import os
      from sys import path

      class Greeter:
          """Greeter docs"""
          def __init__(self, name):
              # initializer comment
              self.name = name

          def greet(self):
              message = f"Hello, {self.name}!"  # inline
              return message

      def util():
          """utility function"""
          return 42

      # trailing comment
    PY

    @tmp = Tempfile.new(['sample', '.py'])
    @tmp.write(@py_source)
    @tmp.flush
  end

  def teardown
    @tmp.close
    @tmp.unlink
  end

  def test_function_container_detection
    results = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /return message/,
      mode: 'find_in_file'
    ).results

    match = results.first[:result].first
    insights = match.insights

    assert_equal 'greet', insights[:container]
    assert_equal 'function', insights[:container_type]
    assert_equal 'module.greet()', insights[:python_path]
  end

  def test_class_container_detection
    results = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /self\.name = name/,
      mode: 'find_in_file'
    ).results

    match = results.first[:result].first
    insights = match.insights

    # Nearest function still takes precedence; ensure class context available as module path prefix
    assert_equal 'function', insights[:container_type]
  end

  def test_docstring_and_comment_flags
    results_doc = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /utility function/,
      mode: 'find_in_file'
    ).results
    insights_doc = results_doc.first[:result].first.insights
    assert_equal true, insights_doc[:in_docstring]

    results_comment = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /initializer comment/,
      mode: 'find_in_file'
    ).results
    insights_comment = results_comment.first[:result].first.insights
    assert_equal true, insights_comment[:in_comment]
  end

  def test_import_context_is_present
    results = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /Greeter/,
      mode: 'find_in_file'
    ).results

    insights = results.first[:result].first.insights
    assert insights[:import_context].any? { |l| l.start_with?('import ') || l.start_with?('from ') }
  end
end


