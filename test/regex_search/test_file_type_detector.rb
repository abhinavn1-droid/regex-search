#!/usr/bin/env ruby
# frozen_string_literal: true

require 'test_helper'

# The library file requires the 'marcel' gem. Tests should not fail if
# marcel is not installed, so provide a minimal stub for Marcel::MimeType
# when marcel isn't available.
begin
  require 'marcel'
rescue LoadError
  module Marcel
    class MimeType
      def self.for(*)
        nil
      end
    end
  end
end

require 'regex_search/file_type_detector'

class TestFileTypeDetector < Minitest::Test
  def test_fallback_returns_txt_for_no_extension
    assert_equal :txt, RegexSearch::FileTypeDetector.fallback('filename')
  end

  def test_fallback_respects_extension
    assert_equal :json, RegexSearch::FileTypeDetector.fallback('data.json')
    assert_equal :txt, RegexSearch::FileTypeDetector.fallback('notes.TXT')
  end

  def test_detect_uses_marcel_when_available
    # stub Marcel::MimeType.for to return a known mime
    Marcel::MimeType.define_singleton_method(:for) { 'application/json' }

    assert_equal :unknown, RegexSearch::FileTypeDetector.detect('somefile.unknown')
  ensure
    # restore a neutral implementation
    Marcel::MimeType.define_singleton_method(:for) { nil }
  end
end
