# frozen_string_literal: true

require 'mapi/msg'

module RegexSearch
  module Insights
    # MSG-specific insight processor for Outlook .msg email files
    #
    # This processor analyzes MSG (Outlook email message) files to provide
    # context about where in the message structure a match was found,
    # including email headers, sender/recipient information, subject, and
    # which part of the message (subject, body, attachment) contained the match.
    #
    # @example MSG insights for a match
    #   match[:insights] # => {
    #     msg_from: "sender@example.com",
    #     msg_to: ["recipient@example.com"],
    #     msg_subject: "Project Update",
    #     msg_date: "2024-01-15",
    #     msg_location: "body",
    #     msg_body_type: "plain"
    #   }
    #
    # @see RegexSearch::Insights::Base
    class Msg < Base
      # Processes a match in an MSG email message file
      #
      # @param input [Hash] Input metadata including:
      #   - :path [String] Path to the MSG file
      # @param match [Hash] Match data including:
      #   - :line_number [Integer] Line number where match was found
      #   - :line [String] The line containing the match
      #   - :captures [Array] Captured groups from the regex
      # @return [Hash] Match with added insights
      def self.call(input, match)
        begin
          file_path = input[:path]
          keyword = match[:captures].flatten.first
          line_text = match[:line]
          
          # Parse MSG file - open fresh each time to avoid stream exhaustion
          ::Mapi::Msg.open(file_path) do |msg|
            # Extract message metadata and content
            message_data = extract_message_data(msg)
            
            # Find where the match occurred
            location = find_match_location(message_data, keyword, line_text)
            
            # Build insights
            insights = {
              msg_from: message_data[:from],
              msg_to: message_data[:to],
              msg_cc: message_data[:cc],
              msg_subject: message_data[:subject],
              msg_date: message_data[:date],
              msg_location: location[:part],
              msg_body_type: location[:body_type]
            }
            
            match[:insights] = insights
          end
        rescue StandardError => e
          match[:insights] = { error: "MSG processing error: #{e.message}" }
        end
        match
      end

      # Extracts message data from an MSG file
      #
      # @api private
      # @param msg [Mapi::Msg] The opened MSG message object
      # @return [Hash] Message data
      def self.extract_message_data(msg)
        # Remove null bytes from subject
        subject = msg.subject || ''
        subject = subject.gsub("\u0000", '') if subject.is_a?(String)
        
        {
          from: extract_sender(msg),
          to: extract_recipients(msg, :to),
          cc: extract_recipients(msg, :cc),
          subject: subject,
          date: extract_date(msg),
          body_plain: extract_body(msg, :plain),
          body_html: extract_body(msg, :html),
          attachments: extract_attachment_names(msg)
        }
      end

      # Extracts sender information
      #
      # @api private
      # @param msg [Mapi::Msg] The MSG message object
      # @return [String, nil] Sender email address or name
      def self.extract_sender(msg)
        return nil unless msg.respond_to?(:from)
        sender = msg.from
        sender = sender.is_a?(String) ? sender : (sender.respond_to?(:email) ? sender.email : sender.to_s)
        # Remove null bytes
        sender&.gsub("\u0000", '')
      rescue StandardError
        nil
      end

      # Extracts recipient list
      #
      # @api private
      # @param msg [Mapi::Msg] The MSG message object
      # @param type [Symbol] Type of recipients (:to, :cc, :bcc)
      # @return [Array<String>] List of recipient email addresses
      def self.extract_recipients(msg, type)
        return [] unless msg.respond_to?(type)
        recipients = msg.send(type)
        return [] if recipients.nil?
        
        recipients = [recipients] unless recipients.is_a?(Array)
        recipients.map do |r|
          r.is_a?(String) ? r : (r.respond_to?(:email) ? r.email : r.to_s)
        end.compact
      rescue StandardError
        []
      end

      # Extracts date from message
      #
      # @api private
      # @param msg [Mapi::Msg] The MSG message object
      # @return [String, nil] Message date
      def self.extract_date(msg)
        return nil unless msg.respond_to?(:date)
        date = msg.date
        return nil if date.nil?
        date.respond_to?(:strftime) ? date.strftime('%Y-%m-%d %H:%M:%S') : date.to_s
      rescue StandardError
        nil
      end

      # Extracts message body
      #
      # @api private
      # @param msg [Mapi::Msg] The MSG message object
      # @param format [Symbol] Body format (:plain or :html)
      # @return [String, nil] Message body text
      def self.extract_body(msg, format)
        property_name = format == :plain ? :body : :body_html
        return nil unless msg.properties.keys.include?(property_name)
        
        body_stream = msg.properties[property_name]
        return nil if body_stream.nil?
        
        # Rewind stream if possible, then read
        body_stream.rewind if body_stream.respond_to?(:rewind)
        body = body_stream.read
        return nil if body.nil? || body.empty?
        
        # For HTML, strip tags to get plain text for searching
        if format == :html
          body = strip_html_tags(body)
        end
        
        body
      rescue StandardError
        nil
      end

      # Strips HTML tags from text
      #
      # @api private
      # @param html [String] HTML content
      # @return [String] Plain text
      def self.strip_html_tags(html)
        # Simple HTML tag removal
        text = html.gsub(/<script[^>]*>.*?<\/script>/im, '')
        text = text.gsub(/<style[^>]*>.*?<\/style>/im, '')
        text = text.gsub(/<[^>]+>/, ' ')
        text = text.gsub(/\s+/, ' ').strip
        text
      end

      # Extracts attachment names
      #
      # @api private
      # @param msg [Mapi::Msg] The MSG message object
      # @return [Array<String>] List of attachment filenames
      def self.extract_attachment_names(msg)
        return [] unless msg.respond_to?(:attachments)
        attachments = msg.attachments
        return [] if attachments.nil?
        
        attachments.map do |att|
          att.respond_to?(:filename) ? att.filename : att.to_s
        end.compact
      rescue StandardError
        []
      end

      # Finds where in the message the match occurred
      #
      # @api private
      # @param message_data [Hash] Extracted message data
      # @param keyword [String] The matched keyword
      # @param line_text [String] The full line text
      # @return [Hash] Location information
      def self.find_match_location(message_data, keyword, line_text)
        # Check subject
        if message_data[:subject]&.include?(keyword) || message_data[:subject] == line_text
          return { part: 'subject', body_type: nil }
        end
        
        # Check plain text body
        if message_data[:body_plain]&.include?(keyword)
          return { part: 'body', body_type: 'plain' }
        end
        
        # Check HTML body
        if message_data[:body_html]&.include?(keyword)
          return { part: 'body', body_type: 'html' }
        end
        
        # Check attachments
        message_data[:attachments].each do |att_name|
          if att_name.include?(keyword)
            return { part: 'attachment', body_type: nil }
          end
        end
        
        # Default: unknown location
        { part: 'unknown', body_type: nil }
      end
    end
  end
end

