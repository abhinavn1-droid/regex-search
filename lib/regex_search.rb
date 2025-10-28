# frozen_string_literal: true

require_relative 'regex_search/searcher'
require_relative 'regex_search/insights'
# Main module for RegexSearch gem
module RegexSearch
  class Runner
    attr_reader :results

    def initialize(input: nil, pattern: nil, mode: 'find', **options)
      inputs = process_input(input, mode)

      @results = Searcher.search(inputs, pattern, options)
    end

    private

    # options = {
    #   stop_at_first_match: false, # By default gives all matches
    #   provide_insights: true,
    # }
    def process_input(input, mode)
      case mode
      when 'find'
        # Highle restrictive: only accept single string input
        raise TypeError, 'Input must be a String' unless input.is_a?(String)

        [{ data: input, path: nil, insights_klass: RegexSearch::Insights::Base }]
      when 'find_in_file'
        process_collection([input])
      when 'find_in_files'
        process_collection(input)
      end
    end

    def process_collection(collection)
      inputs = []
      collection.each do |item|
        unless (item.is_a?(String) && File.file?(item)) || item.is_a?(File)
          raise TypeError, 'All items of the input must be either a file or file path'
        end

        current_input = { data: nil, path: nil, insights_klass: nil }
        if item.is_a?(File)
          item.rewind
          current_input[:data] = item
          current_input[:path] = item.path
        else
          current_input[:data] = File.read(item)
          current_input[:path] = item
        end

        ext = File.extname(current_input[:path]).split('.')[1]
        current_input[:insights_klass] = RegexSearch::Insights::SUPPORTED_FILE_TYPES[ext.to_sym] ||
                                         RegexSearch::Insights::Base
        inputs << current_input
      end

      inputs
    end
  end

  def self.find(**)
    RegexSearch::Runner.new(**, mode: 'find').results
  end

  def self.find_in_file(**)
    RegexSearch::Runner.new(**, mode: 'find_in_file').results
  end

  def self.find_in_files(**)
    RegexSearch::Runner.new(**, mode: 'find_in_files').results
  end
end
