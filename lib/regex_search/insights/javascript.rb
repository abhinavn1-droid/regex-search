# frozen_string_literal: true

require_relative 'base'

module RegexSearch
  module Insights
    # Insight processor for JavaScript/TypeScript files.
    # Adds container (function/class/component), JSX/TSX context,
    # comment flags, import/export context, type hints, and location details.
    class JavaScript < Base
      def self.call(input, match)
        source = input[:data].is_a?(String) ? input[:data] : input[:data].read
        line_no = match[:line_number]
        line_text = match[:line].to_s
        lines = source.to_s.split("\n")

        container = determine_container(lines, line_no)
        in_comment = inside_comment?(line_text)
        in_jsx = inside_jsx?(lines, line_no)
        # If inside JSX and currently resolved to a function container (e.g., inner handler),
        # prefer the nearest enclosing component instead for better context
        if in_jsx && container && container[:type] == 'function'
          comp = find_nearest_component(lines, line_no)
          container = comp if comp
        end
        import_export_ctx = nearest_imports_exports(lines, line_no)
        type_hint = detect_type_usage(line_text, lines, line_no)
        column = compute_column(line_text, match)
        code_ctx = extract_code_context(lines, line_no)
        complexity = compute_complexity_hint(lines, container)

        container ||= { type: 'module', name: 'module' }
        match[:insights] = (match[:insights] || {}).merge({
          container: container.dig(:name),
          container_type: container.dig(:type),
          line_number: line_no,
          column: column,
          code_context: code_ctx,
          in_jsx: in_jsx,
          in_comment: in_comment,
          import_export_context: import_export_ctx,
          type_hint: type_hint,
          complexity_hint: complexity,
          js_path: build_symbolic_path(container)
        }.compact)

        match
      rescue StandardError => e
        match[:insights] = { error: "JavaScript processing error: #{e.message}" }
        match
      end

      # Scan upwards for function/class/component definitions
      def self.determine_container(lines, target_line)
        target_line.downto(1) do |ln|
          text = lines[ln - 1]
          next unless text
          stripped = text.strip
          next if stripped.empty? || stripped.start_with?('//') || stripped.start_with?('/*')

          # React components (function components) - check for PascalCase
          if stripped =~ /^(export\s+)?(const|function)\s+([A-Z][a-zA-Z0-9_$]*)(\s*:\s*[^=]+)?\s*[=(]/
            return { type: 'component', name: Regexp.last_match(3), line: ln }
          # Class declarations
          elsif stripped =~ /^(export\s+)?class\s+([A-Z][a-zA-Z0-9_$]*)/
            return { type: 'class', name: Regexp.last_match(2), line: ln }
          # Function declarations and expressions (camelCase)
          elsif stripped =~ /^(export\s+)?(function|const|let|var)\s+([a-zA-Z_$][\w$]*)\s*[=(]/
            return { type: 'function', name: Regexp.last_match(3), line: ln }
          # Arrow functions
          elsif stripped =~ /^(export\s+)?([a-zA-Z_$][\w$]*)\s*=\s*\([^)]*\)\s*=>/
            return { type: 'function', name: Regexp.last_match(2), line: ln }
          end
        end

        { type: 'module', name: 'module' }
      end

      # Prefer a component/class container above the target line
      def self.find_nearest_component(lines, target_line)
        target_line.downto(1) do |ln|
          text = lines[ln - 1]
          next unless text
          stripped = text.strip
          next if stripped.empty? || stripped.start_with?('//') || stripped.start_with?('/*')

          if stripped =~ /^(export\s+)?(const|function)\s+([A-Z][a-zA-Z0-9_$]*)(\s*:\s*[^=]+)?\s*[=(]/
            return { type: 'component', name: Regexp.last_match(3), line: ln }
          elsif stripped =~ /^(export\s+)?class\s+([A-Z][a-zA-Z0-9_$]*)/
            return { type: 'class', name: Regexp.last_match(2), line: ln }
          end
        end
        nil
      end

      # Detect if line is inside a comment
      def self.inside_comment?(line_text)
        stripped = line_text.strip
        stripped.start_with?('//') || stripped.start_with?('/*') || stripped.end_with?('*/')
      end

      # Detect if line is inside JSX/TSX
      def self.inside_jsx?(lines, target_line)
        # Simple heuristic: look for JSX patterns in surrounding lines
        start_ln = [target_line - 3, 1].max
        end_ln = [target_line + 2, lines.size].min
        
        (start_ln..end_ln).any? do |ln|
          line = lines[ln - 1]
          next false unless line
          
          # Look for JSX patterns
          line.include?('<') && (line.include?('>') || line.include?('/>')) ||
          line.match?(/<[A-Z][a-zA-Z0-9_$]*/) ||
          line.match?(/<\/[A-Z][a-zA-Z0-9_$]*>/) ||
          (line.match?(/\{[^}]*\}/) && line.match?(/<[^>]*>/))
        end
      end

      # Find nearest import/export statements
      def self.nearest_imports_exports(lines, target_line)
        start_ln = [target_line - 10, 0].max
        window = lines[start_ln, 10] || []
        window.select do |l|
          stripped = l.strip
          stripped.match?(/^(import|export)\s+/) ||
          stripped.match?(/^import\s+.*\s+from\s+/) ||
          stripped.match?(/^export\s+(default\s+)?/)
        end
      end

      # Detect TypeScript type usage
      def self.detect_type_usage(line_text, lines, target_line)
        # Check current line for type annotations
        if line_text.match?(/:\s*[A-Z][a-zA-Z0-9_$]*(\[\])?/) ||
           line_text.match?(/interface\s+[A-Z]/) ||
           line_text.match?(/type\s+[A-Z]/) ||
           line_text.match?(/enum\s+[A-Z]/)
          return 'type_annotation'
        end

        # Check for generic types
        if line_text.match?(/<[a-zA-Z][a-zA-Z0-9_$]*>/)
          return 'generic_type'
        end

        # Check for type imports in nearby lines
        start_ln = [target_line - 3, 1].max
        end_ln = [target_line + 1, lines.size].min
        
        (start_ln..end_ln).any? do |ln|
          line = lines[ln - 1]
          line&.match?(/import.*type.*from/) || line&.match?(/import\s*\{[^}]*type[^}]*\}/)
        end ? 'type_import' : nil
      end

      def self.compute_column(line_text, match)
        if match[:captures].is_a?(Array) && !match[:captures].empty?
          token = match[:captures].flatten.first.to_s
          idx = line_text.index(token)
          return idx ? idx + 1 : 1
        end
        m = /\S/.match(line_text)
        m ? (m.begin(0) + 1) : 1
      end

      def self.extract_code_context(lines, line_no)
        from = [line_no - 2, 1].max
        to = [line_no + 1, lines.size].min
        snippet = lines[(from - 1)..(to - 1)] || []
        snippet.join("\n")
      end

      def self.compute_complexity_hint(lines, container)
        return nil unless container && container[:line]
        start_ln = container[:line]
        size = 0
        
        (start_ln..lines.size).each do |ln|
          line = lines[ln - 1]
          break if line.nil?
          
          stripped = line.strip
          next if stripped.empty? || stripped.start_with?('//') || stripped.start_with?('/*')
          
          # Break if we hit another function/class/component definition
          if stripped.match?(/^(export\s+)?(function|class|const|let|var)\s+[a-zA-Z_$]/) && ln > start_ln
            break
          end
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
        when 'component' then "module.#{container[:name]}"
        else 'module'
        end
      end
    end
  end
end
