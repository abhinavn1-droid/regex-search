# frozen_string_literal: true

module RegexSearch
  module Insights
    # Markdown-specific insight processor that finds structural context
    #
    # This processor analyzes Markdown files to provide context about
    # where in the document structure a match was found. It generates metadata
    # including current heading, block type, heading hierarchy, and section path.
    #
    # @example Markdown insights for a match
    #   # For Markdown:
    #   # ## Installation
    #   # Run the following command:
    #   # ```bash
    #   # gem install regex_search
    #   # ```
    #   # When searching for "gem install":
    #   match[:insights] # => {
    #     current_heading: "Installation",
    #     heading_level: 2,
    #     heading_path: ["Installation"],
    #     block_type: "code_block",
    #     code_language: "bash",
    #     line_type: "code"
    #   }
    #
    # @see RegexSearch::Insights::Base
    class Markdown < Base
      # Processes a match in a Markdown file to find structural context
      #
      # @param input [Hash] Input metadata including:
      #   - :path [String] Path to the Markdown file (optional)
      #   - :data [String] Markdown content
      # @param match [Hash] Match data including:
      #   - :line_number [Integer] Line number where match was found
      #   - :line [String] The line containing the match
      # @return [Hash] Match with added insights:
      #   - insights.current_heading [String, nil] Nearest heading above match
      #   - insights.heading_level [Integer, nil] Level of current heading (1-6)
      #   - insights.heading_path [Array<String>] Hierarchy of headings
      #   - insights.block_type [String] Type of block (paragraph, code_block, list_item, etc.)
      #   - insights.code_language [String, nil] Language for code blocks
      #   - insights.line_type [String] Type of current line
      #   - insights.list_level [Integer, nil] Nesting level for lists
      def self.call(input, match)
        begin
          # Get the Markdown content from input data or file path
          markdown_content = input[:data].is_a?(String) ? input[:data] : File.read(input[:path])
          line_number = match[:line_number]
          
          lines = markdown_content.lines
          
          # Analyze document structure
          structure = analyze_structure(lines)
          
          # Find context for the matched line
          context = find_line_context(structure, line_number)
          
          match[:insights] = context
        rescue StandardError => e
          match[:insights] = { error: "Markdown processing error: #{e.message}" }
        end
        match
      end

      # Analyzes the Markdown document structure
      #
      # @api private
      # @param lines [Array<String>] Lines of the document
      # @return [Hash] Structure information for each line
      def self.analyze_structure(lines)
        structure = {}
        current_headings = []
        in_code_block = false
        code_language = nil
        
        lines.each_with_index do |line, idx|
          line_num = idx + 1
          stripped = line.strip
          
          # Detect code block boundaries
          if stripped.start_with?('```')
            if in_code_block
              in_code_block = false
              code_language = nil
            else
              in_code_block = true
              code_language = stripped[3..-1]&.strip
              code_language = nil if code_language&.empty?
            end
            structure[line_num] = {
              line_type: 'code_fence',
              block_type: 'code_block',
              code_language: code_language,
              current_heading: current_headings.last&.[](:text),
              heading_level: current_headings.last&.[](:level),
              heading_path: current_headings.map { |h| h[:text] }
            }
            next
          end
          
          # Inside code block
          if in_code_block
            structure[line_num] = {
              line_type: 'code',
              block_type: 'code_block',
              code_language: code_language,
              current_heading: current_headings.last&.[](:text),
              heading_level: current_headings.last&.[](:level),
              heading_path: current_headings.map { |h| h[:text] }
            }
            next
          end
          
          # Detect headings
          if stripped =~ /^(#+)\s+(.+)$/ && $1.length <= 6
            level = $1.length
            text = $2.strip
            
            # Update heading hierarchy
            current_headings = current_headings.take_while { |h| h[:level] < level }
            current_headings << { level: level, text: text }
            
            structure[line_num] = {
              line_type: 'heading',
              block_type: 'heading',
              current_heading: text,
              heading_level: level,
              heading_path: current_headings.map { |h| h[:text] }
            }
            next
          end
          
          # Detect list items
          if stripped =~ /^(\s*)[-*+]\s+/ || stripped =~ /^(\s*)\d+\.\s+/
            list_level = ($1&.length || 0) / 2
            
            structure[line_num] = {
              line_type: 'list_item',
              block_type: 'list',
              list_level: list_level,
              current_heading: current_headings.last&.[](:text),
              heading_level: current_headings.last&.[](:level),
              heading_path: current_headings.map { |h| h[:text] }
            }
            next
          end
          
          # Detect blockquotes
          if stripped =~ /^>\s*/
            structure[line_num] = {
              line_type: 'blockquote',
              block_type: 'blockquote',
              current_heading: current_headings.last&.[](:text),
              heading_level: current_headings.last&.[](:level),
              heading_path: current_headings.map { |h| h[:text] }
            }
            next
          end
          
          # Detect horizontal rules
          if stripped =~ /^([-*_])\1{2,}$/
            structure[line_num] = {
              line_type: 'horizontal_rule',
              block_type: 'horizontal_rule',
              current_heading: current_headings.last&.[](:text),
              heading_level: current_headings.last&.[](:level),
              heading_path: current_headings.map { |h| h[:text] }
            }
            next
          end
          
          # Default: paragraph
          structure[line_num] = {
            line_type: stripped.empty? ? 'blank' : 'text',
            block_type: 'paragraph',
            current_heading: current_headings.last&.[](:text),
            heading_level: current_headings.last&.[](:level),
            heading_path: current_headings.map { |h| h[:text] }
          }
        end
        
        structure
      end

      # Finds context for a specific line number
      #
      # @api private
      # @param structure [Hash] Analyzed structure from analyze_structure
      # @param line_number [Integer] Line number to find context for
      # @return [Hash] Context information for the line
      def self.find_line_context(structure, line_number)
        context = structure[line_number]
        
        if context
          context
        else
          # Fallback if line not in structure
          {
            line_type: 'text',
            block_type: 'paragraph',
            current_heading: nil,
            heading_level: nil,
            heading_path: []
          }
        end
      end
    end
  end
end

