# frozen_string_literal: true

require_relative "../test_helper"

class CloudflareProviderTest < Minitest::Test
  def setup
    @provider = Ask::Providers::Cloudflare.new(api_key: "cf-key", account_id: "acct-123")
  end

  def test_api_base_workers_ai
    assert_equal "https://api.cloudflare.com/client/v4/accounts/acct-123/ai/v1", @provider.api_base
  end

  def test_api_base_gateway
    provider = Ask::Providers::Cloudflare.new(api_key: "cf-key", account_id: "acct-123", gateway_id: "my-gateway")
    assert_equal "https://gateway.ai.cloudflare.com/v1/acct-123/my-gateway", provider.api_base
  end

  def test_headers
    h = @provider.headers
    assert_equal "Bearer cf-key", h["Authorization"]
  end

  def test_capabilities
    caps = Ask::Providers::Cloudflare.capabilities
    assert caps[:chat]
    assert caps[:vision]
  end

  def test_configuration_requirements
    reqs = Ask::Providers::Cloudflare.configuration_requirements
    assert_includes reqs, :api_key
    assert_includes reqs, :account_id
  end

  def test_slug
    assert_equal "cloudflare", Ask::Providers::Cloudflare.slug
  end

  def test_parse_openai_response
    body = {
      "id" => "cf-123",
      "model" => "@cf/meta/llama-2",
      "choices" => [{
        "index" => 0,
        "message" => { "role" => "assistant", "content" => "Hello from CF!" },
        "finish_reason" => "stop"
      }]
    }
    msg = @provider.__send__(:parse_openai_response, body, "@cf/meta/llama-2")
    assert_equal :assistant, msg.role
    assert_equal "Hello from CF!", msg.content
  end

  def test_process_stream_chunk
    stream = Ask::Stream.new
    data = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"}}]}\n\n"
    @provider.__send__(:process_stream_chunk, data, stream, "@cf/meta/llama-2")
    assert_equal 1, stream.length
    assert_equal "Hello", stream.chunks.first.content
  end

  def test_parse_error
    error_response = Object.new
    def error_response.body; { "errors" => [{ "message" => "Invalid request" }] }; end
    error = @provider.parse_error(error_response)
    assert_includes error, "Invalid"
  end
end
