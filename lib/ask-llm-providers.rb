# frozen_string_literal: true

require "ask"
require "ask-auth"
require "faraday"
require "faraday/multipart"
require "json"
require "base64"

# Common infrastructure
require_relative "ask/llm/config"
require_relative "ask/llm/http"
require_relative "ask/llm/sse_buffer"
require_relative "ask/llm/catalog"
require_relative "ask/llm/aliases"

# Provider transformation contract
require_relative "ask/llm/provider_config"

# Cost calculator
require_relative "ask/llm/cost_calculator"

# OpenAI-compatible provider registry (data, not classes)
require_relative "ask/llm/openai_compatible"

# Load providers
require_relative "ask/provider/openai"
require_relative "ask/provider/openai_compatible"
require_relative "ask/provider/anthropic"
require_relative "ask/provider/google"
require_relative "ask/provider/bedrock"
require_relative "ask/provider/ollama"
require_relative "ask/provider/mistral"
require_relative "ask/provider/cloudflare"
require_relative "ask/provider/openai_codex"

# Register canonical providers
Ask::Provider.register(:openai, Ask::Providers::OpenAI)
Ask::Provider.register(:anthropic, Ask::Providers::Anthropic)
Ask::Provider.register(:gemini, Ask::Providers::Google)
Ask::Provider.register(:bedrock, Ask::Providers::Bedrock)
Ask::Provider.register(:ollama, Ask::Providers::Ollama)
Ask::Provider.register(:mistral, Ask::Providers::Mistral)
Ask::Provider.register(:cloudflare, Ask::Providers::Cloudflare)
Ask::Provider.register(:openai_codex, Ask::Providers::OpenaiCodex)

# Register OpenAI-compatible providers from the registry (data → classes)
Ask::LLM::OPENAI_COMPATIBLE.each do |name, cfg|
  klass = Class.new(Ask::Providers::OpenAICompatible)
  klass.define_singleton_method(:compat_config) { cfg.merge(slug: name.to_s) }
  Ask::Provider.register(name, klass)
end

# Lazily load the bundled model catalog into Ask::ModelCatalog on first use.
# Like ruby_llm, the catalog is still synchronously available after require,
# but callers that never touch models pay no I/O until first access.
# Set ASK_LLM_LAZY_CATALOG=1 to opt into fully lazy loading (test helper uses this).
module Ask
  class ModelCatalog
    class << self
      alias_method :original_find_without_catalog, :find if method_defined?(:find)
      alias_method :original_all_without_catalog, :all if method_defined?(:all)
      alias_method :original_where_without_catalog, :where if method_defined?(:where)

      def find(*args, **kwargs, &block)
        Ask::LLM::Catalog.ensure_loaded!
        original_find_without_catalog(*args, **kwargs, &block)
      end

      def all(*args, **kwargs, &block)
        Ask::LLM::Catalog.ensure_loaded!
        original_all_without_catalog(*args, **kwargs, &block)
      end

      def where(*args, **kwargs, &block)
        Ask::LLM::Catalog.ensure_loaded!
        original_where_without_catalog(*args, **kwargs, &block)
      end
    end

    alias_method :original_instance_all, :all if method_defined?(:all)
    alias_method :original_instance_length, :length if method_defined?(:length)
    alias_method :original_instance_each, :each if method_defined?(:each)

    def all(*args, **kwargs, &block)
      Ask::LLM::Catalog.ensure_loaded!
      original_instance_all(*args, **kwargs, &block)
    end

    def length(*args, **kwargs, &block)
      Ask::LLM::Catalog.ensure_loaded!
      original_instance_length(*args, **kwargs, &block)
    end
    alias size length

    def each(*args, **kwargs, &block)
      Ask::LLM::Catalog.ensure_loaded!
      original_instance_each(*args, **kwargs, &block)
    end
  end
end

# Eager-load once to preserve existing behaviour for apps that expect the
# catalog immediately after require (avoids a de-facto breaking change).
# Set ASK_LLM_LAZY_CATALOG=1 to opt into fully lazy loading.
unless ENV["ASK_LLM_LAZY_CATALOG"] == "1"
  Ask::LLM::Catalog.load!
end
