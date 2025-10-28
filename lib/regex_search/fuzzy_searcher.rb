# frozen_string_literal: true

module RegexSearch
  # A searcher class that performs fuzzy pattern matching
  #
  # This class implements fuzzy string matching using the Levenshtein distance
  # algorithm to find approximate matches in text.
  #
  # @example Basic fuzzy search
  #   searcher = FuzzySearcher.new('config', max_distance: 2)
  #   results = searcher.search_file('config.yml')
  #
  # @example Search with custom threshold
  #   searcher = FuzzySearcher.new('password', max_distance: 3)
  #   results = searcher.search_text(text)
  class FuzzySearcher
    # @return [String] The pattern to search for
    attr_reader :pattern

    # @return [Integer] Maximum allowed Levenshtein distance
    attr_reader :max_distance

    # Initialize a new FuzzySearcher
    #
    # @param pattern [String] The pattern to search for
    # @param max_distance [Integer] Maximum allowed Levenshtein distance
    def initialize(pattern, max_distance: 2)
      @pattern = pattern.downcase
      @max_distance = max_distance
    end

    # Search for fuzzy matches in a file
    #
    # @param path [String] Path to the file to search
    # @param context_lines [Integer] Number of context lines to include
    # @return [Array<Result>] Array of search results
    def search_file(path, context_lines: 2)
      text = File.read(path)
      search_text(text, context_lines: context_lines, file_path: path)
    end

    # Search for fuzzy matches in text
    #
    # @param text [String] The text to search
    # @param context_lines [Integer] Number of context lines to include
    # @return [Array<Result>] Array of search results
    def search_text(text, context_lines: 2, file_path: nil)
      results = []
      lines = text.lines
      window = ContextWindow.new(lines, context_lines)

      lines.each_with_index do |line, index|
        find_matches_in_line(line, index + 1).each do |match_data|
          window.move_to(index)
          results << create_result(match_data, window, file_path)
        end
      end

      results
    end

    private

    # Find fuzzy matches in a single line
    #
    # @param line [String] The line to search
    # @param line_number [Integer] The line number
    # @return [Array<Hash>] Array of match data
    def find_matches_in_line(line, line_number)
      matches = []
      line = line.chomp
      pattern_lower = pattern.downcase
      words = line.split(/\b/).map(&:strip).reject(&:empty?)
      position = 0
      current_pos = 0

      words.each do |word|
        next if word.length < 3 # Skip very short words

        word_lower = word.downcase
        position = line.index(word, current_pos)
        current_pos = position + word.length if position

        # Skip if no position found (shouldn't happen but just in case)
        next unless position

        if word_lower == pattern_lower || word_lower =~ /#{Regexp.escape(pattern_lower)}/
          # Exact match or exact substring
          matches << {
            line: line,
            line_number: line_number,
            word: word,
            distance: 0,
            position: position
          }
        else
          # Try fuzzy match
          distance = levenshtein_distance(word_lower, pattern_lower)
          next if distance > max_distance
          # More strict for different lengths
          next if distance > [word.length, pattern.length].min / 2

          # For similar length strings, be more lenient
          length_diff = (word.length - pattern.length).abs
          next if length_diff > max_distance

          matches << {
            line: line,
            line_number: line_number,
            word: word,
            distance: distance,
            position: position
          }
        end
      end

  # For each line, only keep the single best match (earliest if tie)
  return [] if matches.empty?
  best_distance = matches.map { |m| m[:distance] }.min
  return [] unless best_distance && best_distance <= max_distance

  best_matches = matches.select { |m| m[:distance] == best_distance }
  best_match = best_matches.min_by { |m| m[:position] || 0 }
  [best_match]
    end

    # Create a Result object from match data
    #
    # @param match_data [Hash] The match data
    # @param window [ContextWindow] The context window
    # @return [Result] A new Result object
    def create_result(match_data, window, file_path = nil)
      Result.new(
        match: {
          line_number: match_data[:line_number],
          line: match_data[:line],
          context_before: window.before,
          context_after: window.after,
          captures: [[match_data[:word]]],
          tags: [:fuzzy_match],
          enrichment: {
            levenshtein_distance: match_data[:distance],
            match_position: match_data[:position]
          },
          insights: {}
        },
        input: {
          path: file_path,
          filetype: detect_filetype(match_data[:line])
        }
      )
    end

    # Calculate Levenshtein distance between two strings
    #
    # @param str1 [String] First string
    # @param str2 [String] Second string
    # @return [Integer] The Levenshtein distance
    def levenshtein_distance(str1, str2)
      m = str1.length
      n = str2.length
      return m if n.zero?
      return n if m.zero?

      matrix = Array.new(m + 1) { Array.new(n + 1) }

      (0..m).each { |i| matrix[i][0] = i }
      (0..n).each { |j| matrix[0][j] = j }

      (1..m).each do |i|
        (1..n).each do |j|
          cost = str1[i - 1] == str2[j - 1] ? 0 : 1
          matrix[i][j] = [
            matrix[i - 1][j] + 1,      # deletion
            matrix[i][j - 1] + 1,      # insertion
            matrix[i - 1][j - 1] + cost # substitution
          ].min
        end
      end

      matrix[m][n]
    end

    # Detect file type from content
    #
    # @param line [String] A line from the file
    # @return [Symbol] Detected file type
    def detect_filetype(line)
      FileTypeDetector.detect_from_content(line)
    end
  end
end
