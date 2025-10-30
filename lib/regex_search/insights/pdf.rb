# frozen_string_literal: true

require 'pdf-reader'
require_relative 'base'

module RegexSearch
  module Insights
    # Provides PDF-specific insights for search matches, including encryption handling
    class PDF < Base
      # Processes a match found in a PDF file to add PDF-specific insights.
      #
      # @param input [Hash] Input data including:
      #   - :path [String] The path to the PDF file
      #   - :password [String, nil] Optional password for encrypted PDFs
      # @param match [Hash] Match data including:
      #   - :line_number [Integer] Line number where match was found
      #   - :line [String] The line containing the match
      #   - :captures [Array] Captured groups from the regex
      # @return [Hash] Match with added insights
      def self.call(input, match)
        file_path = input[:path]
        password = input[:password]

        begin
          # Attempt to open the PDF, with optional password
          reader = open_pdf(file_path, password)
          
          # Detect if PDF is encrypted
          encryption_info = detect_encryption(reader, file_path, password)
          
          # If encrypted and couldn't decrypt, return early with encryption info
          if encryption_info[:encrypted] && !encryption_info[:decryptable]
            match[:insights] = encryption_info
            return match
          end

          # Extract PDF context for the match
          page_num = find_page_for_match(reader, match[:line])
          
          if page_num
            match[:insights] = {
              pdf_page: page_num,
              pdf_metadata: extract_metadata(reader),
              section_context: extract_section_context(reader, page_num, match[:line]),
              encrypted: encryption_info[:encrypted],
              decryptable: encryption_info[:decryptable]
            }
          else
            match[:insights] = encryption_info
          end

        rescue ::PDF::Reader::EncryptedPDFError => e
          # PDF is encrypted and no password provided, or wrong password
          match[:insights] = {
            encrypted: true,
            decryptable: false,
            error: 'PDF is encrypted',
            reason: password.nil? ? 'missing_password' : 'wrong_password',
            error_message: e.message
          }
        rescue ::PDF::Reader::MalformedPDFError, ::PDF::Reader::UnsupportedFeatureError => e
          # PDF has issues (possibly unsupported encryption)
          match[:insights] = {
            encrypted: true,
            decryptable: false,
            error: 'PDF processing error',
            reason: 'unsupported_encryption',
            error_message: e.message
          }
        rescue StandardError => e
          # Other errors
          match[:insights] = {
            error: 'PDF processing error',
            error_message: e.message
          }
        end

        match
      end

      # Opens a PDF with optional password
      #
      # @api private
      # @param file_path [String] Path to the PDF file
      # @param password [String, nil] Optional password
      # @return [PDF::Reader] The PDF reader instance
      def self.open_pdf(file_path, password)
        opts = {}
        opts[:password] = password if password
        ::PDF::Reader.new(file_path, opts)
      end

      # Detects if a PDF is encrypted and if it was successfully decrypted
      #
      # @api private
      # @param reader [PDF::Reader] The PDF reader instance
      # @param file_path [String] Path to the PDF file
      # @param password [String, nil] Password used (if any)
      # @return [Hash] Encryption information
      def self.detect_encryption(reader, file_path, password)
        # Check if PDF has encryption metadata
        security_handler = reader.objects.instance_variable_get(:@sec_handler)
        
        # NullSecurityHandler means no encryption or successfully decrypted
        is_encrypted = !security_handler.is_a?(::PDF::Reader::NullSecurityHandler)
        
        # If we can read metadata, it's decryptable
        decryptable = !is_encrypted || can_read_content?(reader)
        
        {
          encrypted: is_encrypted,
          decryptable: decryptable,
          security_handler: security_handler.class.name,
          password_provided: !password.nil?
        }
      rescue StandardError
        # If we can't determine encryption status, assume not encrypted
        { encrypted: false, decryptable: true, password_provided: !password.nil? }
      end

      # Checks if PDF content can be read (i.e., decryption was successful)
      #
      # @api private
      # @param reader [PDF::Reader] The PDF reader instance
      # @return [Boolean] True if content is readable
      def self.can_read_content?(reader)
        reader.page_count
        reader.info
        true
      rescue StandardError
        false
      end

      # Finds the page number containing the match
      #
      # @api private
      # @param reader [PDF::Reader] The PDF reader instance
      # @param match_line [String] The line to find
      # @return [Integer, nil] Page number (1-based) or nil
      def self.find_page_for_match(reader, match_line)
        return nil unless reader

        1.upto(reader.page_count) do |page_num|
          page_text = extract_page_text(reader, page_num)
          
          # Try exact match first
          return page_num if page_text.include?(match_line)
          
          # Try line-by-line match
          page_lines = page_text.split("\n").map(&:strip)
          match_lines = match_line.to_s.split("\n").map(&:strip)
          
          match_lines.each do |search_line|
            return page_num if page_lines.any? { |line| line.include?(search_line) }
          end
        end

        nil
      rescue StandardError => e
        warn "Error finding page for match: #{e.message}"
        nil
      end

      # Extracts text from a specific page
      #
      # @api private
      # @param reader [PDF::Reader] The PDF reader instance
      # @param page_num [Integer] Page number (1-based)
      # @return [String] Page text
      def self.extract_page_text(reader, page_num)
        page = reader.page(page_num)
        text = page.text
        text.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      rescue StandardError => e
        warn "Error extracting page #{page_num} text: #{e.message}"
        ''
      end

      # Extracts PDF metadata
      #
      # @api private
      # @param reader [PDF::Reader] The PDF reader instance
      # @return [Hash] PDF metadata
      def self.extract_metadata(reader)
        {
          title: reader.info[:Title],
          author: reader.info[:Author],
          creator: reader.info[:Creator],
          producer: reader.info[:Producer],
          creation_date: reader.info[:CreationDate],
          page_count: reader.page_count
        }
      rescue StandardError => e
        warn "Error extracting metadata: #{e.message}"
        {}
      end

      # Extracts section context for a match
      #
      # @api private
      # @param reader [PDF::Reader] The PDF reader instance
      # @param page_num [Integer] Page number (1-based)
      # @param match_line [String] The line containing the match
      # @return [Hash] Section context
      def self.extract_section_context(reader, page_num, match_line)
        page_text = extract_page_text(reader, page_num)
        lines = page_text.split("\n").map(&:strip)
        
        match_index = lines.index(match_line.to_s.strip)
        return {} unless match_index

        heading = find_nearest_heading(lines[0..match_index])
        {
          nearest_heading: heading,
          page_position: calculate_position(match_index, lines.size)
        }
      rescue StandardError => e
        warn "Error extracting section context: #{e.message}"
        {}
      end

      # Finds the nearest heading before a given line
      #
      # @api private
      # @param lines [Array<String>] Lines of text
      # @return [String, nil] The nearest heading
      def self.find_nearest_heading(lines)
        lines.reverse.find do |line|
          next if line.empty?
          # Headings are often all caps, numbered, or Roman numerals
          line.match?(/^[A-Z\d\s]{4,}|^\d+(\.\d+)*\s|^[IVXLCDM]+\.\s/)
        end
      end

      # Calculates the position of a line within a page
      #
      # @api private
      # @param index [Integer] Line index
      # @param total [Integer] Total number of lines
      # @return [Symbol] :top, :middle, or :bottom
      def self.calculate_position(index, total)
        ratio = index.to_f / total
        case ratio
        when 0..0.33 then :top
        when 0.34..0.66 then :middle
        else :bottom
        end
      end
    end
  end
end
