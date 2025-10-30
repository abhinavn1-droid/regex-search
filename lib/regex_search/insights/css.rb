# frozen_string_literal: true

require_relative 'base'

module RegexSearch
  module Insights
    # Insight processor for CSS stylesheets.
    # Extracts selector, property, declaration value, media query context,
    # comment presence, import source, and a symbolic path.
    class Css < Base
      # Processes a match found in a CSS file to add stylesheet-specific insights.
      #
      # @param input [Hash] Input data including:
      #   - :data [String] Full CSS content
      #   - :path [String] File path
      # @param match [Hash] Match data including:
      #   - :line_number [Integer]
      #   - :line [String]
      # @return [Hash] Match with added insights
      def self.call(input, match)
        content = input[:data].is_a?(String) ? input[:data] : input[:data].read
        line_no = match[:line_number]
        insights = analyze_css(content, line_no, match[:line])
        match[:insights] = (match[:insights] || {}).merge(insights)
        match
      rescue StandardError => e
        match[:insights] = { error: "CSS processing error: #{e.message}" }
        match
      end

      # Parses the CSS content and returns insights for a given line
      #
      # @api private
      def self.analyze_css(content, target_line, target_line_text)
        lines = content.to_s.split("\n")

        # Detect if target line is inside a comment block
        comment_blocks = find_comment_blocks(lines)
        in_comment = comment_blocks.any? { |(s, e)| target_line.between?(s, e) }

        # If @import detected on the line
        import_source = extract_import_source(target_line_text)

        # Build rule map with media contexts
        rules = build_rules_with_ranges(lines)
        rule = rules.find { |r| target_line.between?(r[:start_line], r[:end_line]) }

        selector = rule&.dig(:selector)
        rule_index = rule&.dig(:index)
        media_query = rule&.dig(:media)&.last # nearest media if nested

        # Extract property and declaration value if looks like a declaration
        property, declaration_value = extract_declaration(target_line_text)

        symbolic_path = if selector
                          path = "stylesheet.rule[#{rule_index || 0}]"
                          if property
                            path += ".declaration[#{property}]"
                          end
                          path
                        end

        {
          selector: selector,
          property: property,
          declaration_value: declaration_value,
          rule_index: rule_index,
          media_query: media_query,
          comment: in_comment,
          import_source: import_source,
          css_path: symbolic_path
        }.compact
      end

      # Finds comment block line ranges as [start_line, end_line]
      def self.find_comment_blocks(lines)
        blocks = []
        open_at = nil
        lines.each_with_index do |line, idx|
          if open_at.nil?
            open_at = idx + 1 if line.include?('/*')
          end
          if !open_at.nil? && line.include?('*/')
            blocks << [open_at, idx + 1]
            open_at = nil
          end
        end
        blocks
      end

      # Extracts @import url or string from a line
      def self.extract_import_source(line)
        return nil unless line
        if line =~ /@import\s+(url\(([^)]+)\)|["']([^"']+)["'])/i
          Regexp.last_match(2) || Regexp.last_match(3)
        end
      end

      # Builds rules with selector, ranges, media stack
      def self.build_rules_with_ranges(lines)
        rules = []
        media_stack = []
        brace_stack = []
        index = 0

        lines.each_with_index do |line, idx|
          lno = idx + 1
          stripped = line.strip

          # Enter/exit media queries
          if stripped.start_with?('@media') && stripped.include?('{')
            media_stack << stripped.sub('{', '').strip
            brace_stack << :media
            next
          end

          # Selector rule start: look for something ending with '{' and not @-rule
          if stripped.end_with?('{') && !stripped.start_with?('@')
            selector = stripped[0..-2].strip
            rules << { index: index, selector: selector, start_line: lno, end_line: lno, media: media_stack.dup }
            index += 1
            brace_stack << :rule
            next
          end

          # Track block ends
          if stripped.include?('}')
            last = brace_stack.pop
            if last == :rule
              # Close the last open rule
              open_rule = rules.reverse.find { |r| r[:end_line] == r[:start_line] }
              open_rule[:end_line] = lno if open_rule
            elsif last == :media
              media_stack.pop
            end
          end

          # Extend the current open rule range if any
          current = rules.reverse.find { |r| lno >= r[:start_line] && lno >= r[:end_line] }
          current[:end_line] = lno if current
        end

        # Close any unclosed rules at EOF
        last_line = lines.size
        rules.each do |r|
          r[:end_line] = last_line if r[:end_line] < r[:start_line]
        end

        rules
      end

      # Extracts CSS property and full declaration value from a line
      def self.extract_declaration(line)
        return [nil, nil] unless line
        if line =~ /\s*([a-zA-Z\-]+)\s*:\s*(.+?);?\s*$/
          property = Regexp.last_match(1)
          value = Regexp.last_match(2).to_s.strip
          [property, value]
        else
          [nil, nil]
        end
      end
    end
  end
end


