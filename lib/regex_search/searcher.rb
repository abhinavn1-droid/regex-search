# frozen_string_literal: true

require_relative 'result'
require_relative 'context_window'

module RegexSearch
  module Searcher
    module_function

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

          before, after = ContextWindow.extract(data, idx, context_lines)

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
