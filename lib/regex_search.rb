# frozen_string_literal: true

require_relative 'regex_search/searcher'
require_relative 'regex_search/insights'
require_relative 'regex_search/errors'
require_relative 'regex_search/result'
require_relative 'regex_search/file_type_detector'
require 'logger'

module RegexSearch
  class Runner
    attr_reader :results

    def initialize(input: nil, pattern: nil, mode: 'find', verbose: false, **options)
      @logger = Logger.new($stdout)
      @logger.level = verbose ? Logger::DEBUG : Logger::WARN

      inputs = process_input(input, mode)
      @results = Searcher.search(inputs, pattern, options.merge(logger: @logger))
    end

    private

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
      else
        raise Errors::MalformedInputError, "Unknown mode: #{mode}"
      end
    end

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

        filetype = FileTypeDetector.detect(current_input[:path])
        klass = Insights::SUPPORTED_FILE_TYPES[filetype] || Insights::Base
        @logger.debug("Detected file type: .#{ext}, using #{klass}")

        inputs << { data:, path:, filetype:, insights_klass: klass }
      end
      inputs
    end
  end
end
