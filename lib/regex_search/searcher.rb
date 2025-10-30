# frozen_string_literal: true

require_relative 'result'
require_relative 'context_window'
require_relative 'insight_pipeline'

module RegexSearch
  # The Searcher module provides the core search functionality for RegexSearch.
  # It handles pattern matching, context extraction, and result processing.
  #
  # @example Basic search with context
  #   input = { data: "line1\nline2\nruby\nline4\n", path: 'test.txt' }
  #   results = RegexSearch::Searcher.search([input], /ruby/, context_lines: 2)
  #
  # @see RegexSearch::Result
  # @see RegexSearch::ContextWindow
  module Searcher
    module_function

    # Searches for pattern matches in the given inputs with context
    #
    # @param inputs [Array<Hash>] Array of input hashes containing:
    #   - :data [String, Array<String>] The content to search
    #   - :path [String, nil] Path to the source file (if applicable)
    #   - :insights_klass [Class] The insights processor to use
    # @param pattern [Regexp, String] The pattern to search for
    # @param options [Hash] Search options
    # @option options [Logger] :logger (Logger.new(nil)) Logger instance
    # @option options [Integer] :context_lines (1) Number of context lines
    # @option options [Boolean] :stop_at_first_match (false) Stop at first match
    #
    # @return [Array<Hash>] Array of input hashes with :result key containing matches
    #
    # @example Search with custom options
    #   inputs = [{ data: content, path: 'file.rb' }]
    #   results = RegexSearch::Searcher.search(
    #     inputs,
    #     /pattern/,
    #     context_lines: 2,
    #     stop_at_first_match: true
    #   )
    def search(inputs, pattern, options = {})
      logger = options[:logger] || Logger.new(nil)
      regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern)
      context_lines = options.fetch(:context_lines, 1)
      stop_at_first = options.fetch(:stop_at_first_match, false)

      inputs.map do |input|
        data = input[:data].is_a?(String) ? input[:data].lines : input[:data]
        matches = []

        data.each_with_index do |line, idx|
          next unless line =~ regex

          window = ContextWindow.new(data, context_lines)
          window.move_to(idx)
          before = window.before
          after = window.after

          match = {
            line_number: idx + 1,
            line: line.chomp,
            context_before: before,
            context_after: after,
            captures: line.scan(regex)
          }

          match = InsightPipeline.run(input[:insights_klass], input, match, logger)
          matches << Result.new(match: match, input: input)
          break if stop_at_first
        end

        input.merge(result: matches)
      end
    end
  end
end
