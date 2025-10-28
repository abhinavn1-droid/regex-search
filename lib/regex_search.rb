# frozen_string_literal: true

require_relative 'regex_search/searcher'
require_relative 'regex_search/fuzzy_searcher'
require_relative 'regex_search/insights'
require_relative 'regex_search/errors'
require_relative 'regex_search/result'
require_relative 'regex_search/file_type_detector'
require_relative 'regex_search/match_filter'
require 'logger'

# RegexSearch is a lightweight Ruby library for searching text content using regular expressions.
# It provides advanced features like contextual search, file type detection, and content insights.
#
# @example Basic string search
#   results = RegexSearch::Runner.new(input: "Hello Ruby", pattern: /Ruby/).results
#   puts results.first[:result].first.line  # => "Hello Ruby"
#
# @example Search in a file with context
#   runner = RegexSearch::Runner.new(
#     input: "path/to/file.txt",
#     pattern: /important/,
#     mode: 'find_in_file',
#     context_lines: 2
#   )
#
# @see RegexSearch::Searcher
# @see RegexSearch::Result
# @version 0.1.0
module RegexSearch
  # Coordinates the search process and handles input processing, file operations,
  # and insight generation.
  #
  # The Runner class is the main entry point for the RegexSearch library. It processes
  # different types of inputs (strings, files, or collections of files) and coordinates
  # the search operation using the {Searcher} module.
  #
  # @!attribute [r] results
  #   @return [Array<Hash>] The search results containing matches and their context
  class Runner
    # @return [Array<Hash>] The search results containing matches and their context
    attr_reader :results

    # Applies filters to the current search results
    #
    # @param filter_options [Hash] Filter criteria
    # @option filter_options [String] :keyword Text to search within matches
    # @option filter_options [Array<Symbol>] :tags Required tags
    # @option filter_options [Integer] :min_context_density Minimum context density
    # @option filter_options [Array<Regexp>] :exclude_patterns Patterns to exclude
    # @option filter_options [Array<Symbol>] :file_types Allowed file types
    # @return [Array<Hash>] Filtered search results
    def filter(**filter_options)
      @results = MatchFilter.filter(@results, **filter_options)
    end

    # Initializes a new Runner instance and performs the search operation
    #
    # @param input [String, File, Array<String, File>] The input to search.
    #   Can be a string, a file path, a File object, or an array of files/paths
    # @param pattern [Regexp, String] The pattern to search for
    # @param mode [String] The search mode: 'find', 'find_in_file', 'find_in_files', or 'fuzzy'
    # @param verbose [Boolean] Whether to output debug logging
    # @param options [Hash] Additional options to pass to the searcher
    # @option options [Integer] :context_lines (1) Number of context lines to include
    # @option options [Boolean] :stop_at_first_match (false) Stop after first match
    #
    # @raise [Errors::MalformedInputError] If input format is invalid for the mode
    # @raise [Errors::FileReadError] If a file cannot be read
    #
    # @example Search in a string
    #   runner = RegexSearch::Runner.new(
    #     input: "Hello Ruby World",
    #     pattern: /Ruby/
    #   )
    #
    # @example Search in multiple files
    #   runner = RegexSearch::Runner.new(
    #     input: ["file1.txt", "file2.txt"],
    #     pattern: /important/,
    #     mode: 'find_in_files'
    #   )
    def initialize(input: nil, pattern: nil, mode: 'find', verbose: false, **options)
      @logger = Logger.new($stdout)
      @logger.level = verbose ? Logger::DEBUG : Logger::WARN

      inputs = process_input(input, mode)
      if mode == 'fuzzy'
        searcher = FuzzySearcher.new(pattern.to_s, max_distance: options.fetch(:max_distance, 2))
        @results = inputs.map do |input|
          data = input[:data].is_a?(String) ? input[:data] : input[:data].read
          results = searcher.search_text(data, context_lines: options.fetch(:context_lines, 1))
          # Update result paths if this came from a file
          results.each { |r| r.instance_variable_set(:@path, input[:path]) } if input[:path]
          { result: results, path: input[:path], filetype: input[:filetype] }
        end
      else
        @results = Searcher.search(inputs, pattern, options.merge(logger: @logger))
      end
    end

    private

    # Processes the input based on the search mode
    #
    # @api private
    # @param input [String, File, Array<String, File>] The input to process
    # @param mode [String] The search mode
    # @return [Array<Hash>] Array of processed inputs ready for searching
    # @raise [Errors::MalformedInputError] If input format doesn't match mode
    def process_input(input, mode)
      case mode
      when 'find'
        raise Errors::MalformedInputError, 'Input must be a String' unless input.is_a?(String)

        @logger.debug('Processing string input')
        [{ data: input, path: nil, insights_klass: Insights::Base }]
      when 'find_in_file'
        process_collection([input])
      when 'find_in_files'
        process_collection(input)
      when 'fuzzy'
        # If a string is provided, it may be literal text or a file path.
        # Treat it as a file path if it's a real file on disk.
        if input.is_a?(String) && File.file?(input)
          process_collection([input])
        elsif input.is_a?(Array)
          process_collection(input)
        elsif input.is_a?(String)
          [{ data: input, path: nil, insights_klass: Insights::Base }]
        else
          process_collection(input.is_a?(Array) ? input : [input])
        end
      else
        raise Errors::MalformedInputError, "Unknown mode: #{mode}"
      end
    end

    # Processes a collection of files for searching
    #
    # @api private
    # @param collection [Array<String, File>] Collection of file paths or File objects
    # @return [Array<Hash>] Processed inputs with file data and metadata
    # @raise [Errors::MalformedInputError] If any file path is invalid
    # @raise [Errors::FileReadError] If any file cannot be read
    def process_collection(collection)
      inputs = []
      collection.each do |item|
        path = item.is_a?(File) ? item.path : item
        raise Errors::MalformedInputError, "Invalid file or path: #{path}" unless File.file?(path)

        begin
          data = item.is_a?(File) ? item.tap(&:rewind) : File.read(path)
        rescue StandardError => e
          raise Errors::FileReadError, "Failed to read file #{path}: #{e.message}"
        end

        filetype = FileTypeDetector.detect(path) # Fixed: was current_input[:path]
        klass = Insights::SUPPORTED_FILE_TYPES[filetype] || Insights::Base
        @logger.debug("Detected file type: .#{filetype}, using #{klass}") # Fixed: was ext

        inputs << { data:, path:, filetype:, insights_klass: klass }
      end
      inputs
    end
  end
end
