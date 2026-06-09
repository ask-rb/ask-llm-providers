# frozen_string_literal: true

require_relative "../test_helper"

class GoogleProviderTest < Minitest::Test
  def setup
    @provider = Ask::Providers::Google.new(api_key: "test-key")
  end

  def test_api_base
    assert_equal "https://generativelanguage.googleapis.com/v1beta", @provider.api_base
  end

  def test_chat_payload_builds
    messages = [{ role: "user", content: "Hello" }]
    payload = @provider.send(:build_chat_payload, messages, "gemini-2.5-pro", nil, nil, false, nil)
    assert payload[:contents]
    assert_equal 1, payload[:contents].length
    assert_equal "user", payload[:contents][0][:role]
    assert payload[:contents][0][:parts].is_a?(Array)
  end

  def test_chat_payload_separates_system
    messages = [
      { role: "system", content: "You are helpful" },
      { role: "user", content: "Hello" }
    ]
    payload = @provider.send(:build_chat_payload, messages, "gemini-2.5-pro", nil, nil, false, nil)
    assert payload[:systemInstruction]
    assert payload[:systemInstruction][:parts]
    assert_equal 1, payload[:contents].length
  end

  def test_format_content_with_tool_calls
    msg = { role: "assistant", content: nil, tool_calls: [{ id: "call_1", function: { name: "get_weather", arguments: '{"loc":"NYC"}' } }] }
    result = @provider.send(:format_content, msg)
    assert_equal "model", result[:role]
    assert result[:parts].any? { |p| p[:functionCall] }
  end

  def test_format_content_with_tool_result
    msg = { role: "tool", tool_call_id: "call_1", content: "Sunny", name: "get_weather" }
    result = @provider.send(:format_content, msg)
    assert result[:parts].any? { |p| p[:functionResponse] }
  end

  def test_response_parsing
    body = {
      "candidates" => [{
        "content" => { "parts" => [{ "text" => "Hello from Gemini" }], "role" => "model" },
        "finishReason" => "STOP"
      }],
      "usageMetadata" => { "promptTokenCount" => 10, "candidatesTokenCount" => 20 }
    }
    msg = @provider.send(:parse_response, body, "gemini-2.5-pro")
    assert_equal :assistant, msg.role
    assert_equal "Hello from Gemini", msg.content
  end

  def test_response_parsing_with_function_call
    body = {
      "candidates" => [{
        "content" => {
          "parts" => [{ "functionCall" => { "name" => "get_weather", "args" => { "location" => "NYC" } } }],
          "role" => "model"
        },
        "finishReason" => "STOP"
      }]
    }
    msg = @provider.send(:parse_response, body, "gemini-2.5-pro")
    assert msg.tool_call?
    assert_equal "get_weather", msg.tool_calls.first[:name]
  end

  def test_capabilities
    caps = Ask::Providers::Google.capabilities
    assert caps[:chat]
    assert caps[:streaming]
    assert caps[:tool_calls]
    assert caps[:vision]
  end
end
