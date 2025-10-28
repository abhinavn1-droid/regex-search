# frozen_string_literal: true

require 'test_helper'
require 'tempfile'
require 'json'

class TestInsightsJson < Minitest::Test
  def test_json_insights_adds_path
    Tempfile.create(['sample', '.json']) do |f|
      f.write({ data: [{ key2: 'ruby is awesome' }] }.to_json)
      f.rewind

      fd = { path: f.path }
      match = { captures: [['ruby']], line: 'ruby is awesome' }
      result = RegexSearch::Insights::Json.call(fd, match)

      assert result[:insights].key?(:json_path)
      assert_match(/key2/, result[:insights][:json_path])
    end
  end

  def test_json_insights_handles_invalid_json
    Tempfile.create(['bad', '.json']) do |f|
      f.write('not json')
      f.rewind

      fd = { path: f.path }
      match = { captures: [['ruby']], line: 'ruby' }
      result = RegexSearch::Insights::Json.call(fd, match)

      assert_equal 'Invalid JSON', result[:insights][:error]
    end
  end
end
