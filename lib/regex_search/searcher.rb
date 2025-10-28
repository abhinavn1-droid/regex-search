# frozen_string_literal: true

module RegexSearch
  module Searcher
    module_function

    def search(inputs, pattern, options = {})
      regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern)
      stop_at_first = options.fetch(:stop_at_first_match, false)

      inputs.map do |input|
        data = input[:data].is_a?(String) ? input[:data].lines : input[:data]
        matches = []

        data.each_with_index do |line, idx|
          next unless line =~ regex

          match = {
            line_number: idx + 1,
            line: line.chomp,
            context_before: data[[0, idx - 1].max],
            context_after: data[idx + 1],
            captures: line.scan(regex)
          }

          # Apply insights post‑processing
          match = input[:insights_klass].call(input, match)

          matches << match
          break if stop_at_first
        end

        input.merge(result: matches)
      end
    end
  end
end
