# frozen_string_literal: true

# Prefer the sibling ask-core checkout when present (unreleased features
# like Ask::DataURI / Ask::Attachment are exercised by the test suite).
$LOAD_PATH.unshift File.expand_path("../../ask-core/lib", __dir__) if Dir.exist?(File.expand_path("../../ask-core/lib", __dir__))
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

# Provider test contract
require_relative "support/base_provider_test_support"
