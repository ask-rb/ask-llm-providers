# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

begin
  require "simplecov"
  SimpleCov.start { add_filter "/test/"; minimum_coverage 90 }
rescue LoadError
end

require "minitest/autorun"
require "mocha/minitest"
require "json"

require "ask-llm-providers"
