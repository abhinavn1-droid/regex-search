# frozen_string_literal: true

require 'pdf-reader'

module RegexSearch
  module Insights
    # Provides PDF-specific insights for search matches
    class PDF < Base
      attr_reader :reader, :page_cache

      def initialize
        @reader = nil
        @page_cache = {}
        @current_page = nil
        @reader_path = nil
      end

      # match can be a Hash or Result-like object
      def process_match(match, input_path:, logger: nil)
        puts "\nProcessing match for #{input_path}"
        return match unless pdf?(input_path)

        begin
          setup_reader(input_path)
          puts "PDF reader setup complete. Match: #{match.inspect}"
          result = enrich_match_with_pdf_context(match)
          puts "Enrichment complete. Result: #{result.inspect}"
          result
        rescue StandardError => e
          logger&.error("PDF processing error: #{e.message}")
          puts "PDF processing error: #{e.full_message}"
          match
        end
      end

      private

      def setup_reader(path)
        return if @reader && path == @reader_path

        @reader_path = path
        begin
          @reader = ::PDF::Reader.new(path) if File.exist?(path)
        rescue StandardError => e
          warn "Error setting up PDF reader: #{e.message}"
          @reader = nil
        end
        @page_cache.clear
      end

      def enrich_match_with_pdf_context(match)
        return match unless @reader

        page_num = find_page_for_match(match)
        return match unless page_num

        if match.is_a?(Hash)
          match[:insights] ||= {}
          match[:insights].merge!(
            pdf_page: page_num,
            pdf_metadata: extract_metadata,
            section_context: extract_section_context(page_num, match[:line])
          )
          match[:tags] ||= []
          match[:tags] << :pdf_content
        else
          match.instance_variable_set(:@insights, {
                                        pdf_page: page_num,
                                        pdf_metadata: extract_metadata,
                                        section_context: extract_section_context(page_num,
                                                                                 match.line)
                                      })
          match.instance_variable_set(:@tags, (match.tags || []) + [:pdf_content])
        end

        match
      end

      def find_page_for_match(match)
        return nil unless @reader

        line = match.is_a?(Hash) ? match[:line] : match.line
        return @current_page if @current_page && page_contains?(line, @current_page)

        1.upto(reader.page_count) do |i|
          if page_contains?(line, i)
            @current_page = i
            return i
          end
        end

        nil
      end

      def page_contains?(text, page_num)
        return false unless @reader

        begin
          @page_cache[page_num] ||= begin
            page = reader.page(page_num)
            text_content = page.text
            text_content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
          end

          page_text = @page_cache[page_num].to_s
          search_text = text.to_s

          return true if page_text.include?(search_text)

          page_lines = page_text.split("\n").map(&:strip)
          search_lines = search_text.split("\n").map(&:strip)
          search_lines.each do |search_line|
            return true if page_lines.any? { |line| line.include?(search_line) }
          end

          false
        rescue StandardError => e
          warn "PDF page reading error: #{e.message}"
          false
        end
      end

      def extract_metadata
        return {} unless @reader

        {
          title: reader.info[:Title],
          author: reader.info[:Author],
          creator: reader.info[:Creator],
          producer: reader.info[:Producer],
          creation_date: reader.info[:CreationDate],
          page_count: reader.page_count
        }
      end

      def extract_section_context(page_num, line)
        return {} unless @reader && @page_cache[page_num]

        page_text = @page_cache[page_num]
        lines = page_text.split("\n").map(&:strip)
        line = line.strip if line
        match_index = lines.index(line)
        return {} unless match_index

        heading = find_nearest_heading(lines[0..match_index])
        {
          nearest_heading: heading,
          page_position: calculate_position(match_index, lines.size)
        }
      end

      def find_nearest_heading(lines)
        lines.reverse.find do |line|
          line = line.strip
          next if line.empty?

          line.match?(/^[A-Z\d\s]{4,}|^\d+(\.\d+)*\s|^[IVXLCDM]+\.\s/)
        end
      end

      def calculate_position(index, total)
        ratio = index.to_f / total
        case ratio
        when 0..0.33 then :top
        when 0.34..0.66 then :middle
        else :bottom
        end
      end

      def pdf?(path)
        File.extname(path).downcase == '.pdf'
      end
    end
  end
end
