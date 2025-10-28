# frozen_string_literal: true

require 'minitest/autorun'
require 'logger'

# Require only the library files needed by tests to avoid loading optional gems
require_relative '../lib/regex_search/searcher'
require_relative '../lib/regex_search/insights'
require_relative '../lib/regex_search/errors'
require_relative '../lib/regex_search/result'
require_relative '../lib/regex_search/context_window'
require_relative '../lib/regex_search/insight_pipeline'
