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
    body = { "id" => "msg_123", "model" => "claude-sonnet-4-5",
             "content" => [{ "type" => "text", "text" => "Hello from Claude" }],
             "stop_reason" => "end_turn",
             "usage" => { "input_tokens" => 10, "output_tokens" => 20 } }
    msg = @provider.send(:parse_response, body, "claude-sonnet-4-5")
    assert_equal :assistant, msg.role
    assert_equal "Hello from Claude", msg.content
  end

  def test_response_parsing_with_tool_calls
    body = { "id" => "msg_456", "model" => "claude-sonnet-4-5",
             "content" => [
               { "type" => "text", "text" => "Let me check" },
               { "type" => "tool_use", "id" => "toolu_1", "name" => "get_weather", "input" => { "location" => "NYC" } }
             ], "stop_reason" => "tool_use" }
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
    assert caps[:chat]; assert caps[:streaming]; assert caps[:thinking]; assert caps[:prompt_caching]
  end

  def test_chat_payload_with_streaming
    messages = [{ role: "user", content: "Hi" }]
    payload = @provider.send(:build_chat_payload, messages, "claude-sonnet-4-5", nil, nil, true, nil)
    assert payload[:stream]
  end

  def test_chat_payload_with_tools
    messages = [{ role: "user", content: "Hi" }]
    tools = [{ name: "get_weather", description: "Get weather", parameters: { type: "object" } }]
    payload = @provider.send(:build_chat_payload, messages, "claude-sonnet-4-5", tools, nil, false, nil)
    assert payload[:tools]
  end

  def test_process_anthropic_chunk_content_delta
    stream = Ask::Stream.new
    data = "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}\n\n"
    @provider.send(:process_anthropic_chunk, data, stream, "claude-sonnet-4-5")
    assert stream.length > 0
  end

  def test_process_anthropic_chunk_invalid_json
    stream = Ask::Stream.new
    @provider.send(:process_anthropic_chunk, "not json\n", stream, "claude-sonnet-4-5")
    assert_equal 0, stream.length
  end

  def test_parse_error
    response = Object.new
    def response.body; { "error" => { "message" => "Invalid request" } }; end
    error = @provider.parse_error(response)
    assert_includes error, "Invalid"
  end

  def test_parse_error_with_nil_body
    response = Object.new
    def response.body; nil; end
    assert_nil @provider.parse_error(response)
  end

  def test_slug
    assert_equal "anthropic", Ask::Providers::Anthropic.slug
  end

  def test_configuration_options
    assert_includes Ask::Providers::Anthropic.configuration_options, :api_key
  end

  def test_configuration_requirements
    assert_includes Ask::Providers::Anthropic.configuration_requirements, :api_key
  end

  def test_chat_payload_includes_temperature
    messages = [{ role: "user", content: "Hi" }]
    payload = @provider.send(:build_chat_payload, messages, "claude-sonnet-4-5", nil, 0.7, false, nil)
    assert_equal 0.7, payload.dig(:extra_headers, "anthropic-version") || payload[:temperature]
  end

  def test_responds_to_chat
    assert_respond_to @provider, :chat
  end

  def test_responds_to_embed
    assert_respond_to @provider, :embed
  end
end
