# frozen_string_literal: true

module RegexSearch
  # Processes matches through a pipeline of enrichments and annotations
  #
  # The InsightPipeline processes each match through several stages:
  # 1. Preprocessing - Normalizes match data
  # 2. Annotation - Adds contextual tags
  # 3. Insight Processing - Applies file-type specific insights
  # 4. Postprocessing - Adds final enrichments
  #
  # @example Basic pipeline usage
  #   match = { line: "Example: https://example.com", captures: [["Example"]] }
  #   result = RegexSearch::InsightPipeline.run(
  #     RegexSearch::Insights::Base,
  #     { path: 'file.txt' },
  #     match
  #   )
  #   result[:tags] # => [:contains_url]
  module InsightPipeline
    # Runs a match through the complete insight pipeline
    #
    # @param klass [Class] The insight processor class to use
    # @param input [Hash] Input metadata (path, type, etc.)
    # @param match [Hash] The match data to process
    # @param logger [Logger, nil] Optional logger for debugging
    # @return [Hash] The processed match with insights
    def self.run(klass, input, match, logger = nil)
      logger&.debug("InsightPipeline: starting for #{klass}")

      match = preprocess(input, match, logger)
      match = annotate(input, match, logger)
      match = klass.call(input, match)
      match = postprocess(input, match, logger)

      logger&.debug("InsightPipeline: completed for line #{match[:line_number]}")
      match
    end

    # Normalizes match content by trimming whitespace
    #
    # @api private
    # @param _ [Hash] Unused input parameter
    # @param match [Hash] The match to normalize
    # @param logger [Logger, nil] Optional logger
    # @return [Hash] The normalized match
    def self.preprocess(_, match, logger)
      match[:line] = match[:line].strip
      match[:captures] = match[:captures].map { |group| group.map(&:strip) }
      logger&.debug('Preprocess: normalized line and captures')
      match
    end

    # Adds contextual tags based on line content
    #
    # Currently detects:
    # - :contains_number - Line contains digits
    # - :contains_url - Line contains HTTP/HTTPS URLs
    # - :contains_email - Line contains email addresses
    #
    # @api private
    # @param _ [Hash] Unused input parameter
    # @param match [Hash] The match to annotate
    # @param logger [Logger, nil] Optional logger
    # @return [Hash] The annotated match
    def self.annotate(_, match, logger)
      match[:tags] = []
      match[:tags] << :contains_number if match[:line] =~ /\d/
      match[:tags] << :contains_url if match[:line] =~ %r{https?://}
      match[:tags] << :contains_email if match[:line] =~ /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i
      logger&.debug("Annotate: added tags #{match[:tags]}")
      match
    end

    # Adds statistical enrichments about the match
    #
    # Enrichments include:
    # - capture_count: Number of regex capture groups
    # - context_density: Number of context lines containing word chars
    #
    # @api private
    # @param _ [Hash] Unused input parameter
    # @param match [Hash] The match to enrich
    # @param logger [Logger, nil] Optional logger
    # @return [Hash] The enriched match
    def self.postprocess(_, match, logger)
      match[:enrichment] = {
        capture_count: match[:captures].flatten.size,
        context_density: [match[:context_before], match[:context_after]].compact.count do |l|
          l =~ /\w/
        end
      }
      logger&.debug("Postprocess: added enrichment #{match[:enrichment]}")
      match
    end
  end
end
