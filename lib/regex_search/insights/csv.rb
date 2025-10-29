# frozen_string_literal: true

require 'csv'

module RegexSearch
  module Insights
    # CSV-specific insight processor that finds row and column context for matched content
    #
    # This processor analyzes CSV files to provide additional context about
    # where in the CSV structure a match was found. It generates metadata including
    # row index, column name (if headers exist), column index, and symbolic paths.
    #
    # @example CSV insights for a match
    #   # For CSV with headers: name,email,age
    #   #                       John,john@example.com,25
    #   # When searching for "john@example.com":
    #   match[:insights] # => {
    #     row_index: 1,
    #     column_name: "email",
    #     column_index: 1,
    #     csv_path: "data[1][\"email\"]",
    #     row_data: { "name" => "John", "email" => "john@example.com", "age" => "25" }
    #   }
    #
    # @see RegexSearch::Insights::Base
    class Csv < Base
      # Processes a match in a CSV file to find the row and column context
      #
      # @param input [Hash] Input metadata including:
      #   - :path [String] Path to the CSV file (optional)
      #   - :data [String] CSV content to parse
      # @param match [Hash] Match data including:
      #   - :line_number [Integer] Line number where match was found
      #   - :captures [Array<Array<String>>] Captured groups from the regex
      # @return [Hash] Match with added insights:
      #   - insights.row_index [Integer] Zero-based row index (excluding headers if present)
      #   - insights.column_name [String, nil] Column name if headers exist
      #   - insights.column_index [Integer] Zero-based column index
      #   - insights.csv_path [String] Symbolic path to the matched cell
      #   - insights.row_data [Hash, Array] Full row data
      #   - insights.has_headers [Boolean] Whether CSV has headers
      #   - insights.error [String] Error message if CSV is invalid
      def self.call(input, match)
        begin
          # Get the CSV content from input data or file path
          csv_content = input[:data].is_a?(String) ? input[:data] : File.read(input[:path])
          keyword = match[:captures].flatten.first # first captured string
          line_number = match[:line_number]

          csv_data = CSV.parse(csv_content)
          return match.merge(insights: { error: 'Empty CSV' }) if csv_data.empty?

          # Detect if CSV has headers
          has_headers = detect_headers(csv_data)
          headers = has_headers ? csv_data[0] : nil
          data_rows = has_headers ? csv_data[1..-1] : csv_data

          # Find the row and column containing the keyword
          result = find_match_location(data_rows, keyword, line_number, csv_data, has_headers)

          if result
            insights = build_insights(result, headers, has_headers)
            match[:insights] = insights
          else
            match[:insights] = { 
              row_index: nil, 
              column_index: nil, 
              csv_path: nil,
              has_headers: has_headers
            }
          end
        rescue CSV::MalformedCSVError => e
          match[:insights] = { error: "Malformed CSV: #{e.message}" }
        rescue StandardError => e
          match[:insights] = { error: "CSV processing error: #{e.message}" }
        end
        match
      end

      # Detects if the CSV has headers by comparing row patterns
      #
      # @api private
      # @param csv_data [Array<Array<String>>] Parsed CSV data
      # @return [Boolean] True if headers are detected
      def self.detect_headers(csv_data)
        return false if csv_data.length < 2

        first_row = csv_data[0]
        second_row = csv_data[1]

        return false if first_row.length != second_row.length

        # Compare the data types in each column between first and second row
        # If first row has different pattern than second row, likely has headers
        first_row.each_with_index do |cell1, idx|
          cell2 = second_row[idx]
          next unless cell1 && cell2

          is_numeric1 = cell1.strip.match?(/^\d+(\.\d+)?$/)
          is_numeric2 = cell2.strip.match?(/^\d+(\.\d+)?$/)

          # If first row has text where second row has text in same position,
          # and they follow the same pattern, likely no headers
          return true if !is_numeric1 && is_numeric2
        end

        # If all columns have the same pattern, likely no headers
        false
      end

      # Finds the exact location (row and column) of the matched keyword
      #
      # @api private
      # @param data_rows [Array<Array<String>>] CSV data rows (excluding headers)
      # @param keyword [String] The text to search for
      # @param line_number [Integer] Line number from the match
      # @param csv_data [Array<Array<String>>] Full CSV data
      # @param has_headers [Boolean] Whether CSV has headers
      # @return [Hash, nil] Hash with row_index, column_index, and row_data
      def self.find_match_location(data_rows, keyword, line_number, csv_data, has_headers)
        # Try to map line number to CSV row
        # Line number is 1-based, and may include header line
        csv_row_index = has_headers ? line_number - 2 : line_number - 1
        csv_row_index = [csv_row_index, 0].max # Ensure non-negative

        # Search in the specific row first
        if csv_row_index < data_rows.length
          row = data_rows[csv_row_index]
          column_index = row.find_index { |cell| cell && cell.include?(keyword) }
          
          if column_index
            return {
              row_index: csv_row_index,
              column_index: column_index,
              row_data: row
            }
          end
        end

        # If not found in the expected row, search all rows
        data_rows.each_with_index do |row, row_idx|
          column_index = row.find_index { |cell| cell && cell.include?(keyword) }
          if column_index
            return {
              row_index: row_idx,
              column_index: column_index,
              row_data: row
            }
          end
        end

        nil
      end

      # Builds the insights hash with all metadata
      #
      # @api private
      # @param result [Hash] Result from find_match_location
      # @param headers [Array<String>, nil] CSV headers if present
      # @param has_headers [Boolean] Whether CSV has headers
      # @return [Hash] Complete insights hash
      def self.build_insights(result, headers, has_headers)
        row_index = result[:row_index]
        column_index = result[:column_index]
        row_data = result[:row_data]

        column_name = headers ? headers[column_index] : nil

        # Build symbolic path
        if has_headers && column_name
          csv_path = "data[#{row_index}][\"#{column_name}\"]"
          # Build row data as hash with headers
          row_data_formatted = headers.zip(row_data).to_h
        else
          csv_path = "data[#{row_index}][#{column_index}]"
          row_data_formatted = row_data
        end

        {
          row_index: row_index,
          column_name: column_name,
          column_index: column_index,
          csv_path: csv_path,
          row_data: row_data_formatted,
          has_headers: has_headers
        }
      end
    end
  end
end

