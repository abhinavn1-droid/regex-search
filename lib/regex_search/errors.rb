# frozen_string_literal: true

module RegexSearch
  module Errors
    class UnsupportedFileTypeError < StandardError; end
    class MalformedInputError < StandardError; end
    class FileReadError < StandardError; end
  end
end
