# frozen_string_literal: true

require_relative "test_helper"

class ProvidersTest < Minitest::Test
  def test_all_providers_are_registered
    assert_equal 12, Ask::Provider.providers.size
    assert Ask::Provider.providers.key?(:openai)
    assert Ask::Provider.providers.key?(:anthropic)
    assert Ask::Provider.providers.key?(:gemini)
    assert Ask::Provider.providers.key?(:bedrock)
    assert Ask::Provider.providers.key?(:ollama)
    assert Ask::Provider.providers.key?(:mistral)
    assert Ask::Provider.providers.key?(:cloudflare)
  end

  def test_each_provider_has_capabilities
    Ask::Provider.providers.each_value do |klass|
      refute_empty klass.capabilities, "#{klass} has no capabilities"
    end
  end

  def test_each_provider_has_slug
    Ask::Provider.providers.each_value do |klass|
      refute_nil klass.slug, "#{klass} slug is nil"
      refute_empty klass.slug, "#{klass} slug is empty"
    end
  end

  def test_each_provider_can_instantiate
    Ask::Provider.providers.each do |name, klass|
      provider = klass.configuration_requirements.any? ? klass.new({ api_key: "test", account_id: "test", base_url: "http://localhost" }) : klass.new({})
      assert provider.is_a?(Ask::Provider), "#{name} is not a Provider"
      assert provider.respond_to?(:chat), "#{name} missing #chat"
    end
  end

  def test_openai_requires_api_key
    assert_includes Ask::Providers::OpenAI.configuration_requirements, :api_key
  end

  def test_openai_slug
    assert_equal "openai", Ask::Providers::OpenAI.slug
  end

  def test_provider_resolution
    assert_equal Ask::Providers::OpenAI, Ask::Provider.resolve(:openai)
    assert_equal Ask::Providers::Anthropic, Ask::Provider.resolve(:anthropic)
  end

  def test_unknown_provider_raises
    assert_raises(Ask::UnknownProvider) { Ask::Provider.resolve(:nonexistent) }
  end

  def test_provider_base_urls
    assert_equal "https://api.openai.com/v1", Ask::Providers::OpenAI.new(api_key: "t").api_base
    assert_equal "https://api.anthropic.com", Ask::Providers::Anthropic.new(api_key: "t").api_base
    assert_equal "https://generativelanguage.googleapis.com/v1beta", Ask::Providers::Google.new(api_key: "t").api_base
  end

  def test_capabilities_introspection
    caps = Ask::Providers::OpenAI.capabilities
    assert caps[:chat]
    assert caps[:streaming]
    assert caps[:tool_calls]
    assert caps[:vision]

    ollama_caps = Ask::Providers::Ollama.capabilities
    assert ollama_caps[:local]
  end

  def test_ollama_local_flag
    assert Ask::Providers::Ollama.local?
    refute Ask::Providers::OpenAI.local?
  end
end

  def test_deepseek_is_registered
    assert Ask::Provider.providers.key?(:deepseek)
    assert_equal Ask::Providers::DeepSeek, Ask::Provider.resolve(:deepseek)
    assert_equal "deepseek", Ask::Providers::DeepSeek.slug
  end

  def test_deepseek_base_url
    assert_equal "https://api.deepseek.com", Ask::Providers::DeepSeek.new(api_key: "t").api_base
  end

  def test_deepseek_requires_api_key
    assert_includes Ask::Providers::DeepSeek.configuration_requirements, :api_key
  end

  def test_deepseek_inherits_openai_capabilities
    caps = Ask::Providers::DeepSeek.capabilities
    assert caps[:chat]
    assert caps[:streaming]
    assert caps[:tool_calls]
  end
