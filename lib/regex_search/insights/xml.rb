# frozen_string_literal: true

require 'nokogiri'

module RegexSearch
  module Insights
    # XML-specific insight processor that finds element paths and context
    #
    # This processor analyzes XML files to provide additional context about
    # where in the XML structure a match was found. It generates metadata including
    # element tag name, XPath, element attributes, namespaces, and surrounding structure.
    #
    # @example XML insights for a match
    #   # For XML: <users><user id="1"><email>john@example.com</email></user></users>
    #   # When searching for "john@example.com":
    #   match[:insights] # => {
    #     element_tag: "email",
    #     xpath: "/users/user/email",
    #     element_text: "john@example.com",
    #     element_attributes: {},
    #     parent_tag: "user",
    #     parent_attributes: {"id" => "1"},
    #     namespaces: {}
    #   }
    #
    # @see RegexSearch::Insights::Base
    class Xml < Base
      # Processes a match in an XML file to find element and structural context
      #
      # @param input [Hash] Input metadata including:
      #   - :path [String] Path to the XML file (optional)
      #   - :data [String] XML content to parse
      # @param match [Hash] Match data including:
      #   - :line [String] The line containing the match
      #   - :captures [Array<Array<String>>] Captured groups from the regex
      # @return [Hash] Match with added insights:
      #   - insights.element_tag [String] XML tag name
      #   - insights.xpath [String] XPath to element
      #   - insights.element_text [String] Full text content of the element
      #   - insights.element_attributes [Hash] Element attributes
      #   - insights.parent_tag [String] Parent element tag name
      #   - insights.parent_attributes [Hash] Parent element attributes
      #   - insights.namespaces [Hash] Element namespaces
      #   - insights.error [String] Error message if parsing fails
      def self.call(input, match)
        begin
          # Get the XML content from input data or file path
          xml_content = input[:data].is_a?(String) ? input[:data] : File.read(input[:path])
          keyword = match[:captures].flatten.first # first captured string
          
          doc = Nokogiri::XML(xml_content)
          
          # Check for parsing errors
          if doc.errors.any?
            return match.merge(insights: { error: "Malformed XML: #{doc.errors.first.message}" })
          end
          
          # Find the element containing the matched text
          element = find_matching_element(doc, keyword, match[:line])
          
          if element
            insights = build_xml_insights(element, doc)
            match[:insights] = insights
          else
            match[:insights] = {
              element_tag: nil,
              xpath: nil,
              element_text: nil
            }
          end
        rescue Nokogiri::XML::SyntaxError => e
          match[:insights] = { error: "XML syntax error: #{e.message}" }
        rescue StandardError => e
          match[:insights] = { error: "XML processing error: #{e.message}" }
        end
        match
      end

      # Finds the XML element containing the matched keyword
      #
      # @api private
      # @param doc [Nokogiri::XML::Document] Parsed XML document
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
          
          # Check if the element's text content matches
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

      # Builds comprehensive XML insights from an element
      #
      # @api private
      # @param element [Nokogiri::XML::Element] The XML element
      # @param doc [Nokogiri::XML::Document] The XML document
      # @return [Hash] Complete insights hash
      def self.build_xml_insights(element, doc)
        parent = element.parent
        
        {
          element_tag: element.name,
          xpath: element.path,
          element_text: element.text.strip,
          element_attributes: extract_attributes(element),
          parent_tag: parent && parent.name != 'document' ? parent.name : nil,
          parent_attributes: parent && parent.name != 'document' ? extract_attributes(parent) : {},
          namespaces: doc.root ? doc.root.namespaces : {}
        }
      end

      # Extracts attributes from an element as a hash
      #
      # @api private
      # @param element [Nokogiri::XML::Element] The XML element
      # @return [Hash] Element attributes
      def self.extract_attributes(element)
        element.attributes.transform_values(&:value)
      end
    end
  end
end

