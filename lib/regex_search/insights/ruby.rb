# frozen_string_literal: true

require_relative 'base'

module RegexSearch
  module Insights
    # Insight processor for Ruby source files.
    # Adds container (method/class/module), docstring/comment flags,
    # nearby requires, precise location, code context, and a complexity hint.
    class Ruby < Base
      def self.call(input, match)
        source = input[:data].is_a?(String) ? input[:data] : input[:data].read
        line_no = match[:line_number]
        line_text = match[:line].to_s
        lines = source.to_s.split("\n")

        container = determine_container(lines, line_no)
        in_comment = line_text.strip.start_with?('#')
        in_docstring = inside_docblock?(lines, line_no)
        require_ctx = nearest_requires(lines, line_no)
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
          require_context: require_ctx,
          complexity_hint: complexity,
          ruby_path: symbolic_path
        }.compact)

        match
      rescue StandardError => e
        match[:insights] = { error: "Ruby processing error: #{e.message}" }
        match
      end

      # Scan upwards for def/class/module
      def self.determine_container(lines, target_line)
        (target_line - 1).downto(1) do |ln|
          text = lines[ln - 1]
          next unless text
          stripped = text.strip
          next if stripped.empty? || stripped.start_with?('#')

          if stripped =~ /^def\s+([a-zA-Z_][\w!?]*)\s*(\(|$)/
            return { type: 'method', name: Regexp.last_match(1), line: ln }
          elsif stripped =~ /^class\s+([A-Z]\w*)/
            return { type: 'class', name: Regexp.last_match(1), line: ln }
          elsif stripped =~ /^module\s+([A-Z]\w*)/
            return { type: 'module', name: Regexp.last_match(1), line: ln }
          end
        end
        { type: 'module', name: 'module' }
      end

      # Detect =begin/=end doc blocks; simple heuristic
      def self.inside_docblock?(lines, target_line)
        open = false
        lines[0, target_line].each do |l|
          s = l.strip
          open = true if s.start_with?('=begin')
          open = false if s.start_with?('=end')
        end
        open
      end

      # Collect nearest require/require_relative/load lines in previous 6 lines
      def self.nearest_requires(lines, target_line)
        start_ln = [target_line - 7, 0].max
        window = lines[start_ln, 6] || []
        window.select { |l| l.strip =~ /^(require|require_relative|load)\s+/ }
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
          break if line && line.strip =~ /^(def|class|module)\b/
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
        when 'method' then "module.#{container[:name]}()"
        when 'class' then "module.#{container[:name]}"
        when 'module' then "module.#{container[:name]}"
        else 'module'
        end
      end
    end
  end
end


