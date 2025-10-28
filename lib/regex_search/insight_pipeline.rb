# frozen_string_literal: true

module RegexSearch
  module InsightPipeline
    def self.run(klass, input, match, logger = nil)
      logger&.debug("InsightPipeline: starting for #{klass}")

      match = preprocess(input, match, logger)
      match = annotate(input, match, logger)
      match = klass.call(input, match)
      match = postprocess(input, match, logger)

      logger&.debug("InsightPipeline: completed for line #{match[:line_number]}")
      match
    end

    # Normalize line content and capture structure
    def self.preprocess(_, match, logger)
      match[:line] = match[:line].strip
      match[:captures] = match[:captures].map { |group| group.map(&:strip) }
      logger&.debug('Preprocess: normalized line and captures')
      match
    end

    # Add basic tags or flags based on content
    def self.annotate(_, match, logger)
      match[:tags] = []
      match[:tags] << :contains_number if match[:line] =~ /\d/
      match[:tags] << :contains_url if match[:line] =~ %r{https?://}
      if match[:line] =~ /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i
        match[:tags] << :contains_email
      end
      logger&.debug("Annotate: added tags #{match[:tags]}")
      match
    end

    # Add enrichment based on match density or context
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
