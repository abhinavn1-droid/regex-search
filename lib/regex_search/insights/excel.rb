# frozen_string_literal: true

require 'roo'

module RegexSearch
  module Insights
    # Excel-specific insight processor that finds cell locations across sheets
    #
    # This processor analyzes Excel files (.xlsx, .xls) to provide context about
    # where in the spreadsheet structure a match was found. It generates metadata
    # including sheet name, row/column indices, header names, and symbolic paths.
    #
    # @example Excel insights for a match
    #   # For Excel with sheet "Users" and headers: Name, Email, Age
    #   #                                Row 2: John, john@example.com, 25
    #   # When searching for "john@example.com":
    #   match[:insights] # => {
    #     sheet_name: "Users",
    #     row_index: 1,
    #     column_index: 1,
    #     column_header: "Email",
    #     cell_reference: "Users!B2",
    #     excel_path: 'workbook["Users"][1]["Email"]',
    #     row_data: {"Name" => "John", "Email" => "john@example.com", "Age" => "25"},
    #     has_headers: true
    #   }
    #
    # @see RegexSearch::Insights::Base
    class Excel < Base
      # Processes a match in an Excel file to find sheet and cell context
      #
      # @param input [Hash] Input metadata including:
      #   - :path [String] Path to the Excel file
      # @param match [Hash] Match data including:
      #   - :line_number [Integer] Line number where match was found
      #   - :captures [Array<Array<String>>] Captured groups from the regex
      # @return [Hash] Match with added insights:
      #   - insights.sheet_name [String] Name of the sheet
      #   - insights.row_index [Integer] Zero-based row index (excluding headers)
      #   - insights.column_index [Integer] Zero-based column index
      #   - insights.column_header [String, nil] Column header if present
      #   - insights.cell_reference [String] Excel cell reference (e.g., "Sheet1!B2")
      #   - insights.excel_path [String] Symbolic path to cell
      #   - insights.row_data [Hash, Array] Full row data
      #   - insights.has_headers [Boolean] Whether sheet has headers
      #   - insights.error [String] Error message if processing fails
      def self.call(input, match)
        begin
          file_path = input[:path]
          keyword = match[:captures].flatten.first
          
          spreadsheet = Roo::Spreadsheet.open(file_path)
          
          # Search across all sheets
          result = find_match_in_spreadsheet(spreadsheet, keyword)
          
          if result
            insights = build_excel_insights(result, spreadsheet)
            match[:insights] = insights
          else
            match[:insights] = {
              sheet_name: nil,
              row_index: nil,
              column_index: nil,
              cell_reference: nil
            }
          end
        rescue StandardError => e
          match[:insights] = { error: "Excel processing error: #{e.message}" }
        end
        match
      end

      # Finds the match across all sheets in the spreadsheet
      #
      # @api private
      # @param spreadsheet [Roo::Spreadsheet] The opened spreadsheet
      # @param keyword [String] The text to search for
      # @return [Hash, nil] Match location details
      def self.find_match_in_spreadsheet(spreadsheet, keyword)
        spreadsheet.sheets.each do |sheet_name|
          spreadsheet.sheet(sheet_name)
          
          # Detect if sheet has headers
          has_headers = detect_headers(spreadsheet)
          first_data_row = has_headers ? 2 : 1
          headers = has_headers ? spreadsheet.row(1) : nil
          
          # Search through all rows
          (first_data_row..spreadsheet.last_row).each do |row_num|
            row_data = spreadsheet.row(row_num)
            
            # Search through all columns in the row
            row_data.each_with_index do |cell_value, col_idx|
              next unless cell_value && cell_value.to_s.include?(keyword)
              
              # Found a match
              return {
                sheet_name: sheet_name,
                row_number: row_num,
                column_index: col_idx,
                row_data: row_data,
                headers: headers,
                has_headers: has_headers,
                spreadsheet: spreadsheet
              }
            end
          end
        end
        
        nil
      end

      # Detects if the current sheet has headers
      #
      # @api private
      # @param spreadsheet [Roo::Spreadsheet] The spreadsheet with active sheet
      # @return [Boolean] True if headers are detected
      def self.detect_headers(spreadsheet)
        return false if spreadsheet.last_row < 2
        
        first_row = spreadsheet.row(1)
        second_row = spreadsheet.row(2)
        
        return false if first_row.length != second_row.length
        
        # Compare data types between first and second row
        first_row.each_with_index do |cell1, idx|
          cell2 = second_row[idx]
          next unless cell1 && cell2
          
          # If first row has text where second has number, likely headers
          is_numeric1 = cell1.is_a?(Numeric) || cell1.to_s.match?(/^\d+(\.\d+)?$/)
          is_numeric2 = cell2.is_a?(Numeric) || cell2.to_s.match?(/^\d+(\.\d+)?$/)
          
          return true if !is_numeric1 && is_numeric2
        end
        
        false
      end

      # Builds comprehensive Excel insights from match result
      #
      # @api private
      # @param result [Hash] Match location details
      # @param spreadsheet [Roo::Spreadsheet] The spreadsheet
      # @return [Hash] Complete insights hash
      def self.build_excel_insights(result, spreadsheet)
        sheet_name = result[:sheet_name]
        row_number = result[:row_number]
        column_index = result[:column_index]
        headers = result[:headers]
        has_headers = result[:has_headers]
        row_data = result[:row_data]
        
        # Calculate zero-based row index (excluding headers)
        row_index = has_headers ? row_number - 2 : row_number - 1
        
        # Get column header if available
        column_header = headers ? headers[column_index] : nil
        
        # Build Excel cell reference (e.g., "Sheet1!B2")
        column_letter = column_index_to_letter(column_index + 1)
        cell_reference = "#{sheet_name}!#{column_letter}#{row_number}"
        
        # Build symbolic path
        if has_headers && column_header
          excel_path = "workbook[\"#{sheet_name}\"][#{row_index}][\"#{column_header}\"]"
          # Build row data as hash with headers
          row_data_formatted = headers.zip(row_data).to_h
        else
          excel_path = "workbook[\"#{sheet_name}\"][#{row_index}][#{column_index}]"
          row_data_formatted = row_data
        end
        
        {
          sheet_name: sheet_name,
          row_index: row_index,
          column_index: column_index,
          column_header: column_header,
          cell_reference: cell_reference,
          excel_path: excel_path,
          row_data: row_data_formatted,
          has_headers: has_headers
        }
      end

      # Converts a column index to Excel column letter(s)
      #
      # @api private
      # @param num [Integer] Column number (1-based)
      # @return [String] Column letter(s) (A, B, ..., Z, AA, AB, ...)
      def self.column_index_to_letter(num)
        result = ''
        while num > 0
          num -= 1
          result = ((num % 26) + 65).chr + result
          num /= 26
        end
        result
      end
    end
  end
end

