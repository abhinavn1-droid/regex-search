# frozen_string_literal: true

require 'rtf'

module RegexSearch
  module Insights
    # RTF-specific insight processor for .rtf files
    #
    # This processor analyzes RTF (Rich Text Format) documents to provide
    # context about where in the document structure a match was found,
    # including section indices, paragraph indices, and formatting metadata.
    #
    # @example RTF insights for a match
    #   match[:insights] # => {
    #     rtf_section: 1,
    #     rtf_paragraph: 4,
    #     rtf_style: "bold",
    #     rtf_path: "section[1].paragraph[4]"
    #   }
    #
    # @see RegexSearch::Insights::Base
    class Rtf < Base
      # Processes a match in an RTF document
      #
      # @param input [Hash] Input metadata including:
      #   - :path [String] Path to the RTF file
      # @param match [Hash] Match data including:
      #   - :line_number [Integer] Line number where match was found
      #   - :line [String] The line containing the match
      #   - :captures [Array] Captured groups from the regex
      # @return [Hash] Match with added insights
      def self.call(input, match)
        begin
          file_path = input[:path]
          keyword = match[:captures].flatten.first
          line_text = match[:line]
          
          # Parse RTF document
          rtf_content = File.read(file_path)
          document = parse_rtf(rtf_content)
          
          # Find the paragraph containing the match
          context = find_paragraph_context(document, keyword, line_text)
          
          match[:insights] = context
        rescue StandardError => e
          match[:insights] = { error: "RTF processing error: #{e.message}" }
        end
        match
      end

      # Parses an RTF document and extracts structure
      #
      # @api private
      # @param rtf_content [String] The raw RTF content
      # @return [Hash] Document structure information
      def self.parse_rtf(rtf_content)
        # Extract text content by parsing the RTF
        # RTF format stores text with control words - we need to extract plain text
        plain_text = extract_plain_text(rtf_content)
        
        # Split into paragraphs
        paragraphs = plain_text.split(/\n+/).reject(&:empty?).map(&:strip)
        
        # Build document structure
        {
          paragraphs: paragraphs.map.with_index do |para_text, idx|
            {
              index: idx,
              text: para_text,
              section: determine_section(paragraphs, idx),
              formatting: extract_formatting(rtf_content, para_text)
            }
          end
        }
      end

      # Extracts plain text from RTF content
      #
      # @api private
      # @param rtf_content [String] The raw RTF content
      # @return [String] Plain text extracted from RTF
      def self.extract_plain_text(rtf_content)
        # Remove RTF control words and extract plain text
        # RTF control words start with backslash
        text = rtf_content.dup
        
        # First, replace \par with newlines (before removing other control words)
        text = text.gsub(/\\par\s*/, "\n")
        
        # Remove RTF header
        text = text.sub(/^\{\\rtf.*?\n/, '')
        
        # Remove font table
        text = text.gsub(/\{\\fonttbl.*?\}/, '')
        
        # Remove color table
        text = text.gsub(/\{\\colortbl.*?\}/, '')
        
        # Remove control words like \b, \i, \fs20, etc. (but preserve the space/text after)
        text = text.gsub(/\\[a-z]+(-?\d+)?\s*/, ' ')
        
        # Remove control symbols
        text = text.gsub(/\\[^a-z\s]/, '')
        
        # Remove braces
        text = text.gsub(/[{}]/, '')
        
        # Normalize whitespace within lines
        text = text.gsub(/ +/, ' ')
        
        # Clean up
        text = text.strip
        
        text
      end

      # Determines the section index for a paragraph
      #
      # @api private
      # @param paragraphs [Array<String>] All paragraphs in the document
      # @param para_index [Integer] Index of the current paragraph
      # @return [Integer] Section index
      def self.determine_section(paragraphs, para_index)
        # Count how many potential section headers appear before this paragraph
        section_count = 0
        paragraphs[0...para_index].each do |para|
          # Heuristic: short paragraphs (< 50 chars) might be section headers
          section_count += 1 if para.length < 50 && para.length > 0
        end
        [section_count, 1].max # At least section 1
      end

      # Extracts formatting information for a text segment
      #
      # @api private
      # @param rtf_content [String] The raw RTF content
      # @param text_segment [String] The text to find formatting for
      # @return [String] Formatting description
      def self.extract_formatting(rtf_content, text_segment)
        # Look for formatting control words near this text
        formatting = []
        
        # Check for bold (\b)
        if rtf_content.include?("\\b") && rtf_content.index(text_segment[0..10])
          text_pos = rtf_content.index(text_segment[0..10])
          preceding = rtf_content[0...text_pos][-50..-1] || ''
          formatting << 'bold' if preceding.include?('\\b') && !preceding.include?('\\b0')
        end
        
        # Check for italic (\i)
        if rtf_content.include?("\\i") && rtf_content.index(text_segment[0..10])
          text_pos = rtf_content.index(text_segment[0..10])
          preceding = rtf_content[0...text_pos][-50..-1] || ''
          formatting << 'italic' if preceding.include?('\\i') && !preceding.include?('\\i0')
        end
        
        # Check for heading styles (\s1, \s2, etc.)
        if rtf_content.include?("\\s") && rtf_content.index(text_segment[0..10])
          text_pos = rtf_content.index(text_segment[0..10])
          preceding = rtf_content[0...text_pos][-100..-1] || ''
          if match_data = preceding.match(/\\s(\d+)/)
            formatting << "Heading #{match_data[1]}"
          end
        end
        
        formatting.empty? ? 'Normal' : formatting.join(', ')
      end

      # Finds the paragraph context for a match
      #
      # @api private
      # @param document [Hash] Document structure from parse_rtf
      # @param keyword [String] The matched keyword
      # @param line_text [String] The full line text
      # @return [Hash] Context information
      def self.find_paragraph_context(document, keyword, line_text)
        # Find the paragraph that contains the keyword
        matching_para = document[:paragraphs].find do |para|
          para[:text].include?(keyword) || para[:text] == line_text
        end
        
        if matching_para
          {
            rtf_section: matching_para[:section],
            rtf_paragraph: matching_para[:index],
            rtf_style: matching_para[:formatting],
            rtf_path: build_rtf_path(matching_para),
            paragraph_text: matching_para[:text]
          }
        else
          {
            rtf_section: nil,
            rtf_paragraph: nil,
            rtf_style: nil,
            rtf_path: nil
          }
        end
      end

      # Builds a symbolic path for a paragraph
      #
      # @api private
      # @param para_info [Hash] Paragraph information
      # @return [String] Symbolic path
      def self.build_rtf_path(para_info)
        "section[#{para_info[:section]}].paragraph[#{para_info[:index]}]"
      end
    end
  end
end

