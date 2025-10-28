# frozen_string_literal: true

module RegexSearch
  module ContextWindow
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
