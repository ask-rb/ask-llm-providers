# frozen_string_literal: true

require_relative "../test_helper"

class MistralProviderTest < Minitest::Test
  include BaseProviderTests
  def provider_class
    Ask::Providers::Mistral
  end

  def provider_config
    { api_key: "test-key" }
  end

  def test_model
    "mistral-large-latest"
  end

  # --- API base ---

  def test_api_base
    assert_equal "https://api.mistral.ai/v1", @provider.api_base
  end

  # --- Headers ---

  def test_headers
    h = @provider.headers
    assert_equal "Bearer test-key", h["Authorization"]
  end

  # --- Capabilities ---

  def test_capabilities
    caps = provider_class.capabilities
    assert caps[:chat]; assert caps[:streaming]
    assert caps[:tool_calls]; assert caps[:structured_output]
    assert caps[:embed]
  end

  # --- Request building ---

  def test_build_request_basic
    payload = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model)
    assert_equal test_model, payload[:model]
    assert_equal false, payload[:stream]
    assert_equal 1, payload[:messages].length
  end

  def test_build_request_includes_temperature
    payload = @provider.build_request([{ role: "user", content: "Hi" }], model: test_model, temperature: 0.7)
    assert_equal 0.7, payload[:temperature]
  end

  # --- Response parsing ---

  def test_parse_response
    body = { "id" => "mistral-123", "model" => "mistral-large-latest",
             "choices" => [{ "index" => 0, "message" => { "role" => "assistant", "content" => "Hello!" },
                              "finish_reason" => "stop" }],
             "usage" => { "prompt_tokens" => 10, "completion_tokens" => 20 } }
    msg = @provider.parse_response(body, test_model)
    assert_equal :assistant, msg.role
    assert_equal "Hello!", msg.content
    assert_equal "stop", msg.metadata[:finish_reason]
  end

  # --- Parse error ---

  def test_parse_error
    response = Object.new
    def response.body; { "error" => { "message" => "Rate limit exceeded", "type" => "rate_limit_error" } }; end
    error = @provider.parse_error(response)
    assert_includes error, "Rate limit"
  end

  def test_parse_error_nil_body
    response = Object.new
    def response.body; nil; end
    assert_nil @provider.parse_error(response)
  end

  # --- Streaming ---

  def test_parse_stream
    stream = Ask::Stream.new
    data = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"}}]}\n\n"
    @provider.parse_stream(data, stream, test_model)
    assert_equal 1, stream.length
    assert_equal "Hello", stream.chunks.first.content
  end

  def test_parse_stream_done
    stream = Ask::Stream.new
    data = "data: [DONE]\n\n"
    @provider.parse_stream(data, stream, test_model)
    assert_equal 0, stream.length
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
