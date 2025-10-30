# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../lib/regex_search'

class TestInsightsRuby < Minitest::Test
  def setup
    @rb_source = <<~RB
      # frozen_string_literal: true
      require 'json'
      require_relative 'util'

      =begin
      File operations helpers
      =end

      module Tools
        class Greeter
          # initialize docs
          def initialize(name)
            # assigning name
            @name = name
          end

          def greet
            msg = "Hello, #{@name}!" # inline
            return msg
          end
        end
      end
    RB

    @tmp = Tempfile.new(['sample', '.rb'])
    @tmp.write(@rb_source)
    @tmp.flush
  end

  def teardown
    @tmp.close
    @tmp.unlink
  end

  def test_method_container_detection
    results = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /return msg/,
      mode: 'find_in_file'
    ).results

    insights = results.first[:result].first.insights
    assert_equal 'method', insights[:container_type]
    assert_equal 'greet', insights[:container]
    assert_equal 'module.greet()', insights[:ruby_path]
  end

  def test_comment_and_docblock_flags
    results_comment = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /assigning name/,
      mode: 'find_in_file'
    ).results
    assert_equal true, results_comment.first[:result].first.insights[:in_comment]

    results_doc = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /File operations helpers/,
      mode: 'find_in_file'
    ).results
    assert_equal true, results_doc.first[:result].first.insights[:in_docstring]
  end

  def test_require_context_present
    results = RegexSearch::Runner.new(
      input: @tmp.path,
      pattern: /module Tools/,
      mode: 'find_in_file'
    ).results
    insights = results.first[:result].first.insights
    assert insights[:require_context].any? { |l| l.start_with?('require ') || l.start_with?('require_relative') }
  end
end


