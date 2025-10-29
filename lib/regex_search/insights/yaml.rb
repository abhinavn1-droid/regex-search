# frozen_string_literal: true

require 'yaml'

module RegexSearch
  module Insights
    # Processor for YAML file insights
    #
    # This processor analyzes YAML files and enriches matches with
    # metadata such as key paths and parent structure.
    class Yaml < Base
      def self.call(input, match)
        new(input).process_match(match)
      end

      def initialize(input)
        # Don't pass arguments to super; Base does not define initialize
        super()
        @input = input
        @yaml_content = parse_yaml
        @flattened_paths = flatten_yaml(@yaml_content)
      end

      def process_match(match)
        match[:insights] = {
          yaml_path: find_yaml_path(match[:line_number]),
          parent_structure: find_parent_structure(match[:line_number])
        }
        match
      end

      private

      def parse_yaml
        YAML.safe_load(@input)
      rescue StandardError => e
        warn "YAML parsing error: #{e.message}"
        {}
      end

      def flatten_yaml(obj, path = [], result = {})
        case obj
        when Hash
          obj.each do |key, value|
            new_path = path + [key]
            result[new_path.join('.')] = value unless value.is_a?(Hash) || value.is_a?(Array)
            flatten_yaml(value, new_path, result)
          end
        when Array
          obj.each_with_index do |value, index|
            new_path = path + [index.to_s]
            result[new_path.join('.')] = value unless value.is_a?(Hash) || value.is_a?(Array)
            flatten_yaml(value, new_path, result)
          end
        end
        result
      end

      def find_yaml_path(line_number)
        # Convert line number to 0-based index for array access
        target_line = @input.split("\n")[line_number - 1]&.strip
        return '' unless target_line

        processed = target_line.sub(/^\s*-\s*/, '')
        # If the line contains a key/value pair, extract the value side
        processed = processed.split(':', 2).last&.strip || processed

        @flattened_paths.find do |_path, value|
          value.to_s == processed
        end&.first || ''
      end

      def find_parent_structure(line_number)
        path = find_yaml_path(line_number)
        return {} if path.empty?

        parent_path = path.split('.')[0..-2].join('.')
        return {} if parent_path.empty?

        # Navigate the YAML structure to find the parent
        current = @yaml_content
        parent_path.split('.').each do |key|
          current = current[key] if current.is_a?(Hash)
          current = current[key.to_i] if current.is_a?(Array) && key.match?(/^\d+$/)
        end

        current.is_a?(Hash) || current.is_a?(Array) ? current : {}
      end
    end

    # NOTE: YAML file type registration is done in insights.rb
  end
end
