# frozen_string_literal: true

require_relative 'insights/base'
require_relative 'insights/json'
require_relative 'insights/pdf'
require_relative 'insights/yaml'
require_relative 'insights/csv'
require_relative 'insights/html'
require_relative 'insights/xml'
require_relative 'insights/excel'
require_relative 'insights/markdown'
require_relative 'insights/word'

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
      txt: Base,       # Plain text files use base processor
      json: Json,      # JSON files get special JSON path analysis
      pdf: PDF,        # PDF files get page numbers and metadata
      yaml: Yaml,      # YAML files get structure and path analysis
      yml: Yaml,       # Alternative extension for YAML files
      csv: Csv,        # CSV files get row and column context
      html: Html,      # HTML files get element paths and structure
      xml: Xml,        # XML files get element paths and namespaces
      xlsx: Excel,     # Excel files get sheet and cell context
      xls: Excel,      # Legacy Excel files get sheet and cell context
      md: Markdown,    # Markdown files get heading and block context
      markdown: Markdown,  # Alternative extension for Markdown files
      docx: Word,      # Word documents get section and paragraph context
      doc: Word        # Legacy Word documents get section and paragraph context
    }.freeze
  end
end
