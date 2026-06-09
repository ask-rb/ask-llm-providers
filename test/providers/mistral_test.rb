# frozen_string_literal: true

require_relative "../test_helper"

class MistralProviderTest < Minitest::Test
  def setup
    @provider = Ask::Providers::Mistral.new(api_key: "test-key")
  end

  def test_api_base
    assert_equal "https://api.mistral.ai/v1", @provider.api_base
  end

  def test_headers
    h = @provider.headers
    assert_equal "Bearer test-key", h["Authorization"]
  end

  def test_capabilities
    caps = Ask::Providers::Mistral.capabilities
    assert caps[:chat]
    assert caps[:streaming]
    assert caps[:tool_calls]
    assert caps[:structured_output]
    assert caps[:embed]
  end
end
