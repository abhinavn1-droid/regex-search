#!/usr/bin/env ruby
# frozen_string_literal: true

require 'test_helper'

class TestResult < Minitest::Test
  def test_result_attributes_and_to_h
    match = {
      line_number: 2,
      line: 'ruby is awesome',
      context_before: 'hello',
      context_after: 'end',
      captures: [['ruby']],
      insights: { example: true },
      tags: [:contains_word],
      enrichment: { capture_count: 1 }
    }

    input = { path: 'sample.txt', filetype: :txt }

    result = RegexSearch::Result.new(match: match, input: input)

    assert_equal 2, result.line_number
    assert_equal 'ruby is awesome', result.line
    assert_equal 'sample.txt', result.path
    assert_equal :txt, result.filetype

    h = result.to_h
    assert_equal 'sample.txt', h[:path]
    assert_equal :txt, h[:filetype]
    assert_equal 2, h[:match][:line_number]
    assert_match(/ruby/, h[:match][:line])
    assert_equal 1, h[:match][:captures].flatten.size
    assert_equal result.insights, h[:match][:insights]
  end
end
