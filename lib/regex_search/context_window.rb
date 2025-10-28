# frozen_string_literal: true

module RegexSearch
  # Provides functionality to extract surrounding context for a matched line
  #
  # The ContextWindow class helps provide before-and-after context for search
  # matches, making it easier to understand the context in which a pattern appears.
  #
  # @example Create a context window
  #   window = ContextWindow.new(["line 1", "line 2", "match", "line 4"], 2)
  #   window.move_to(2)
  #   before = window.before # => "line 2"
  #   after = window.after  # => "line 4"
  class ContextWindow
    # @return [String, nil] The line before the current position
    attr_reader :before

    # @return [String, nil] The line after the current position
    attr_reader :after

    # Initialize a new ContextWindow
    #
    # @param lines [Array<String>] The lines of text
    # @param window_size [Integer] Number of context lines to include
    def initialize(lines, window_size = 1)
      @lines = lines
      @window_size = window_size
      @before = nil
      @after = nil
    end

    # Move the window to a new position
    #
    # @param index [Integer] The index to move to
    def move_to(index)
      @before, @after = extract(index, @window_size)
    end

    private

    # Extract context lines surrounding a specific index
    #
    # @param index [Integer] The index of the matched line
    # @param window [Integer] Number of context lines to include
    # @return [Array<(String, String)>] Tuple of [before_context, after_context]
    def extract(index, window)
      before = []
      after = []

      (1..window).each do |i|
        before.unshift(@lines[index - i]) if index - i >= 0
        after.push(@lines[index + i]) if index + i < @lines.size
      end

      [before.last, after.first]
    end
  end
end
