# frozen_string_literal: true

module RegexSearch
  # Provides functionality to extract surrounding context for a matched line
  #
  # The ContextWindow module helps provide before-and-after context for search
  # matches, making it easier to understand the context in which a pattern appears.
  #
  # @example Extract context for a match
  #   data = ["line 1", "line 2", "match", "line 4", "line 5"]
  #   before, after = RegexSearch::ContextWindow.extract(data, 2, 1)
  #   # => ["line 2", "line 4"]
  module ContextWindow
    # Extracts context lines surrounding a specific index in the data
    #
    # @param data [Array<String>] The lines of text to extract context from
    # @param index [Integer] The index of the matched line
    # @param window [Integer] Number of context lines to extract before and after
    # @return [Array<(String, String)>] Tuple of [before_context, after_context]
    def self.extract(data, index, window)
      before = []
      after = []

      (1..window).each do |i|
        before.unshift(data[index - i]) if index - i >= 0
        after.push(data[index + i]) if index + i < data.size
      end

      [before.last, after.first] # preserve 1-line context for now
    end
  end
end
