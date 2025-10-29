# frozen_string_literal: true

require 'marcel'

module RegexSearch
  module FileTypeDetector
    EXTENSION_MAP = {
      'application/json' => :json,
      'text/plain' => :txt,
      'application/x-yaml' => :yaml,
      'text/yaml' => :yaml,
      'application/xml' => :xml,
      'text/html' => :html,
      'application/rtf' => :rtf,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => :docx,
      'application/msword' => :doc,
      'application/vnd.ms-excel' => :xls,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => :xlsx,
      'application/pdf' => :pdf,
      'text/csv' => :csv
    }.freeze

    def self.detect(path)
      mime = Marcel::MimeType.for(Pathname.new(path), name: File.basename(path))
      EXTENSION_MAP[mime] || fallback(path)
    rescue StandardError => e
      warn "FileTypeDetector error: #{e.message}"
      fallback(path)
    end

    def self.fallback(path)
      ext = File.extname(path).delete('.').downcase.to_sym
      ext.empty? ? :txt : ext
    end

    def self.detect_from_content(content)
      return :json if content.strip.start_with?('{') || content.strip.start_with?('[')
      return :yaml if content.strip.start_with?('---')
      return :html if content.strip.downcase.start_with?('<!doctype html') || content.strip.downcase.start_with?('<html')
      return :xml if content.strip.downcase.start_with?('<?xml')

      :txt
    end
  end
end
