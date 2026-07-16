# frozen_string_literal: true

# Shared test methods for all provider tests.
# Inspired by LiteLLM's BaseLLMChatTest — enforces the contract
# that every Ask::Provider must satisfy.
#
# Include this module in your provider test class and define:
#   provider_class   — the Ask::Provider subclass under test
#   provider_config  — hash of config options for instantiation
#   test_model       — model ID to use in request/response tests
module BaseProviderTests
  def setup
    super
    @provider = provider_class.new(provider_config)
  end

  # --- Provider interface contract ---

  def test_responds_to_chat
    assert_respond_to @provider, :chat
  end

  def test_responds_to_embed
    assert_respond_to @provider, :embed
  end

  def test_responds_to_list_models
    assert_respond_to @provider, :list_models
  end

  def test_responds_to_api_base
    assert_respond_to @provider, :api_base
  end

  def test_responds_to_headers
    assert_respond_to @provider, :headers
  end

  def test_responds_to_parse_error
    assert_respond_to @provider, :parse_error
  end

  # --- Slug / identity ---

  def test_has_slug
    refute_nil provider_class.slug, "#{provider_class} slug is nil"
    refute_empty provider_class.slug, "#{provider_class} slug is empty"
    assert_kind_of String, provider_class.slug
  end

  def test_slug_is_lowercase
    assert_match(/\A[a-z0-9_]+\z/, provider_class.slug,
                 "#{provider_class} slug '#{provider_class.slug}' should be lowercase with no spaces")
  end

  # --- Capabilities ---

  def test_has_capabilities
    caps = provider_class.capabilities
    refute_nil caps, "#{provider_class} has nil capabilities"
    assert caps.is_a?(Hash), "#{provider_class} capabilities should be a Hash"
  end

  def test_capabilities_include_chat
    assert provider_class.capabilities[:chat],
           "#{provider_class} must support chat"
  end

  # --- Configuration ---

  def test_configuration_options_defined
    opts = provider_class.configuration_options
    assert_kind_of Array, opts
  end

  def test_configuration_requirements_defined
    reqs = provider_class.configuration_requirements
    assert_kind_of Array, reqs
  end

  # --- Config transformation contract (public methods) ---

  def test_responds_to_build_request
    assert_respond_to @provider, :build_request
  end

  def test_responds_to_parse_response
    assert_respond_to @provider, :parse_response
  end

  def test_build_request_returns_hash
    result = @provider.build_request([{ role: "user", content: "Hello" }],
                                     model: test_model)
    assert_kind_of Hash, result
  end

  def test_build_request_includes_model
    result = @provider.build_request([{ role: "user", content: "Hello" }],
                                     model: test_model)
    assert result.to_s.include?(test_model.to_s),
           "#{provider_class} build_request model reference not found in payload"
  end

  def test_build_request_includes_messages
    result = @provider.build_request([{ role: "user", content: "Hello" }],
                                     model: test_model)

    messages = find_messages_in_payload(result)
    refute_nil messages, "#{provider_class} build_request should include messages in the payload"
    assert_equal 1, messages.length if messages
  end

  def test_build_request_includes_temperature_when_given
    result = @provider.build_request([{ role: "user", content: "Hello" }],
                                     model: test_model, temperature: 0.7)
    assert_includes result.to_s, "0.7"
  end

  def test_build_request_includes_stream_flag
    result = @provider.build_request([{ role: "user", content: "Hello" }],
                                     model: test_model, stream: true)
    assert_includes result.to_s, "true"
  end

  def test_build_request_accepts_tools
    skip "#{provider_class} does not advertise tool_calls support" unless provider_class.capabilities[:tool_calls]

    tools = [{ name: "get_weather",
               description: "Get current weather",
               parameters: { type: "object", properties: { location: { type: "string" } } } }]
    result = @provider.build_request([{ role: "user", content: "Hi" }],
                                     model: test_model, tools:)
    assert_includes result.to_s, "get_weather"
  end

  # --- Error mapping ---

  def test_map_error_rate_limit
    error = Ask::LLM::HTTP.map_error(429,
                                      { "error" => { "message" => "Too fast" } },
                                      provider: provider_class.slug)
    assert error.is_a?(Ask::RateLimitError),
           "429 should map to RateLimitError, got #{error.class}"
  end

  def test_map_error_auth
    error = Ask::LLM::HTTP.map_error(401,
                                      { "error" => { "message" => "Invalid key" } },
                                      provider: provider_class.slug)
    assert error.is_a?(Ask::Unauthorized),
           "401 should map to Unauthorized, got #{error.class}"
  end

  def test_map_error_server
    error = Ask::LLM::HTTP.map_error(500,
                                      { "error" => { "message" => "Server error" } },
                                      provider: provider_class.slug)
    assert error.is_a?(Ask::ServerError),
           "500 should map to ServerError, got #{error.class}"
  end

  def test_map_context_length_exceeded
    error = Ask::LLM::HTTP.map_error(400,
                                      { "error" => { "code" => "context_length_exceeded",
                                                     "message" => "Too long" } },
                                      provider: provider_class.slug)
    assert error.is_a?(Ask::ContextLengthExceeded),
           "context_length_exceeded should map to ContextLengthExceeded, got #{error.class}"
  end

  private

  def provider_class
    raise NotImplementedError, "#{self.class} must define provider_class"
  end

  def provider_config
    raise NotImplementedError, "#{self.class} must define provider_config"
  end

  def test_model
    raise NotImplementedError, "#{self.class} must define test_model"
  end

  def find_messages_in_payload(payload)
    return nil unless payload.is_a?(Hash)

    [:messages, "messages", :contents, "contents", :message, "message"].each do |key|
      return payload[key] if payload[key].is_a?(Array)
    end

    payload.each_value do |v|
      next unless v.is_a?(Hash)
      result = find_messages_in_payload(v)
      return result if result
    end
    nil
  end
end
