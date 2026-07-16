# frozen_string_literal: true

require_relative "../test_helper"

class DeepSeekProviderTest < Minitest::Test
  include BaseProviderTests
  def provider_class
    Ask::Providers::DeepSeek
  end

  def provider_config
    { api_key: "sk-deepseek-test" }
  end

  def test_model
    "deepseek-chat"
  end

  # --- API base ---

  def test_api_base
    assert_equal "https://api.deepseek.com", @provider.api_base
  end

  # --- Headers ---

  def test_headers
    h = @provider.headers
    assert_equal "Bearer sk-deepseek-test", h["Authorization"]
  end

  # --- Capabilities ---

  def test_capabilities
    caps = provider_class.capabilities
    assert caps[:chat]; assert caps[:streaming]
    assert caps[:tool_calls]; assert caps[:thinking]
  end

  def test_slug
    assert_equal "deepseek", provider_class.slug
  end

  # --- Request building ---

  def test_build_request_basic
    payload = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model)
    assert_equal test_model, payload[:model]
    assert_equal false, payload[:stream]
  end

  def test_build_request_streaming
    payload = @provider.build_request([{ role: "user", content: "Hi" }], model: test_model, stream: true)
    assert payload[:stream]
  end

  def test_build_request_with_tools
    tools = [{ name: "get_weather", parameters: { type: "object" } }]
    payload = @provider.build_request([{ role: "user", content: "Hi" }], model: test_model, tools:)
    assert payload[:tools]
  end

  def test_build_request_with_temperature
    payload = @provider.build_request([{ role: "user", content: "Hi" }], model: test_model, temperature: 0.7)
    assert_equal 0.7, payload[:temperature]
  end

  # --- Response parsing ---

  def test_parse_response
    body = { "id" => "chatcmpl-123", "model" => "deepseek-chat",
             "choices" => [{ "index" => 0, "message" => { "role" => "assistant", "content" => "Hello!" },
                              "finish_reason" => "stop" }],
             "usage" => { "prompt_tokens" => 10, "completion_tokens" => 20 } }
    msg = @provider.parse_response(body, test_model)
    assert_equal :assistant, msg.role
    assert_equal "Hello!", msg.content
  end

  def test_parse_response_with_tool_calls
    body = { "id" => "chatcmpl-456", "model" => "deepseek-chat",
             "choices" => [{ "message" => { "tool_calls" => [{ "id" => "call_1",
                                                                "function" => { "name" => "get_weather" } }] },
                              "finish_reason" => "tool_calls" }] }
    msg = @provider.parse_response(body, test_model)
    assert msg.tool_call?
  end

  # --- Streaming ---

  def test_parse_stream
    stream = Ask::Stream.new
    data = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"}}]}\n\n"
    @provider.parse_stream(data, stream, test_model)
    assert_equal 1, stream.length
  end

  def test_parse_stream_done
    stream = Ask::Stream.new
    @provider.parse_stream("data: [DONE]\n\n", stream, test_model)
    assert_equal 0, stream.length
  end

  def test_parse_stream_invalid_json
    stream = Ask::Stream.new
    @provider.parse_stream("data: not json\n\n", stream, test_model)
    assert_equal 0, stream.length
  end

  # --- Parse error ---

  def test_parse_error
    response = Object.new
    def response.body; { "error" => { "message" => "Insufficient balance" } }; end
    error = @provider.parse_error(response)
    assert_includes error, "Insufficient"
  end

  # --- Config ---

  def test_config_requirements
    assert_includes provider_class.configuration_requirements, :api_key
  end

  # --- Override base tests ---

  def test_build_request_includes_model
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model)
    assert_equal test_model, result[:model]
  end

  def test_build_request_includes_stream_flag
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model, stream: true)
    assert_equal true, result[:stream]
  end
end
