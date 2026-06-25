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

  def test_configuration_options
    opts = Ask::Providers::Bedrock.configuration_options
    assert_includes opts, :region
    assert_includes opts, :access_key_id
  end

  def test_configuration_requirements
    assert_empty Ask::Providers::Bedrock.configuration_requirements
  end

  def test_slug
    assert_equal "bedrock", Ask::Providers::Bedrock.slug
  end

  def test_parse_json
    result = @provider.__send__(:parse_json, '{"key": "value"}')
    assert_equal "value", result["key"]
  end

  def test_parse_json_malformed
    result = @provider.__send__(:parse_json, "not json")
    assert_kind_of Hash, result
  end

  def test_parse_error
    error_response = Object.new
    def error_response.body; { "message" => "Access denied" }; end
    error = @provider.parse_error(error_response)
    assert_includes error, "Access denied"
  end

  def test_parse_error_with_nil_body
    error_response = Object.new
    def error_response.body; nil; end
    assert_nil @provider.parse_error(error_response)
  end

  def test_format_bedrock_msg_user
    msg = @provider.__send__(:format_bedrock_msg, { role: "user", content: "Hello" })
    assert msg.key?(:role) || msg.key?("role")
  end

  def test_format_bedrock_msg_assistant
    msg = @provider.__send__(:format_bedrock_msg, { role: "assistant", content: "Hi" })
    assert_equal "assistant", msg[:role]
  end

  def test_list_models
    result = @provider.list_models
    assert_kind_of Array, result
  end

  def test_responds_to_chat
    assert_respond_to @provider, :chat
  end
end
