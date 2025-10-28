# frozen_string_literal: true

require_relative 'insights/base'
require_relative 'insights/json'

module RegexSearch
  module Insights
    SUPPORTED_FILE_TYPES = {
      txt: Base,
      json: Json
    }.freeze
  end
end
