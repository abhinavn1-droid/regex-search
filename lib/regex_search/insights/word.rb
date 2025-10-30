# frozen_string_literal: true

require 'docx'

module RegexSearch
  module Insights
    # Word-specific insight processor for .doc/.docx files
    #
    # This processor analyzes Word documents to provide context about
    # where in the document structure a match was found, including
    # section headings, paragraph indices, and style information.
    #
    # @example Word insights for a match
    #   match[:insights] # => {
    #     word_section: "Introduction",
    #     word_paragraph: 4,
    #     word_style: "Heading 2",
    #     word_path: "Section[1].Paragraph[4]"
    #   }
    #
    # @see RegexSearch::Insights::Base
    class Word < Base
      # Processes a match in a Word document
      #
      # @param input [Hash] Input metadata including:
      #   - :path [String] Path to the Word file
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
          
          doc = Docx::Document.open(file_path)
          
          # Extract document structure
          structure = analyze_document_structure(doc)
          
          # Find the paragraph containing the match
          context = find_paragraph_context(structure, keyword, line_text)
          
          match[:insights] = context
        rescue StandardError => e
          match[:insights] = { error: "Word processing error: #{e.message}" }
        end
        match
      end

      # Analyzes the Word document structure
      #
      # @api private
      # @param doc [Docx::Document] The opened Word document
      # @return [Hash] Document structure information
      def self.analyze_document_structure(doc)
        structure = {
          paragraphs: [],
          current_section: nil,
          section_index: 0
        }
        
        paragraph_index = 0
        
        doc.paragraphs.each do |para|
          text = para.text.strip
          next if text.empty?
          
          # Detect headings (paragraphs with heading styles)
          style = extract_style(para)
          is_heading = style&.match?(/heading/i)
          
          if is_heading
            structure[:current_section] = text
            structure[:section_index] += 1
          end
          
          structure[:paragraphs] << {
            index: paragraph_index,
            text: text,
            style: style || 'Normal',
            section: structure[:current_section],
            section_index: structure[:section_index],
            is_heading: is_heading
          }
          
          paragraph_index += 1
        end
        
        structure
      end

      # Extracts the style name from a paragraph
      #
      # @api private
      # @param para [Docx::Elements::Paragraph] The paragraph element
      # @return [String, nil] The style name
      def self.extract_style(para)
        # Try to get style from paragraph properties
        return nil unless para.respond_to?(:style)
        
        begin
          style_name = para.style
          return nil if style_name.nil? || style_name.empty?
          style_name
        rescue NoMethodError
          # Some paragraphs don't have style properties
          nil
        end
      end

      # Finds the paragraph context for a match
      #
      # @api private
      # @param structure [Hash] Document structure from analyze_document_structure
      # @param keyword [String] The matched keyword
      # @param line_text [String] The full line text
      # @return [Hash] Context information
      def self.find_paragraph_context(structure, keyword, line_text)
        # Find the paragraph that contains the keyword
        matching_para = structure[:paragraphs].find do |para|
          para[:text].include?(keyword) || para[:text] == line_text
        end
        
        if matching_para
          {
            word_section: matching_para[:section],
            word_paragraph: matching_para[:index],
            word_style: matching_para[:style],
            word_path: build_word_path(matching_para),
            paragraph_text: matching_para[:text]
          }
        else
          {
            word_section: nil,
            word_paragraph: nil,
            word_style: nil,
            word_path: nil
          }
        end
      end

      # Builds a symbolic path for a paragraph
      #
      # @api private
      # @param para_info [Hash] Paragraph information
      # @return [String] Symbolic path
      def self.build_word_path(para_info)
        if para_info[:section]
          "Section[#{para_info[:section_index]}].Paragraph[#{para_info[:index]}]"
        else
          "Paragraph[#{para_info[:index]}]"
        end
      end
    end
  end
end

