# frozen_string_literal: true

require_relative "test_helper"

class ThreadSafetyTest < Minitest::Test
  def test_concurrent_provider_instantiation
    threads = 10.times.map do |i|
      Thread.new do
        provider = Ask::Providers::OpenAI.new(api_key: "test-#{i}")
        [provider.slug, provider.api_base]
      end
    end
    results = threads.map(&:value)
    assert_equal 10, results.length
    results.each { |slug, base| assert_equal "openai", slug }
  end

  def test_concurrent_provider_registration
    Ask::Provider.clear_providers!
    threads = 5.times.map do |i|
      Thread.new { Ask::Provider.register("test_prov_#{i}".to_sym, Ask::Providers::OpenAI) }
    end
    threads.each(&:join)
    assert_equal 5, Ask::Provider.providers.length
  ensure
  Ask::Provider.clear_providers!
  Ask::Provider.register(:openai, Ask::Providers::OpenAI)
  Ask::Provider.register(:anthropic, Ask::Providers::Anthropic)
  Ask::Provider.register(:gemini, Ask::Providers::Google)
  Ask::Provider.register(:bedrock, Ask::Providers::Bedrock)
  Ask::Provider.register(:ollama, Ask::Providers::Ollama)
  Ask::Provider.register(:mistral, Ask::Providers::Mistral)
  Ask::Provider.register(:cloudflare, Ask::Providers::Cloudflare)
  Ask::Provider.register(:opencode, Ask::Providers::OpenCode)
  Ask::Provider.register(:opencode_go, Ask::Providers::OpenCodeGo)
  Ask::Provider.register(:mimo, Ask::Providers::Mimo)
  Ask::Provider.register(:deepseek, Ask::Providers::DeepSeek)
end


  def test_concurrent_model_reads
    catalog = Ask::ModelCatalog.instance
    threads = 10.times.map do
      Thread.new { catalog.all.length }
    end
    results = threads.map(&:value)
    assert results.all? { |n| n > 0 }
  end

  def test_config_is_thread_safe
    config = Ask::LLM::Config.new(api_key: "test", base_url: "http://example.com")
    threads = 10.times.map do |i|
      Thread.new { assert_equal "test", config.api_key }
    end
    threads.each(&:join)
  end
end
