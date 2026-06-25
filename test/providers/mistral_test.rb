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

  def test_configuration_requirements
    assert_includes Ask::Providers::Mistral.configuration_requirements, :api_key
  end

  def test_slug
    assert_equal "mistral", Ask::Providers::Mistral.slug
  end

  def test_parse_error
    error_response = Object.new
    def error_response.body; { "error" => { "message" => "Rate limit exceeded", "type" => "rate_limit_error" } }; end
    error = @provider.parse_error(error_response)
    assert_includes error, "Rate limit"
  end

  def test_parse_error_without_body
    error_response = Object.new
    def error_response.body; nil; end
    assert_nil @provider.parse_error(error_response)
  end

  def test_configuration_options
    opts = Ask::Providers::Mistral.configuration_options
    assert_includes opts, :api_key
    assert_includes opts, :api_base
  end

  def test_responds_to_chat
    assert_respond_to @provider, :chat
  end

  def test_responds_to_embed
    assert_respond_to @provider, :embed
  end

  def test_responds_to_list_models
    assert_respond_to @provider, :list_models
  end
end
