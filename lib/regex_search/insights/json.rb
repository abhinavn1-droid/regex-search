# lib/regex_search/insights/json.rb
# frozen_string_literal: true

require 'json'

module RegexSearch
  module Insights
    # JSON-specific insight processor that finds JSON paths to matched content
    #
    # This processor analyzes JSON files to provide additional context about
    # where in the JSON structure a match was found. It generates JSONPath-like
    # expressions to help locate the matched content.
    #
    # @example JSON insights for a match
    #   # For JSON: {"users": [{"name": "Ruby"}]}
    #   # When searching for "Ruby":
    #   match[:insights] # => { json_path: 'data["users"][0]["name"]' }
    #
    # @see RegexSearch::Insights::Base
    class Json < Base
      # Processes a match in a JSON file to find the JSON path to the matched content
      #
      # @param input [Hash] Input metadata including:
      #   - :path [String] Path to the JSON file
      # @param match [Hash] Match data including:
      #   - :captures [Array<Array<String>>] Captured groups from the regex
      # @return [Hash] Match with added insights:
      #   - insights.json_path [String, nil] Path to matched content
      #   - insights.error [String] Error message if JSON is invalid
      def self.call(input, match)
        begin
          json_data = JSON.parse(File.read(input[:path]))
          keyword   = match[:captures].flatten.first # first captured string

          path = find_path(json_data, keyword)
          match[:insights] = if path
                               { json_path: path }
                             else
                               { json_path: nil }
                             end
        rescue JSON::ParserError
          match[:insights] = { error: 'Invalid JSON' }
        end
        match
      end

      # Recursively searches a JSON structure for a value containing the keyword
      #
      # @api private
      # @param obj [Hash, Array, Object] The JSON structure to search
      # @param keyword [String] The text to search for
      # @param current_path [String] The current path in the JSON structure
      # @return [String, nil] JSONPath-like expression to the matching value
      def self.find_path(obj, keyword, current_path: 'data')
        case obj
        when Hash
          return process_hash(obj, keyword, current_path: current_path)
        when Array
          return process_array(obj, keyword, current_path: current_path)
        end
        nil
      end

      # Processes an array node in the JSON structure
      #
      # @api private
      # @param obj [Array] The array to search
      # @param keyword [String] The text to search for
      # @param current_path [String] The current path in the JSON structure
      # @return [String, nil] JSONPath-like expression if found
      def self.process_array(obj, keyword, current_path:)
        obj.each_with_index do |v, i|
          new_path = "#{current_path}[#{i}]"
          return new_path if v.is_a?(String) && v.include?(keyword)

          found = find_path(v, keyword, current_path: new_path)
          return found if found
        end
      end

      # Processes a hash/object node in the JSON structure
      #
      # @api private
      # @param obj [Hash] The hash to search
      # @param keyword [String] The text to search for
      # @param current_path [String] The current path in the JSON structure
      # @return [String, nil] JSONPath-like expression if found
      def self.process_hash(obj, keyword, current_path:)
        obj.each do |k, v|
          new_path = "#{current_path}[\"#{k}\"]"
          return new_path if v.is_a?(String) && v.include?(keyword)

          found = find_path(v, keyword, current_path: new_path)
          return found if found
        end
      end
    end
  end
end
