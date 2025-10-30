# frozen_string_literal: true

require 'test_helper'

class TestInsightsMsg < Minitest::Test
  def setup
    @msg_file = File.join(__dir__, '../../fixtures/sample.msg')
  end

  def test_msg_insights_extracts_sender_and_recipients
    match = { captures: [['test']], line_number: 1, line: 'test subject' }
    input = { path: @msg_file }
    result = RegexSearch::Insights::Msg.call(input, match)

    assert result[:insights][:msg_from]
    assert result[:insights][:msg_from].include?('Abhinav')
    assert result[:insights][:msg_to].is_a?(Array)
    assert result[:insights][:msg_to].any? { |to| to.include?('abhinavnain') }
  end

  def test_msg_insights_extracts_subject_and_date
    match = { captures: [['test']], line_number: 1, line: 'test subject' }
    input = { path: @msg_file }
    result = RegexSearch::Insights::Msg.call(input, match)

    assert result[:insights].key?(:msg_subject)
    assert_equal 'Test Email', result[:insights][:msg_subject]
    assert result[:insights].key?(:msg_date)
  end

  def test_msg_insights_identifies_match_location_in_subject
    match = { captures: [['Test Email']], line_number: 1, line: 'Test Email ' }
    input = { path: @msg_file }
    result = RegexSearch::Insights::Msg.call(input, match)

    # Match is in subject
    assert_equal 'subject', result[:insights][:msg_location]
    assert_nil result[:insights][:msg_body_type]
  end

  def test_msg_insights_identifies_match_location_in_body
    match = { captures: [['test body']], line_number: 1, line: 'test body' }
    input = { path: @msg_file }
    result = RegexSearch::Insights::Msg.call(input, match)

    # Match is in body
    assert_equal 'body', result[:insights][:msg_location]
    assert_equal 'html', result[:insights][:msg_body_type]
  end

  def test_msg_insights_handles_body_type
    match = { captures: [['email']], line_number: 1, line: 'An email with test subject' }
    input = { path: @msg_file }
    result = RegexSearch::Insights::Msg.call(input, match)

    # Body type should be html for this message
    assert_equal 'body', result[:insights][:msg_location]
    assert_equal 'html', result[:insights][:msg_body_type]
  end

  def test_msg_file_type_detection_and_integration
    # Test file type detection
    detected_type = RegexSearch::FileTypeDetector.detect(@msg_file)
    assert_equal :msg, detected_type

    # Test processor is registered
    processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:msg]
    assert_equal RegexSearch::Insights::Msg, processor
  end

  def test_msg_insights_handles_missing_file_gracefully
    match = { captures: [['test']], line_number: 1, line: 'test message' }
    input = { path: 'nonexistent.msg' }
    result = RegexSearch::Insights::Msg.call(input, match)

    # Should have error in insights
    assert result[:insights].key?(:error)
  end
end

