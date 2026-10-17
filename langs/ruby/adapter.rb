#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'stringio'

def honepad_nonfinite?(value)
  case value
  when Float
    !!(value.nan? || value.infinite?)
  when Array
    value.any? { |item| honepad_nonfinite?(item) }
  when Hash
    value.any? { |_key, item| honepad_nonfinite?(item) }
  else
    false
  end
end

def honepad_tag(value)
  case value
  when Float
    return 'NaN' if value.nan?
    return 'Infinity' if value.infinite? == 1
    return '-Infinity' if value.infinite? == -1

    value
  when Array
    value.map { |item| honepad_tag(item) }
  when Hash
    value.transform_values { |item| honepad_tag(item) }
  else
    value
  end
end

def load_class(file, class_name)
  path = File.expand_path(file)
  dir = File.dirname(path)
  $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir)
  require File.basename(path, '.rb')
  Object.const_get(class_name)
end

def main
  orig_stdout = $stdout
  $stdout = StringIO.new
  file = ARGV[0]
  class_name = ARGV[1]
  cases_path = ARGV[2]
  cls = load_class(file, class_name)
  cases = JSON.parse(File.read(cases_path))
  failed = []
  passed = 0
  cases.each do |c|
    obj = cls.new
    ok = true
    c['calls'].each_with_index do |call, i|
      method = call['m']
      args = call['a']
      expected = call['e']
      begin
        actual = obj.public_send(method, *args)
      rescue StandardError => err
        failed << {
          'case' => c['id'],
          'index' => i,
          'method' => method,
          'expected' => expected,
          'actual' => "exc:#{err.class.name}"
        }
        ok = false
        break
      end
      bad = honepad_nonfinite?(actual)
      if bad || JSON.generate(actual) != JSON.generate(expected)
        failed << {
          'case' => c['id'],
          'index' => i,
          'method' => method,
          'expected' => expected,
          'actual' => bad ? honepad_tag(actual) : actual
        }
        ok = false
        break
      end
    end
    passed += 1 if ok
  end
  orig_stdout.write(JSON.generate({ 'passed' => passed, 'failed' => failed }) + "\n")
  exit(failed.empty? ? 0 : 1)
end

main
