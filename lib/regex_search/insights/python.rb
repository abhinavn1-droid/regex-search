# frozen_string_literal: true

require_relative 'base'

module RegexSearch
  module Insights
    # Insight processor for Python source files.
    # Provides code-aware metadata like container (function/class),
    # docstring/comment flags, import vicinity, and location details.
    class Python < Base
      # Processes a match found in a Python file.
      #
      # @param input [Hash] Input data including:
      #   - :data [String] Full source
      #   - :path [String] File path
      # @param match [Hash] Match data including :line_number, :line, :captures
      # @return [Hash]
      def self.call(input, match)
        source = input[:data].is_a?(String) ? input[:data] : input[:data].read
        line_no = match[:line_number]
        line_text = match[:line].to_s

        lines = source.to_s.split("\n")

        container = determine_container(lines, line_no)
        in_comment = line_text.strip.start_with?('#')
        in_docstring = inside_docstring?(lines, line_no)
        import_ctx = nearest_imports(lines, line_no)
        column = compute_column(line_text, match)
        code_ctx = extract_code_context(lines, line_no)
        complexity = compute_complexity_hint(lines, container)

        symbolic_path = build_symbolic_path(container)

        container ||= { type: 'module', name: 'module' }
        match[:insights] = (match[:insights] || {}).merge({
          container: container.dig(:name),
          container_type: container.dig(:type),
          line_number: line_no,
          column: column,
          code_context: code_ctx,
          in_docstring: in_docstring,
          in_comment: in_comment,
          import_context: import_ctx,
          complexity_hint: complexity,
          python_path: symbolic_path
        }.compact)

        match
      rescue StandardError => e
        match[:insights] = { error: "Python processing error: #{e.message}" }
        match
      end

      # Determine nearest enclosing function/class by scanning upwards
      def self.determine_container(lines, target_line)
        indent_stack = []
        (target_line - 1).downto(1) do |ln|
          text = lines[ln - 1]
          next unless text
          stripped = text.strip
          next if stripped.empty? || stripped.start_with?('#')

          if stripped =~ /^def\s+([a-zA-Z_][\w]*)\s*\(/
            return { type: 'function', name: Regexp.last_match(1), line: ln }
          elsif stripped =~ /^class\s+([a-zA-Z_][\w]*)\s*(\(|:)/
            return { type: 'class', name: Regexp.last_match(1), line: ln }
          end
        end
        { type: 'module', name: File.basename('module') }
      end

      # Docstring detection: inline triple quotes or unmatched count up to line
      def self.inside_docstring?(lines, target_line)
        current = lines[target_line - 1].to_s
        return true if current =~ /(\"\"\".*\"\"\"|'''.*''')/

        quotes = 0
        lines[0, target_line].each do |l|
          quotes += l.scan(/\"\"\"|'''/).length
        end
        quotes.odd?
      end

      # Find nearest preceding import statements (up to 5 lines)
      def self.nearest_imports(lines, target_line)
        start_ln = [target_line - 6, 0].max
        window = lines[start_ln, 5] || []
        window.select { |l| l.strip.start_with?('import ', 'from ') }
      end

      # Column index where the match occurred (prefer first capture)
      def self.compute_column(line_text, match)
        if match[:captures].is_a?(Array) && !match[:captures].empty?
          token = match[:captures].flatten.first.to_s
          idx = line_text.index(token)
          return idx ? idx + 1 : 1
        end
        # fallback to first non-space
        m = /\S/.match(line_text)
        m ? (m.begin(0) + 1) : 1
      end

      # Extract small code context snippet around the line
      def self.extract_code_context(lines, line_no)
        from = [line_no - 2, 1].max
        to = [line_no + 1, lines.size].min
        snippet = lines[(from - 1)..(to - 1)] || []
        snippet.join("\n")
      end

      # Very rough complexity hint based on block size under the container
      def self.compute_complexity_hint(lines, container)
        return nil unless container && container[:line]
        start_ln = container[:line]
        # scan forward until next top-level def/class of same or less indent
        size = 0
        (start_ln..lines.size).each do |ln|
          line = lines[ln - 1]
          break if line && line.strip =~ /^(def|class)\s+/
          size += 1
        end
        case size
        when 0..10 then 'low'
        when 11..40 then 'medium'
        else 'high'
        end
      end

      def self.build_symbolic_path(container)
        return 'module' unless container
        case container[:type]
        when 'function' then "module.#{container[:name]}()"
        when 'class' then "module.#{container[:name]}"
        else 'module'
        end
      end
    end
  end
end


