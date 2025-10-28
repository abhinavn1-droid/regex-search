# frozen_string_literal: true

module RegexSearch
  module Insights
    # Base class for all insight processors
    #
    # This class serves as the base implementation and interface for all
    # file-type specific insight processors. It defines the minimal interface
    # that all insight processors must implement.
    #
    # Subclasses should override {call} to provide file-type specific insights.
    #
    # @example Creating a custom insight processor
    #   class MyInsight < RegexSearch::Insights::Base
    #     def self.call(input, match)
    #       match[:insights] = { custom_data: analyze(match[:line]) }
    #       match
    #     end
    #   end
    class Base
      # Process a match and add any relevant insights
      #
      # @param _ [Hash] The input metadata (unused in base class)
      # @param match [Hash] The match data to analyze
      # @return [Hash] The match with any added insights
      def self.call(_, match)  
        match
      end
    end
  end
end
