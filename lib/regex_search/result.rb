# frozen_string_literal: true

module RegexSearch
  # Represents a single search result with its context and metadata
  #
  # Result objects encapsulate all information about a pattern match,
  # including the matched line, surrounding context, and any additional
  # insights or metadata gathered during the search process.
  #
  # @!attribute [r] line_number
  #   @return [Integer] The 1-based line number where the match was found
  # @!attribute [r] line
  #   @return [String] The full line containing the match
  # @!attribute [r] context_before
  #   @return [String, nil] The line before the match, if available
  # @!attribute [r] context_after
  #   @return [String, nil] The line after the match, if available
  # @!attribute [r] captures
  #   @return [Array<Array<String>>] Captured groups from the regex match
  # @!attribute [r] insights
  #   @return [Hash] Additional insights about the match from analyzers
  # @!attribute [r] tags
  #   @return [Array<Symbol>] Tags applied to the match (e.g., :contains_url)
  # @!attribute [r] enrichment
  #   @return [Hash] Additional metadata about the match
  # @!attribute [r] path
  #   @return [String, nil] Path to the source file, if applicable
  # @!attribute [r] filetype
  #   @return [Symbol] The detected file type (:txt, :json, etc.)
  class Result
    attr_reader :line_number, :line, :context_before, :context_after,
                :captures, :insights, :tags, :enrichment,
                :path, :filetype

    # Creates a new Result instance
    #
    # @param match [Hash] The match data containing:
    #   - :line_number [Integer] The 1-based line number
    #   - :line [String] The matched line
    #   - :context_before [String, nil] Previous line
    #   - :context_after [String, nil] Next line
    #   - :captures [Array<Array<String>>] Regex captures
    #   - :insights [Hash] Additional insights
    #   - :tags [Array<Symbol>] Applied tags
    #   - :enrichment [Hash] Extra metadata
    # @param input [Hash] The input metadata containing:
    #   - :path [String, nil] Source file path
    #   - :filetype [Symbol] Detected file type
    def initialize(match:, input:)
      @line_number     = match[:line_number]
      @line            = match[:line]
      @context_before  = match[:context_before]
      @context_after   = match[:context_after]
      @captures        = match[:captures]
      @insights        = match[:insights]
      @tags           = match[:tags]
      @enrichment     = match[:enrichment]
      @path           = input[:path]
      @filetype       = input[:filetype]
    end

    # Converts the result to a hash representation
    #
    # @return [Hash] A hash containing all result data
    # @example
    #   result.to_h
    #   # => {
    #   #   path: "file.txt",
    #   #   filetype: :txt,
    #   #   match: {
    #   #     line_number: 1,
    #   #     line: "matched text",
    #   #     context_before: "previous line",
    #   #     context_after: "next line",
    #   #     captures: [["captured", "groups"]],
    #   #     tags: [:contains_url],
    #   #     enrichment: { capture_count: 2 },
    #   #     insights: { json_path: "$.field" }
    #   #   }
    #   # }
    def to_h
      {
        path: path,
        filetype: filetype,
        match: {
          line_number: line_number,
          line: line,
          context_before: context_before,
          context_after: context_after,
          captures: captures,
          tags: tags,
          enrichment: enrichment,
          insights: insights
        }
      }
    end
  end
end
