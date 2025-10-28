# frozen_string_literal: true

module RegexSearch
  class Result
    attr_reader :line_number, :line, :context_before, :context_after,
                :captures, :insights, :tags, :enrichment,
                :path, :filetype

    def initialize(match:, input:)
      @line_number     = match[:line_number]
      @line            = match[:line]
      @context_before  = match[:context_before]
      @context_after   = match[:context_after]
      @captures        = match[:captures]
      @insights        = match[:insights]
      @tags            = match[:tags]
      @enrichment      = match[:enrichment]
      @path            = input[:path]
      @filetype        = input[:filetype]
    end

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
