# frozen_string_literal: true

require_relative 'insights/base'
require_relative 'insights/json'
require_relative 'insights/pdf'
require_relative 'insights/yaml'
require_relative 'insights/csv'

module RegexSearch
  # Framework for file-type specific analysis and enrichment
  #
  # The Insights module provides a pluggable system for adding file-type
  # specific analysis to search results. Each file type can have its own
  # insight processor that adds relevant metadata to matches.
  #
  # @example Adding a new insight processor
  #   module RegexSearch
  #     module Insights
  #       class Yaml < Base
  #         def self.call(input, match)
  #           match[:insights] = { yaml_key: find_key(input, match) }
  #           match
  #         end
  #       end
  #
  #       SUPPORTED_FILE_TYPES[:yaml] = Yaml
  #     end
  #   end
  #
  # @see RegexSearch::Insights::Base
  # @see RegexSearch::Insights::Json
  module Insights
    # Maps file types to their insight processors
    #
    # @api private
    # @return [Hash<Symbol, Class>] Mapping of file type to processor class
    SUPPORTED_FILE_TYPES = {
      txt: Base,   # Plain text files use base processor
      json: Json,  # JSON files get special JSON path analysis
      pdf: PDF,    # PDF files get page numbers and metadata
      yaml: Yaml,  # YAML files get structure and path analysis
      yml: Yaml,   # Alternative extension for YAML files
      csv: Csv     # CSV files get row and column context
    }.freeze
  end
end
