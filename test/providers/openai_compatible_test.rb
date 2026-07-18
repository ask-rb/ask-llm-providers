# frozen_string_literal: true

require_relative "../test_helper"

class OpenAICompatibleTest < Minitest::Test
  # Auto-build REGISTERED from the registry — adding a provider to
  # OPENAI_COMPATIBLE automatically gets tested here.
  REGISTERED = Ask::LLM::OPENAI_COMPATIBLE.transform_values { |cfg| cfg[:api_base] }.freeze

  def setup
    @deepseek = provider(:deepseek)
    @openrouter = provider(:openrouter)
    @opencode = provider(:opencode)
  end

  # --- Dynamically generate per-provider tests ---

  REGISTERED.each do |name, api_base|
    define_method :"test_#{name}_is_registered" do
      klass = Ask::Provider.resolve(name)
      assert klass < Ask::Providers::OpenAICompatible,
             "#{name} should be an OpenAICompatible subclass"
    end

    define_method :"test_#{name}_slug" do
      klass = Ask::Provider.resolve(name)
      assert_equal name.to_s, klass.slug
    end

    define_method :"test_#{name}_has_capabilities" do
      klass = Ask::Provider.resolve(name)
      caps = klass.capabilities
      assert caps[:chat], "#{name} must support chat"
    end

    define_method :"test_#{name}_api_base" do
      klass = Ask::Provider.resolve(name)
      assert_equal api_base, klass.new(api_key: "test").api_base
    end

    define_method :"test_#{name}_requires_api_key" do
      klass = Ask::Provider.resolve(name)
      assert_includes klass.configuration_requirements, :api_key
    end
  end

  # --- Per-provider quirks ---

  def test_deepseek_api_key_from_env
    cfg = Ask::LLM::OPENAI_COMPATIBLE[:deepseek]
    with_env(cfg[:api_key_env], "env-key-deepseek") do
      klass = Ask::Provider.resolve(:deepseek)
      provider = klass.new({})
      assert_equal "env-key-deepseek", provider.config.api_key
    end
  end

  def test_github_api_key_from_env
    cfg = Ask::LLM::OPENAI_COMPATIBLE[:github]
    with_env(cfg[:api_key_env], "env-key-github") do
      klass = Ask::Provider.resolve(:github)
      provider = klass.new({})
      assert_equal "env-key-github", provider.config.api_key
    end
  end

  def test_openrouter_extra_headers
    h = @openrouter.headers
    assert h.key?("HTTP-Referer"), "OpenRouter should set HTTP-Referer"
    assert h.key?("X-Title"), "OpenRouter should set X-Title"
  end

  def test_opencode_go_uses_opencode_api_key
    cfg = Ask::LLM::OPENAI_COMPATIBLE[:opencode_go]
    assert_equal "OPENCODE_API_KEY", cfg[:api_key_env]
  end

  def test_opencode_go_api_key_from_env_with_config_object
    with_env("OPENCODE_API_KEY", "env-key-from-config-object") do
      klass = Ask::Provider.resolve(:opencode_go)
      config = Ask::LLM::Config.new({})
      provider = klass.new(config)
      assert_equal "env-key-from-config-object", provider.config.api_key
    end
  end

  def test_opencode_go_api_key_from_slug_env_with_config_object
    with_env("OPENCODE_GO_API_KEY", "slug-env-key") do
      klass = Ask::Provider.resolve(:opencode_go)
      config = Ask::LLM::Config.new({})
      provider = klass.new(config)
      assert_equal "slug-env-key", provider.config.api_key
    end
  end

  def test_opencode_go_api_key_from_config_object_explicit
    config = Ask::LLM::Config.new({ api_key: "explicit-from-config" })
    klass = Ask::Provider.resolve(:opencode_go)
    provider = klass.new(config)
    assert_equal "explicit-from-config", provider.config.api_key
  end

  def test_opencode_go_api_key_from_env
    with_env("OPENCODE_API_KEY", "env-key") do
      klass = Ask::Provider.resolve(:opencode_go)
      provider = klass.new({})
      assert_equal "env-key", provider.config.api_key
    end
  end

  def test_opencode_go_api_key_from_auth_resolve_fallback
    Ask::Auth.stubs(:resolve).returns("auth-resolved-key")
    klass = Ask::Provider.resolve(:opencode_go)
    provider = klass.new({})
    assert_equal "auth-resolved-key", provider.config.api_key
  ensure
    Ask::Auth.unstub(:resolve)
  end

  def test_opencode_go_api_key_auth_resolve_does_not_override_explicit
    Ask::Auth.stubs(:resolve).returns("should-not-be-used")
    klass = Ask::Provider.resolve(:opencode_go)
    provider = klass.new({ api_key: "explicit-key" })
    assert_equal "explicit-key", provider.config.api_key
  ensure
    Ask::Auth.unstub(:resolve)
  end

  def test_deepseek_reasoning_content
    msgs = [{ role: :assistant, content: nil,
              tool_calls: [{ id: "call_1", function: { name: "f", arguments: "{}" } }] }]
    formatted = @deepseek.format_messages(msgs)
    assert formatted.first.key?(:reasoning_content),
           "DeepSeek should inject reasoning_content for tool call messages"
  end

  # --- All share the same wire format ---

  def test_all_build_request_standard_format
    REGISTERED.each_key do |name|
      klass = Ask::Provider.resolve(name)
      provider = klass.new(api_key: "test")
      payload = provider.build_request([{ role: "user", content: "Hi" }], model: "gpt-4o")
      assert_equal "gpt-4o", payload[:model], "#{name} model key"
      assert payload[:messages].is_a?(Array), "#{name} messages"
    end
  end

  def test_all_build_request_with_tools
    REGISTERED.each_key do |name|
      klass = Ask::Provider.resolve(name)
      provider = klass.new(api_key: "test")
      tools = [{ name: "get_weather", description: "Get weather",
                 parameters: { type: "object", properties: { loc: { type: "string" } } } }]
      payload = provider.build_request([{ role: "user", content: "Hi" }], model: "gpt-4o", tools:)
      assert payload[:tools], "#{name} should include tools"
    end
  end

  def test_all_parse_response_standard_format
    body = { "id" => "cmpl-123", "model" => "gpt-4o",
             "choices" => [{ "index" => 0, "message" => { "role" => "assistant", "content" => "Hello" },
                              "finish_reason" => "stop" }],
             "usage" => { "prompt_tokens" => 10, "completion_tokens" => 20 } }
    REGISTERED.each_key do |name|
      klass = Ask::Provider.resolve(name)
      provider = klass.new(api_key: "test")
      msg = provider.parse_response(body, "gpt-4o")
      assert_equal :assistant, msg.role, "#{name} role"
      assert_equal "Hello", msg.content, "#{name} content"
    end
  end

  def test_all_parse_stream_standard_format
    data = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"}}]}\n\n"
    REGISTERED.each_key do |name|
      klass = Ask::Provider.resolve(name)
      provider = klass.new(api_key: "test")
      stream = Ask::Stream.new
      provider.parse_stream(data, stream, "gpt-4o")
      assert_equal 1, stream.length, "#{name} stream length"
      assert_equal "Hello", stream.chunks.first.content, "#{name} stream content"
    end
  end

  def test_all_format_tools
    tools = [{ name: "get_weather", description: "Get weather", parameters: { type: "object" } }]
    REGISTERED.each_key do |name|
      klass = Ask::Provider.resolve(name)
      provider = klass.new(api_key: "test")
      formatted = provider.format_tools(tools)
      assert_equal "function", formatted[0][:type], "#{name} tool type"
      assert_equal "get_weather", formatted[0][:function][:name], "#{name} tool name"
    end
  end

  # --- Edge cases ---

  def test_unknown_env_falls_back_to_configured_key
    klass = Ask::Provider.resolve(:opencode)
    provider = klass.new(api_key: "explicit-key")
    assert_equal "explicit-key", provider.config.api_key
  end

  def test_base_url_override
    klass = Ask::Provider.resolve(:deepseek)
    provider = klass.new(api_key: "test", base_url: "http://localhost:8000")
    assert_equal "http://localhost:8000", provider.api_base
  end

  def test_configuration_options
    klass = Ask::Provider.resolve(:deepseek)
    assert_includes klass.configuration_options, :api_key
    assert_includes klass.configuration_options, :base_url
  end

  def test_all_registered_providers_match_registry
    REGISTERED.each_key { |name| assert Ask::Provider.providers.key?(name), "#{name} should be registered" }
    assert_equal REGISTERED.size, Ask::LLM::OPENAI_COMPATIBLE.size
  end

  private

  def provider(name)
    klass = Ask::Provider.resolve(name)
    klass.new(api_key: "test")
  end

  def with_env(key, value)
    old = ENV[key.to_s]
    ENV[key.to_s] = value
    yield
  ensure
    ENV[key.to_s] = old
  end
end
