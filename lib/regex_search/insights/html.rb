# frozen_string_literal: true

require 'nokogiri'

module RegexSearch
  module Insights
    # HTML-specific insight processor that finds element paths and context
    #
    # This processor analyzes HTML files to provide additional context about
    # where in the HTML structure a match was found. It generates metadata including
    # element tag name, CSS selector path, element attributes, and surrounding structure.
    #
    # @example HTML insights for a match
    #   # For HTML: <div class="user"><p>Contact: john@example.com</p></div>
    #   # When searching for "john@example.com":
    #   match[:insights] # => {
    #     element_tag: "p",
    #     css_path: "div.user > p",
    #     xpath: "//div[@class='user']/p",
    #     element_text: "Contact: john@example.com",
    #     element_attributes: {},
    #     parent_tag: "div",
    #     parent_attributes: {"class" => "user"}
    #   }
    #
    # @see RegexSearch::Insights::Base
    class Html < Base
      # Processes a match in an HTML file to find element and structural context
      #
      # @param input [Hash] Input metadata including:
      #   - :path [String] Path to the HTML file (optional)
      #   - :data [String] HTML content to parse
      # @param match [Hash] Match data including:
      #   - :line [String] The line containing the match
      #   - :captures [Array<Array<String>>] Captured groups from the regex
      # @return [Hash] Match with added insights:
      #   - insights.element_tag [String] HTML tag name
      #   - insights.css_path [String] CSS selector path to element
      #   - insights.xpath [String] XPath to element
      #   - insights.element_text [String] Full text content of the element
      #   - insights.element_attributes [Hash] Element attributes
      #   - insights.parent_tag [String] Parent element tag name
      #   - insights.parent_attributes [Hash] Parent element attributes
      #   - insights.error [String] Error message if parsing fails
      def self.call(input, match)
        begin
          # Get the HTML content from input data or file path
          html_content = input[:data].is_a?(String) ? input[:data] : File.read(input[:path])
          keyword = match[:captures].flatten.first # first captured string
          
          doc = Nokogiri::HTML(html_content)
          
          # Find the element containing the matched text
          element = find_matching_element(doc, keyword, match[:line])
          
          if element
            insights = build_html_insights(element)
            match[:insights] = insights
          else
            match[:insights] = {
              element_tag: nil,
              css_path: nil,
              xpath: nil
            }
          end
        rescue StandardError => e
          match[:insights] = { error: "HTML processing error: #{e.message}" }
        end
        match
      end

      # Finds the HTML element containing the matched keyword
      #
      # @api private
      # @param doc [Nokogiri::HTML::Document] Parsed HTML document
      # @param keyword [String] The text to search for
      # @param line [String] The full line containing the match
      # @return [Nokogiri::XML::Element, nil] The matching element
      def self.find_matching_element(doc, keyword, line)
        # Search for text nodes containing the keyword
        text_nodes = doc.xpath("//text()[contains(., '#{escape_xpath(keyword)}')]")
        
        # Filter to find the best matching element
        text_nodes.each do |text_node|
          element = text_node.parent
          next if element.name == 'document' # Skip document root
          
          # Check if the element's text content matches the line context
          element_text = element.text.strip
          return element if element_text.include?(keyword)
        end
        
        # Fallback: find any element containing the keyword
        text_nodes.first&.parent if text_nodes.any?
      end

      # Escapes special characters for XPath queries
      #
      # @api private
      # @param text [String] Text to escape
      # @return [String] Escaped text
      def self.escape_xpath(text)
        text.gsub("'", "\\'")
      end

      # Builds comprehensive HTML insights from an element
      #
      # @api private
      # @param element [Nokogiri::XML::Element] The HTML element
      # @return [Hash] Complete insights hash
      def self.build_html_insights(element)
        parent = element.parent
        
        {
          element_tag: element.name,
          css_path: build_css_path(element),
          xpath: element.path,
          element_text: element.text.strip,
          element_attributes: extract_attributes(element),
          parent_tag: parent && parent.name != 'document' ? parent.name : nil,
          parent_attributes: parent && parent.name != 'document' ? extract_attributes(parent) : {}
        }
      end

      # Builds a CSS selector path for an element
      #
      # @api private
      # @param element [Nokogiri::XML::Element] The HTML element
      # @return [String] CSS selector path
      def self.build_css_path(element)
        path_parts = []
        current = element
        
        while current && current.name != 'document'
          selector = current.name
          
          # Add ID if present
          if current['id']
            selector += "##{current['id']}"
            path_parts.unshift(selector)
            break # ID is unique, stop here
          end
          
          # Add class if present
          if current['class']
            classes = current['class'].split.join('.')
            selector += ".#{classes}" unless classes.empty?
          end
          
          path_parts.unshift(selector)
          current = current.parent
          
          # Limit depth to avoid overly long paths
          break if path_parts.length >= 5
        end
        
        path_parts.join(' > ')
      end

      # Extracts attributes from an element as a hash
      #
      # @api private
      # @param element [Nokogiri::XML::Element] The HTML element
      # @return [Hash] Element attributes
      def self.extract_attributes(element)
        element.attributes.transform_values(&:value)
      end
    end
  end
end

