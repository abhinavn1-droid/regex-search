# lib/regex_search/insights/json.rb
# frozen_string_literal: true

require 'json'

module RegexSearch
  module Insights
    class Json < Base
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

      # Recursively search for a value containing the keyword
      def self.find_path(obj, keyword, current_path: 'data')
        case obj
        when Hash
          return process_hash(obj, keyword, current_path: current_path)
        when Array
          return process_array(obj, keyword, current_path: current_path)
        end
        nil
      end

      def self.process_array(obj, keyword, current_path:)
        obj.each_with_index do |v, i|
          new_path = "#{current_path}[#{i}]"
          return new_path if v.is_a?(String) && v.include?(keyword)


          found = find_path(v, keyword, current_path: new_path)
          return found if found
        end
      end

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
