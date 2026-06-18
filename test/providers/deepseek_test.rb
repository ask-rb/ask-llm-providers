# frozen_string_literal: true

require_relative "../test_helper"
require "vcr"
require "webmock/minitest"



VCR.configure do |config|
  config.cassette_library_dir = File.expand_path("../fixtures/vcr_cassettes", __dir__)
  config.hook_into :webmock
  config.default_cassette_options = { record: :once }

  config.filter_sensitive_data("<DEEPSEEK_API_KEY>") { ENV["DEEPSEEK_API_KEY"] }
  config.filter_sensitive_data("<AUTH_TOKEN>") { |interaction|
    interaction.request.headers["Authorization"]&.first
  }
end

class DeepSeekTest < Minitest::Test
  def setup
    @key = ENV["DEEPSEEK_API_KEY"] || (Ask::Auth.resolve(:deepseek_api_key) rescue nil)
    skip "Set DEEPSEEK_API_KEY in your environment or ~/.ask/credentials.yml" unless @key
    @provider = Ask::Providers::DeepSeek.new(api_key: @key)
  end

  def test_basic_chat
    VCR.use_cassette("deepseek/basic_chat") do
      resp = @provider.chat([{ role: "user", content: "Say hi in one word" }],
        model: "deepseek-chat", stream: false)
      assert resp.content.to_s.length > 0
      assert resp.content.to_s.downcase.include?("hi") || resp.content.to_s.downcase.include?("hello")
    end
  end

  def test_basic_chat_streaming
    VCR.use_cassette("deepseek/basic_chat_streaming") do
      chunks = []
      @provider.chat([{ role: "user", content: "Say hi" }],
        model: "deepseek-chat", stream: true) { |c| chunks << c }
      assert chunks.any?
      assert chunks.any? { |c| c.content.to_s.length > 0 }
    end
  end

  def test_tool_call
    VCR.use_cassette("deepseek/tool_call") do
      tool_def = Ask::ToolDef.new(
        name: "get_weather",
        description: "Get weather for a location",
        parameters: { type: "object", properties: { city: { type: "string" } }, required: ["city"] }
      )
      resp = @provider.chat(
        [{ role: "user", content: "What's weather in Paris?" }],
        model: "deepseek-chat", tools: [tool_def], stream: false)
      assert resp.tool_call?, "Expected tool call response"
      assert resp.tool_calls.first[:name] == "get_weather"
    end
  end

  def test_tool_call_streaming
    VCR.use_cassette("deepseek/tool_call_streaming") do
      tool_def = Ask::ToolDef.new(
        name: "get_weather",
        description: "Get weather for a location",
        parameters: { type: "object", properties: { city: { type: "string" } }, required: ["city"] }
      )
      chunks = []
      @provider.chat(
        [{ role: "user", content: "What's weather in Paris?" }],
        model: "deepseek-chat", tools: [tool_def], stream: true) { |c| chunks << c }

      # Should have tool call chunks
      tool_chunks = chunks.select { |c| c.tool_calls&.any? }
      assert tool_chunks.any?, "Should have tool call chunks in stream"
    end
  end

  def test_tool_result_multi_turn
    VCR.use_cassette("deepseek/tool_result_multi_turn") do
      tool_def = Ask::ToolDef.new(
        name: "get_time",
        description: "Get current time",
        parameters: { type: "object", properties: { tz: { type: "string" } }, required: ["tz"] }
      )

      messages = [
        { role: "user", content: "What time in UTC?" }
      ]
      resp = @provider.chat(messages, model: "deepseek-chat", tools: [tool_def], stream: false)
      assert resp.tool_call?, "First turn should return a tool call"

      tc = resp.tool_calls.first
      tc_id = tc[:id] || "call_1"
      tc_args = tc[:arguments].is_a?(String) ? tc[:arguments] : JSON.generate(tc[:arguments])
      messages << { role: :assistant, content: nil,
        tool_calls: [{ id: tc_id, type: "function", function: { name: tc[:name], arguments: tc_args } }] }
      messages << { role: :tool, content: "12:00 UTC", tool_call_id: tc_id }

      resp2 = @provider.chat(messages, model: "deepseek-chat",
        tools: [tool_def], stream: false)
      assert resp2.content.to_s.length > 0 || resp2.tool_call?,
        "Second turn should respond or call another tool"
    end
  end

  def test_tool_result_with_reasoning_content
    VCR.use_cassette("deepseek/tool_result_with_reasoning") do
      # This tests the fix: DeepSeek requires reasoning_content
      # on every assistant message with tool_calls
      tool_def = Ask::ToolDef.new(
        name: "t", description: "test",
        parameters: { type: "object", properties: { c: { type: "string" } }, required: ["c"] }
      )

      messages = [
        { role: "user", content: "hi" },
        { role: :assistant, content: nil,
          tool_calls: [{ id: "c1", type: "function", function: { name: "t", arguments: '{"c":"test"}' } }] },
        { role: :tool, content: "done", tool_call_id: "c1" }
      ]

      resp = @provider.chat(messages, model: "deepseek-chat",
        tools: [tool_def], stream: false)
      assert resp.content.to_s.length > 0, "Should get a response"
    end
  end

  def test_multi_turn_streaming_with_tools
    VCR.use_cassette("deepseek/multi_turn_streaming_tools") do
      tool_def = Ask::ToolDef.new(
        name: "t", description: "test",
        parameters: { type: "object", properties: { c: { type: "string" } }, required: ["c"] }
      )

      chunks = []
      @provider.chat(
        [{ role: "user", content: "hi" },
         { role: :assistant, content: nil,
           tool_calls: [{ id: "c1", type: "function", function: { name: "t", arguments: '{"c":"test"}' } }] },
         { role: :tool, content: "done", tool_call_id: "c1" }],
        model: "deepseek-chat", tools: [tool_def], stream: true) { |c| chunks << c }

      assert chunks.any?, "Should receive chunks"
      content_chunks = chunks.select { |c| c.content.to_s.length > 0 }
      assert content_chunks.any?, "Should have content in stream"
    end
  end

  def test_invalid_model_returns_error
    VCR.use_cassette("deepseek/invalid_model") do
      assert_raises Ask::ProviderError do
        @provider.chat([{ role: "user", content: "hi" }],
          model: "nonexistent-model", stream: false)
      end
    end
  end

  def test_list_models_returns_models
    VCR.use_cassette("deepseek/list_models") do
      models = @provider.list_models
      assert models.any?
      assert models.any? { |m| m.id.include?("deepseek") }
    end
  end
end
