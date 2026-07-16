# frozen_string_literal: true

require_relative "../test_helper"

class CloudflareProviderTest < Minitest::Test
  include BaseProviderTests
  def provider_class
    Ask::Providers::Cloudflare
  end

  def provider_config
    { api_key: "cf-key", account_id: "acct-123" }
  end

  def test_model
    "@cf/meta/llama-2"
  end

  # --- API base ---

  def test_api_base_workers_ai
    assert_equal "https://api.cloudflare.com/client/v4/accounts/acct-123/ai/v1",
                 @provider.api_base
  end

  def test_api_base_gateway
    provider = provider_class.new(api_key: "cf-key", account_id: "acct-123", gateway_id: "my-gateway")
    assert_equal "https://gateway.ai.cloudflare.com/v1/acct-123/my-gateway",
                 provider.api_base
  end

  # --- Headers ---

  def test_headers
    h = @provider.headers
    assert_equal "Bearer cf-key", h["Authorization"]
  end

  # --- Response parsing ---

  def test_parse_openai_response
    body = {
      "id" => "cf-123", "model" => "@cf/meta/llama-2",
      "choices" => [{ "index" => 0, "message" => { "role" => "assistant", "content" => "Hello from CF!" },
                       "finish_reason" => "stop" }]
    }
    # Use parse_response directly — it routes through parse_openai_response
    # via gateway detection
    provider = provider_class.new(api_key: "cf-key", account_id: "acct-123", gateway_id: "gw-1")
    msg = provider.parse_response(body, test_model)
    assert_equal :assistant, msg.role
    assert_equal "Hello from CF!", msg.content
  end

  def test_parse_response_workers_ai
    body = { "result" => { "response" => "Hello from Workers AI" } }
    msg = @provider.parse_response(body, test_model)
    assert_equal :assistant, msg.role
    assert_equal "Hello from Workers AI", msg.content
  end

  # --- Streaming ---

  def test_parse_stream
    stream = Ask::Stream.new
    data = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"}}]}\n\n"
    @provider.parse_stream(data, stream, test_model)
    assert_equal 1, stream.length
    assert_equal "Hello", stream.chunks.first.content
  end

  # --- Parse error ---

  def test_parse_error
    response = Object.new
    def response.body; { "errors" => [{ "message" => "Invalid request" }] }; end
    error = @provider.parse_error(response)
    assert_includes error, "Invalid"
  end

  def test_parse_error_openai_style
    response = Object.new
    def response.body; { "error" => { "message" => "Rate limited" } }; end
    error = @provider.parse_error(response)
    assert_includes error, "Rate"
  end

  # --- Capabilities ---

  def test_capabilities
    caps = provider_class.capabilities
    assert caps[:chat]; assert caps[:vision]
  end

  # --- Config requirements ---

  def test_requires_api_key_and_account
    reqs = provider_class.configuration_requirements
    assert_includes reqs, :api_key
    assert_includes reqs, :account_id
  end

  # --- Override base tests ---

  def test_build_request_includes_model
    provider = provider_class.new(api_key: "cf-key", account_id: "acct-123", gateway_id: "gw-1")
    result = provider.build_request([{ role: "user", content: "Hello" }], model: test_model)
    assert_equal test_model, result[:model]
  end

  def test_build_request_includes_stream_flag
    provider = provider_class.new(api_key: "cf-key", account_id: "acct-123", gateway_id: "gw-1")
    result = provider.build_request([{ role: "user", content: "Hello" }], model: test_model, stream: true)
    assert_equal true, result[:stream]
  end

  def test_list_models
    result = @provider.list_models
    assert_kind_of Array, result
    assert_empty result
  end
end
