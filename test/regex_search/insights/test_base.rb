# frozen_string_literal: true

require 'test_helper'

class TestInsightsBase < Minitest::Test
  def test_base_does_not_modify_match
    match = { line: 'hello', captures: [['hello']] }
    result = RegexSearch::Insights::Base.call(nil, match) # constructor is a no‑op
    # Base has no .call, so Searcher will just return match unchanged
    assert_equal(result, match)
  end
end
