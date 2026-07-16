# frozen_string_literal: true

require_relative "../test_helper"

class AnthropicProviderTest < Minitest::Test
  include BaseProviderTests
  def provider_class
    Ask::Providers::Anthropic
  end

  def provider_config
    { api_key: "sk-ant-test" }
  end

  def test_model
    "claude-sonnet-4-5"
  end

  # --- Headers ---

  def test_headers
    h = @provider.headers
    assert_equal "sk-ant-test", h["x-api-key"]
    assert_equal "2023-06-01", h["anthropic-version"]
  end

  def test_api_base
    assert_equal "https://api.anthropic.com", @provider.api_base
  end

  # --- Response parsing ---

  def test_parse_response
    body = { "id" => "msg_123", "model" => "claude-sonnet-4-5",
             "content" => [{ "type" => "text", "text" => "Hello from Claude" }],
             "stop_reason" => "end_turn",
             "usage" => { "input_tokens" => 10, "output_tokens" => 20 } }
    msg = @provider.parse_response(body, test_model)
    assert_equal :assistant, msg.role
    assert_equal "Hello from Claude", msg.content
  end

  def test_parse_response_with_tool_calls
    body = { "id" => "msg_456", "model" => "claude-sonnet-4-5",
             "content" => [
               { "type" => "text", "text" => "Let me check" },
               { "type" => "tool_use", "id" => "toolu_1", "name" => "get_weather",
                 "input" => { "location" => "NYC" } }
             ], "stop_reason" => "tool_use" }
    msg = @provider.parse_response(body, test_model)
    assert msg.tool_call?
    assert_equal 1, msg.tool_calls.length
    assert_equal "get_weather", msg.tool_calls.first[:name]
  end

  def test_parse_response_with_thinking
    body = { "id" => "msg_789", "model" => "claude-sonnet-4-5",
             "content" => [
               { "type" => "thinking", "thinking" => "Let me reason about this..." },
               { "type" => "text", "text" => "Here is my answer." }
             ], "stop_reason" => "end_turn" }
    msg = @provider.parse_response(body, test_model)
    assert_equal "Here is my answer.", msg.content
    assert_includes msg.metadata[:thinking], "Let me reason"
  end

  # --- Message formatting ---

  def test_format_message_with_tool_result
    msg = { role: "user", tool_call_id: "toolu_1", content: "34°F" }
    formatted = @provider.format_message(msg)
    assert_equal "user", formatted[:role]
    assert formatted[:content].is_a?(Array)
    assert_equal "tool_result", formatted[:content][0][:type]
  end

  def test_format_message_with_tool_calls
    msg = { role: :assistant, content: nil,
            tool_calls: [{ id: "toolu_1", type: "function",
                           function: { name: "get_weather", arguments: '{"loc":"NYC"}' } }] }
    formatted = @provider.format_message(msg)
    assert_equal "assistant", formatted[:role]
    assert formatted[:tool_calls]
    assert_equal "tool_use", formatted[:tool_calls][0][:type]
  end

  # --- Request building ---

  def test_build_request_includes_max_tokens
    payload = @provider.build_request([{ role: "user", content: "Hi" }], model: test_model)
    assert payload[:max_tokens]
  end

  def test_build_request_system_message
    payload = @provider.build_request(
      [{ role: "system", content: "Be helpful." }, { role: "user", content: "Hi" }],
      model: test_model
    )
    assert payload[:system]
    assert_includes payload[:system], "Be helpful."
  end

  # --- Streaming ---

  def test_parse_stream_content_delta
    stream = Ask::Stream.new
    data = "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}\n\n"
    @provider.parse_stream(data, stream, test_model)
    assert stream.length > 0
  end

  def test_parse_stream_invalid_json
    stream = Ask::Stream.new
    @provider.parse_stream("not json\n", stream, test_model)
    assert_equal 0, stream.length
  end

  # --- Capabilities ---

  def test_capabilities
    caps = provider_class.capabilities
    assert caps[:chat]; assert caps[:streaming]
    assert caps[:thinking]; assert caps[:prompt_caching]
  end

  def test_embed_raises
    assert_raises(Ask::CapabilityNotSupported) { @provider.embed(["text"], model: test_model) }
  end

  # --- Parse error ---

  def test_parse_error
    response = Object.new
    def response.body; { "error" => { "message" => "Invalid request" } }; end
    error = @provider.parse_error(response)
    assert_includes error, "Invalid"
  end

  def test_parse_error_nil_body
    response = Object.new
    def response.body; nil; end
    assert_nil @provider.parse_error(response)
  end

  # --- Override base test for model check ---

  def test_build_request_includes_model
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model)
    assert_equal test_model, result[:model]
  end
end
