# frozen_string_literal: true

require_relative "../test_helper"

class OpenAIProviderTest < Minitest::Test
  def setup
    @provider = Ask::Providers::OpenAI.new(api_key: "sk-test")
  end

  def test_chat_payload_builds_correctly
    messages = [{ role: "user", content: "Hello" }]
    payload = @provider.send(:build_chat_payload, messages, "gpt-4o", nil, nil, false, nil)
    assert_equal "gpt-4o", payload[:model]
    assert_equal false, payload[:stream]
    assert_equal 1, payload[:messages].length
    assert_equal "user", payload[:messages][0][:role]
    assert_equal "Hello", payload[:messages][0][:content]
  end

  def test_chat_payload_includes_tools
    messages = [{ role: "user", content: "Hi" }]
    tools = [{ name: "get_weather", description: "Get weather", parameters: { type: "object", properties: {} } }]
    payload = @provider.send(:build_chat_payload, messages, "gpt-4o", tools, nil, false, nil)
    assert payload[:tools]
    assert_equal 1, payload[:tools].length
  end

  def test_chat_payload_includes_temperature
    messages = [{ role: "user", content: "Hi" }]
    payload = @provider.send(:build_chat_payload, messages, "gpt-4o", nil, 0.7, false, nil)
    assert_equal 0.7, payload[:temperature]
  end

  def test_chat_payload_includes_schema
    messages = [{ role: "user", content: "Hi" }]
    schema = { type: "object", properties: { name: { type: "string" } } }
    payload = @provider.send(:build_chat_payload, messages, "gpt-4o", nil, nil, false, schema)
    assert payload[:response_format]
    assert_equal "json_schema", payload[:response_format][:type]
  end

  def test_response_parsing
    body = {
      "id" => "chatcmpl-123",
      "model" => "gpt-4o",
      "choices" => [{
        "index" => 0,
        "message" => { "role" => "assistant", "content" => "Hello!" },
        "finish_reason" => "stop"
      }],
      "usage" => { "prompt_tokens" => 10, "completion_tokens" => 20 }
    }
    msg = @provider.send(:parse_response, body, "gpt-4o")
    assert_equal :assistant, msg.role
    assert_equal "Hello!", msg.content
    assert_equal "stop", msg.metadata[:finish_reason]
  end

  def test_response_parsing_with_tool_calls
    body = {
      "id" => "chatcmpl-456",
      "model" => "gpt-4o",
      "choices" => [{
        "index" => 0,
        "message" => {
          "role" => "assistant",
          "content" => nil,
          "tool_calls" => [{
            "id" => "call_1",
            "type" => "function",
            "function" => { "name" => "get_weather", "arguments" => '{"location":"NYC"}' }
          }]
        },
        "finish_reason" => "tool_calls"
      }],
      "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 }
    }
    msg = @provider.send(:parse_response, body, "gpt-4o")
    assert msg.tool_call?
    assert_equal 1, msg.tool_calls.length
    assert_equal "get_weather", msg.tool_calls.first[:name]
  end

  def test_headers
    headers = @provider.headers
    assert_equal "Bearer sk-test", headers["Authorization"]
    assert_equal "application/json", headers["Content-Type"]
  end

  def test_api_base_default
    assert_equal "https://api.openai.com/v1", @provider.api_base
  end

  def test_api_base_custom
    provider = Ask::Providers::OpenAI.new(api_key: "sk-test", base_url: "https://openrouter.ai/api/v1")
    assert_equal "https://openrouter.ai/api/v1", provider.api_base
  end
end
