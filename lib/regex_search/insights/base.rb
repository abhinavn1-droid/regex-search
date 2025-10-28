# frozen_string_literal: true

module RegexSearch
  module Insights
    class Base
      def self.call(_, match)
        match
      end
    end
  end
end
