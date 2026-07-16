# frozen_string_literal: true

require_relative "../test_helper"

class GoogleProviderTest < Minitest::Test
  include BaseProviderTests
  def provider_class
    Ask::Providers::Google
  end

  def provider_config
    { api_key: "google-test-key" }
  end

  def test_model
    "gemini-2.0-flash"
  end

  # --- Headers ---

  def test_headers
    h = @provider.headers
    assert_equal "application/json", h["Content-Type"]
  end

  def test_api_base
    assert_equal "https://generativelanguage.googleapis.com/v1beta", @provider.api_base
  end

  # --- Response parsing ---

  def test_parse_response
    body = { "candidates" => [{
      "content" => { "parts" => [{ "text" => "Hello from Gemini" }] },
      "finishReason" => "STOP"
    }], "usageMetadata" => { "promptTokenCount" => 10, "candidatesTokenCount" => 20 } }
    msg = @provider.parse_response(body, test_model)
    assert_equal :assistant, msg.role
    assert_equal "Hello from Gemini", msg.content
  end

  def test_parse_response_with_tool_calls
    body = { "candidates" => [{
      "content" => {
        "parts" => [
          { "text" => "Let me check" },
          { "functionCall" => { "name" => "get_weather", "args" => { "location" => "NYC" } } }
        ]
      },
      "finishReason" => "STOP"
    }] }
    msg = @provider.parse_response(body, test_model)
    assert msg.tool_call?
    assert_equal 1, msg.tool_calls.length
    assert_equal "get_weather", msg.tool_calls.first[:name]
  end

  def test_parse_response_nil
    body = {}
    msg = @provider.parse_response(body, test_model)
    assert_equal :assistant, msg.role
    assert_nil msg.content
  end

  # --- Request building ---

  def test_build_request_contents
    payload = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model)
    assert payload[:contents]
    assert_equal 1, payload[:contents].length
  end

  def test_build_request_system_instruction
    payload = @provider.build_request(
      [{ role: "system", content: "Be helpful." }, { role: "user", content: "Hi" }],
      model: test_model
    )
    assert payload[:systemInstruction]
    assert payload[:systemInstruction][:parts]
  end

  # --- Streaming ---

  def test_parse_stream
    stream = Ask::Stream.new
    data = "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Hello\"}],\"role\":\"model\"}}]}\n\n"
    @provider.parse_stream(data, stream, test_model)
    assert_equal 1, stream.length
    assert_equal "Hello", stream.chunks.first.content
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
    assert caps[:tool_calls]; assert caps[:vision]
    assert caps[:embed]
  end

  def test_slug
    assert_equal "gemini", provider_class.slug
  end

  # --- Message formatting ---

  def test_format_message_user
    formatted = @provider.format_message({ role: :user, content: "Hello" })
    assert_equal "user", formatted[:role]
    assert formatted[:parts]
    assert formatted[:parts][0][:text]
  end

  def test_format_message_assistant
    formatted = @provider.format_message({ role: :assistant, content: "Hi" })
    assert_equal "model", formatted[:role]
  end

  def test_format_message_with_tool_calls
    msg = { role: :assistant, content: nil,
            tool_calls: [{ id: "call_1", function: { name: "get_weather", arguments: '{"loc":"NYC"}' } }] }
    formatted = @provider.format_message(msg)
    assert_equal "model", formatted[:role]
    assert formatted[:parts].any? { |p| p[:functionCall] }
  end

  # --- Parse error ---

  def test_parse_error
    response = Object.new
    def response.body; { "error" => { "message" => "API key invalid" } }; end
    error = @provider.parse_error(response)
    assert_includes error, "API key"
  end

  # --- Override base tests ---

  def test_build_request_includes_model
    # Google uses model in the URL path, not the payload
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model)
    assert result[:contents]
  end

  def test_build_request_includes_stream_flag
    # Google doesn't use a stream flag in payload
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model, stream: true)
    refute result.key?(:stream)
  end

  def test_build_request_includes_temperature_when_given
    result = @provider.build_request([{ role: "user", content: "Hello" }],
                                     model: test_model, temperature: 0.7)
    assert_equal 0.7, result.dig(:generationConfig, :temperature)
  end
end
