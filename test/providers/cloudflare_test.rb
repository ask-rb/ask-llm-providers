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
end
