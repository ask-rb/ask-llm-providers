# frozen_string_literal: true

require_relative "test_helper"

class ProvidersTest < Minitest::Test
  def test_all_providers_are_registered
    count = Ask::Provider.providers.size
    assert_operator count, :>=, 33, "Expected at least 33 providers, got #{count}"
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

  def test_openai_compatible_providers_are_registered
    Ask::LLM::OPENAI_COMPATIBLE.each_key do |name|
      assert Ask::Provider.providers.key?(name), "#{name} should be registered"
      klass = Ask::Provider.resolve(name)
      assert klass < Ask::Providers::OpenAICompatible, "#{name} should be an OpenAICompatible subclass"
      assert_equal name.to_s, klass.slug, "#{name} slug mismatch"
    end
  end

  def test_openai_compatible_base_urls
    Ask::LLM::OPENAI_COMPATIBLE.each do |name, cfg|
      klass = Ask::Provider.resolve(name)
      assert_equal cfg[:api_base], klass.new(api_key: "t").api_base, "#{name} api_base"
    end
  end

  def test_openai_compatible_requires_api_key
    Ask::LLM::OPENAI_COMPATIBLE.each_key do |name|
      klass = Ask::Provider.resolve(name)
      assert_includes klass.configuration_requirements, :api_key, "#{name}"
    end
  end

  def test_openai_compatible_has_capabilities
    Ask::LLM::OPENAI_COMPATIBLE.each do |name, cfg|
      klass = Ask::Provider.resolve(name)
      caps = klass.capabilities
      assert caps[:chat], "#{name} missing chat capability"
      assert_equal cfg[:capabilities], caps, "#{name} capabilities mismatch"
    end
  end
end
