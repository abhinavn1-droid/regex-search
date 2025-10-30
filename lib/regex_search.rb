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
    # @option options [String, Hash] :pdf_password Password for encrypted PDFs.
    #   Can be a single string or a hash mapping file paths to passwords
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
    #
    # @example Search in encrypted PDF
    #   runner = RegexSearch::Runner.new(
    #     input: "encrypted.pdf",
    #     pattern: /confidential/,
    #     mode: 'find_in_file',
    #     pdf_password: 'secret123'
    #   )
    def initialize(input: nil, pattern: nil, mode: 'find', verbose: false, **options)
      @logger = Logger.new($stdout)
      @logger.level = verbose ? Logger::DEBUG : Logger::WARN
      @pdf_password = options.delete(:pdf_password)

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

        filetype = FileTypeDetector.detect(path)
        klass = Insights::SUPPORTED_FILE_TYPES[filetype] || Insights::Base
        @logger.debug("Detected file type: .#{filetype}, using #{klass}")

        # Add password support for PDFs
        password = get_password_for_file(path)

        begin
          # Extract text for binary formats (PDF)
          if filetype == :pdf
            data = extract_pdf_text(path, password)
          else
            data = item.is_a?(File) ? item.tap(&:rewind) : File.read(path)
          end
        rescue StandardError => e
          raise Errors::FileReadError, "Failed to read file #{path}: #{e.message}"
        end

        inputs << { data:, path:, filetype:, insights_klass: klass, password: }
      end
      inputs
    end

    # Gets the password for a given file path
    #
    # @api private
    # @param path [String] File path
    # @return [String, nil] Password for the file, if configured
    def get_password_for_file(path)
      return nil unless @pdf_password

      if @pdf_password.is_a?(Hash)
        @pdf_password[path] || @pdf_password[File.basename(path)]
      else
        @pdf_password
      end
    end

    # Extracts text from a PDF file
    #
    # @api private
    # @param path [String] Path to the PDF file
    # @param password [String, nil] Optional password for encrypted PDFs
    # @return [String] Extracted text from all pages
    # @raise [Errors::FileReadError] If PDF cannot be read
    def extract_pdf_text(path, password)
      require 'pdf-reader'
      
      opts = {}
      opts[:password] = password if password
      reader = ::PDF::Reader.new(path, opts)
      
      text = []
      1.upto(reader.page_count) do |page_num|
        begin
          page = reader.page(page_num)
          page_text = page.text
          text << page_text.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        rescue StandardError => e
          @logger.warn("Error extracting page #{page_num} from #{path}: #{e.message}")
        end
      end
      
      text.join("\n")
    rescue ::PDF::Reader::EncryptedPDFError => e
      raise Errors::FileReadError, "PDF is encrypted and requires a password: #{e.message}"
    rescue StandardError => e
      raise Errors::FileReadError, "Failed to extract text from PDF #{path}: #{e.message}"
    end
  end
end
