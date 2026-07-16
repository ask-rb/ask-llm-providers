# frozen_string_literal: true

require_relative "../test_helper"

class BedrockProviderTest < Minitest::Test
  include BaseProviderTests
  def provider_class
    Ask::Providers::Bedrock
  end

  def provider_config
    { region: "us-east-1" }
  end

  def test_model
    "anthropic.claude-sonnet-4-20250514"
  end

  # --- API base ---

  def test_api_base_is_region
    assert_equal "us-east-1", @provider.api_base
  end

  def test_custom_region
    provider = provider_class.new(region: "eu-west-1")
    assert_equal "eu-west-1", provider.api_base
  end

  # --- Capabilities ---

  def test_capabilities
    caps = provider_class.capabilities
    assert caps[:chat]; assert caps[:streaming]
    assert caps[:tool_calls]; assert caps[:vision]
  end

  def test_embed_raises
    assert_raises(Ask::CapabilityNotSupported) { @provider.embed(["text"], model: test_model) }
  end

  # --- Message formatting ---

  def test_format_message_user
    msg = @provider.format_message({ role: "user", content: "Hello" })
    assert_equal "user", msg[:role]
    assert msg[:content].is_a?(Array)
    assert msg[:content][0][:text]
  end

  def test_format_message_assistant
    msg = @provider.format_message({ role: "assistant", content: "Hi" })
    assert_equal "assistant", msg[:role]
  end

  def test_format_message_with_tool_calls
    msg = { role: :assistant, content: nil,
            tool_calls: [{ id: "call_1", function: { name: "get_weather", arguments: '{"loc":"NYC"}' } }] }
    formatted = @provider.format_message(msg)
    assert formatted[:content].any? { |p| p[:toolUse] }
  end

  def test_format_message_with_tool_result
    msg = { role: :tool, content: "34°F", tool_call_id: "call_1" }
    formatted = @provider.format_message(msg)
    assert formatted[:content].any? { |p| p[:toolResult] }
    assert_equal "user", formatted[:role]
  end

  # --- Request building ---

  def test_build_request_includes_max_tokens
    payload = @provider.build_request([{ role: "user", content: "Hi" }], model: test_model)
    assert payload[:inferenceConfig]
  end

  def test_build_request_system_message
    payload = @provider.build_request(
      [{ role: "system", content: "Be helpful." }, { role: "user", content: "Hi" }],
      model: test_model
    )
    assert payload[:system]
    assert_equal "Be helpful.", payload[:system][0][:text]
  end

  # --- Tools formatting ---

  def test_format_tools
    tools = [{ name: "get_weather", description: "Get weather",
               parameters: { type: "object", properties: { location: { type: "string" } } } }]
    formatted = @provider.format_tools(tools)
    assert formatted[0][:toolSpec]
    assert_equal "get_weather", formatted[0][:toolSpec][:name]
  end

  # --- Parse error ---

  def test_parse_error
    response = Object.new
    def response.body; { "message" => "Access denied" }; end
    error = @provider.parse_error(response)
    assert_includes error, "Access denied"
  end

  def test_parse_error_nil_body
    response = Object.new
    def response.body; nil; end
    assert_nil @provider.parse_error(response)
  end

  # --- Config requirements ---

  def test_no_required_config
    assert_empty provider_class.configuration_requirements
  end

  # --- Override base tests ---

  def test_build_request_includes_model
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model)
    assert_equal test_model, result[:modelId]
  end

  def test_build_request_includes_stream_flag
    # Bedrock doesn't use a stream flag in payload
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model, stream: true)
    refute result.key?(:stream)
  end

  def test_build_request_includes_temperature_when_given
    result = @provider.build_request([{ role: "user", content: "Hello" }],
                                     model: test_model, temperature: 0.7)
    assert_equal 0.7, result.dig(:inferenceConfig, :temperature)
  end
end
