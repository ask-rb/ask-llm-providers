# frozen_string_literal: true

require_relative "../test_helper"

class BedrockProviderTest < Minitest::Test
  def setup
    @provider = Ask::Providers::Bedrock.new(region: "us-east-1")
  end

  def test_api_base_is_region
    assert_equal "us-east-1", @provider.api_base
  end

  def test_custom_region
    provider = Ask::Providers::Bedrock.new(region: "eu-west-1")
    assert_equal "eu-west-1", provider.api_base
  end

  def test_capabilities
    caps = Ask::Providers::Bedrock.capabilities
    assert caps[:chat]
    assert caps[:streaming]
    assert caps[:tool_calls]
    assert caps[:vision]
  end

  def test_embed_raises
    assert_raises(Ask::CapabilityNotSupported) { @provider.embed(["text"], model: "test") }
  end
end
