# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../lib/regex_search'

class TestInsightsJavaScript < Minitest::Test
  def setup
    @js_source = <<~JS
      import React, { useState, useEffect } from 'react';
      import { Button } from './components/Button';
      
      // Component documentation
      const MyComponent = ({ name, age }) => {
        const [count, setCount] = useState(0);
        
        useEffect(() => {
          console.log('Component mounted');
        }, []);
        
        const handleClick = () => {
          setCount(count + 1);
          return 'clicked';
        };
        
        return (
          <div className="container">
            <h1>Hello, {name}!</h1>
            <Button onClick={handleClick}>
              Count: {count}
            </Button>
          </div>
        );
      };
      
      export default MyComponent;
    JS

    @ts_source = <<~TS
      import React, { useState, useEffect } from 'react';
      import type { User } from './types/User';
      
      interface Props {
        name: string;
        age: number;
      }
      
      const MyComponent: React.FC<Props> = ({ name, age }) => {
        const [count, setCount] = useState<number>(0);
        
        useEffect(() => {
          console.log('Component mounted');
        }, []);
        
        const handleClick = (): string => {
          setCount(count + 1);
          return 'clicked';
        };
        
        return (
          <div className="container">
            <h1>Hello, {name}!</h1>
            <button onClick={handleClick}>
              Count: {count}
            </button>
          </div>
        );
      };
      
      export default MyComponent;
    TS

    @js_file = Tempfile.new(['sample', '.js'])
    @js_file.write(@js_source)
    @js_file.flush

    @ts_file = Tempfile.new(['sample', '.ts'])
    @ts_file.write(@ts_source)
    @ts_file.flush
  end

  def teardown
    @js_file.close
    @js_file.unlink
    @ts_file.close
    @ts_file.unlink
  end

  def test_function_container_detection
    results = RegexSearch::Runner.new(
      input: @js_file.path,
      pattern: /return 'clicked'/,
      mode: 'find_in_file'
    ).results

    insights = results.first[:result].first.insights
    assert_equal 'function', insights[:container_type]
    assert_equal 'handleClick', insights[:container]
    assert_equal 'module.handleClick()', insights[:js_path]
  end

  def test_component_container_detection
    results = RegexSearch::Runner.new(
      input: @js_file.path,
      pattern: /const \[count, setCount\]/,
      mode: 'find_in_file'
    ).results

    insights = results.first[:result].first.insights
    assert_equal 'component', insights[:container_type]
    assert_equal 'MyComponent', insights[:container]
    assert_equal 'module.MyComponent', insights[:js_path]
  end

  def test_jsx_detection
    results = RegexSearch::Runner.new(
      input: @js_file.path,
      pattern: /Hello, \{name\}!/,
      mode: 'find_in_file'
    ).results

    insights = results.first[:result].first.insights
    assert insights[:in_jsx]
    assert_equal 'component', insights[:container_type]
    assert_equal 'MyComponent', insights[:container]
  end

  def test_comment_detection
    results = RegexSearch::Runner.new(
      input: @js_file.path,
      pattern: /Component documentation/,
      mode: 'find_in_file'
    ).results

    insights = results.first[:result].first.insights
    assert insights[:in_comment]
  end

  def test_import_export_context
    results = RegexSearch::Runner.new(
      input: @js_file.path,
      pattern: /console\.log/,
      mode: 'find_in_file'
    ).results

    insights = results.first[:result].first.insights
    assert insights[:import_export_context].any? { |l| l.include?('import') }
  end

  def test_typescript_type_detection
    results = RegexSearch::Runner.new(
      input: @ts_file.path,
      pattern: /: React\.FC<Props>/,
      mode: 'find_in_file'
    ).results

    insights = results.first[:result].first.insights
    assert_equal 'type_annotation', insights[:type_hint]
    assert_equal 'component', insights[:container_type]
    assert_equal 'MyComponent', insights[:container]
  end

  def test_typescript_interface_detection
    results = RegexSearch::Runner.new(
      input: @ts_file.path,
      pattern: /interface Props/,
      mode: 'find_in_file'
    ).results

    insights = results.first[:result].first.insights
    assert_equal 'type_annotation', insights[:type_hint]
    assert_equal 'module', insights[:container_type]
  end

  def test_typescript_generic_type_detection
    results = RegexSearch::Runner.new(
      input: @ts_file.path,
      pattern: /useState<number>/,
      mode: 'find_in_file'
    ).results

    insights = results.first[:result].first.insights
    assert_equal 'generic_type', insights[:type_hint]
  end

  def test_file_type_detection
    js_type = RegexSearch::FileTypeDetector.detect(@js_file.path)
    ts_type = RegexSearch::FileTypeDetector.detect(@ts_file.path)
    
    assert_equal :js, js_type
    assert_equal :ts, ts_type

    processor = RegexSearch::Insights::SUPPORTED_FILE_TYPES[:js]
    assert_equal RegexSearch::Insights::JavaScript, processor
  end

  def test_jsx_file_detection
    jsx_file = Tempfile.new(['sample', '.jsx'])
    jsx_file.write(@js_source)
    jsx_file.flush

    jsx_type = RegexSearch::FileTypeDetector.detect(jsx_file.path)
    assert_equal :jsx, jsx_type

    jsx_file.close
    jsx_file.unlink
  end

  def test_tsx_file_detection
    tsx_file = Tempfile.new(['sample', '.tsx'])
    tsx_file.write(@ts_source)
    tsx_file.flush

    tsx_type = RegexSearch::FileTypeDetector.detect(tsx_file.path)
    assert_equal :tsx, tsx_type

    tsx_file.close
    tsx_file.unlink
  end
end
