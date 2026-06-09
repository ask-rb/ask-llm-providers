# frozen_string_literal: true

require_relative "../test_helper"

class AnthropicProviderTest < Minitest::Test
  def setup
    @provider = Ask::Providers::Anthropic.new(api_key: "sk-ant-test")
  end

  def test_headers
    h = @provider.headers
    assert_equal "sk-ant-test", h["x-api-key"]
    assert_equal "2023-06-01", h["anthropic-version"]
  end

  def test_api_base
    assert_equal "https://api.anthropic.com", @provider.api_base
  end

  def test_response_parsing
    body = {
      "id" => "msg_123",
      "model" => "claude-sonnet-4-5",
      "content" => [{ "type" => "text", "text" => "Hello from Claude" }],
      "stop_reason" => "end_turn",
      "usage" => { "input_tokens" => 10, "output_tokens" => 20 }
    }
    msg = @provider.send(:parse_response, body, "claude-sonnet-4-5")
    assert_equal :assistant, msg.role
    assert_equal "Hello from Claude", msg.content
    assert_equal "end_turn", msg.metadata[:stop_reason]
  end

  def test_response_parsing_with_tool_calls
    body = {
      "id" => "msg_456",
      "model" => "claude-sonnet-4-5",
      "content" => [
        { "type" => "text", "text" => "Let me check" },
        { "type" => "tool_use", "id" => "toolu_1", "name" => "get_weather", "input" => { "location" => "NYC" } }
      ],
      "stop_reason" => "tool_use",
      "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
    }
    msg = @provider.send(:parse_response, body, "claude-sonnet-4-5")
    assert msg.tool_call?
    assert_equal 1, msg.tool_calls.length
    assert_equal "get_weather", msg.tool_calls.first[:name]
  end

  def test_format_message_with_tool_result
    messages = [{ role: "user", tool_call_id: "toolu_1", content: "34°F" }]
    payload = @provider.send(:build_chat_payload, messages, "claude-sonnet-4-5", nil, nil, false, nil)
    msg = payload[:messages].first
    assert_equal "user", msg[:role]
    assert msg[:content].is_a?(Array)
    assert_equal "tool_result", msg[:content][0][:type]
  end

  def test_capabilities
    caps = Ask::Providers::Anthropic.capabilities
    assert caps[:chat]
    assert caps[:streaming]
    assert caps[:thinking]
    assert caps[:prompt_caching]
  end
end
