# frozen_string_literal: true

require_relative 'result'

module RegexSearch
  # Provides filtering capabilities for search results
  #
  # This module allows filtering search results based on various criteria
  # such as keywords, tags, or insights data.
  #
  # @example Filter results containing a keyword
  #   results = RegexSearch::MatchFilter.filter(results, keyword: 'important')
  #
  # @example Filter by multiple criteria
  #   results = RegexSearch::MatchFilter.filter(
  #     results,
  #     keyword: 'config',
  #     tags: [:contains_url],
  #     min_context_density: 2
  #   )
  module MatchFilter
    # Filter search results based on specified criteria
    #
    # @param results [Array<Hash>] The search results to filter
    # @param keyword [String, nil] Optional keyword to search within matches
    # @param tags [Array<Symbol>, nil] Required tags for matches
    # @param min_context_density [Integer, nil] Minimum context density
    # @param exclude_patterns [Array<Regexp>, nil] Patterns to exclude
    # @param file_types [Array<Symbol>, nil] Filter by file types
    # @return [Array<Hash>] Filtered search results
    def self.filter(results, keyword: nil, tags: nil, min_context_density: nil,
                    exclude_patterns: nil, file_types: nil)
      results.map do |file_result|
        matches = file_result[:result].select do |match|
          matches_criteria?(match, keyword, tags, min_context_density, exclude_patterns) &&
            matches_file_type?(file_result[:filetype], file_types)
        end
        file_result.merge(result: matches)
      end.reject { |fr| fr[:result].empty? }
    end

    class << self
      private

      def matches_criteria?(match, keyword, tags, min_context_density, exclude_patterns)
        return false if keyword && !match_contains_keyword?(match, keyword)
        return false if tags && !has_required_tags?(match, tags)
        return false if min_context_density && !meets_density?(match, min_context_density)
        return false if exclude_patterns && matches_excluded_pattern?(match, exclude_patterns)

        true
      end

      def match_contains_keyword?(match, keyword)
        return true if match.line.include?(keyword)
        return true if match.context_before&.include?(keyword)
        return true if match.context_after&.include?(keyword)

        false
      end

      def has_required_tags?(match, required_tags)
        required_tags.all? { |tag| match.tags.include?(tag) }
      end

      def meets_density?(match, min_density)
        match.enrichment[:context_density] >= min_density
      end

      def matches_excluded_pattern?(match, patterns)
        patterns.any? do |pattern|
          match.line =~ pattern ||
            match.context_before&.match?(pattern) ||
            match.context_after&.match?(pattern)
        end
      end

      def matches_file_type?(file_type, required_types)
        return true unless required_types
        required_types.include?(file_type)
      end
    end
  end
end
