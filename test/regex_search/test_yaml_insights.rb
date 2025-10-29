# frozen_string_literal: true

require 'test_helper'
require 'regex_search/insights/yaml'

module RegexSearch
  module Insights
    class TestYamlInsights < Minitest::Test
      def setup
        @sample_yaml = <<~YAML
          server:
            host: localhost
            port: 3000
            database:
              name: myapp_db
              credentials:
                username: admin
                password: secret123
          environment: production
          features:
            - logging
            - authentication
            - caching
        YAML
      end

      def test_basic_yaml_path_detection
        match = { line_number: 2, line: 'host: localhost' }
        result = Yaml.call(@sample_yaml, match)

        assert_equal 'server.host', result[:insights][:yaml_path]
      end

      def test_nested_yaml_path_detection
        match = { line_number: 7, line: 'username: admin' }
        result = Yaml.call(@sample_yaml, match)

        assert_equal 'server.database.credentials.username', result[:insights][:yaml_path]
      end

      def test_array_element_detection
        match = { line_number: 12, line: '- authentication' }
        result = Yaml.call(@sample_yaml, match)

        assert_equal 'features.1', result[:insights][:yaml_path]
      end

      def test_parent_structure_for_nested_element
        match = { line_number: 7, line: 'username: admin' }
        result = Yaml.call(@sample_yaml, match)

        expected_parent = {
          'username' => 'admin',
          'password' => 'secret123'
        }

        assert_equal expected_parent, result[:insights][:parent_structure]
      end

      def test_invalid_yaml_handling
        invalid_yaml = "invalid:\n  - foo:\n  bar: baz"
        match = { line_number: 1, line: 'invalid:' }
        result = Yaml.call(invalid_yaml, match)

        assert_empty result[:insights][:yaml_path]
        assert_empty result[:insights][:parent_structure]
      end
    end
  end
end
