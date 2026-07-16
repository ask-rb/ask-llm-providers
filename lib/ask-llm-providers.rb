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

# Register canonical providers
Ask::Provider.register(:openai, Ask::Providers::OpenAI)
Ask::Provider.register(:anthropic, Ask::Providers::Anthropic)
Ask::Provider.register(:gemini, Ask::Providers::Google)
Ask::Provider.register(:bedrock, Ask::Providers::Bedrock)
Ask::Provider.register(:ollama, Ask::Providers::Ollama)
Ask::Provider.register(:mistral, Ask::Providers::Mistral)
Ask::Provider.register(:cloudflare, Ask::Providers::Cloudflare)

# Register OpenAI-compatible providers from the registry (data → classes)
Ask::LLM::OPENAI_COMPATIBLE.each do |name, cfg|
  klass = Class.new(Ask::Providers::OpenAICompatible)
  klass.define_singleton_method(:compat_config) { cfg.merge(slug: name.to_s) }
  Ask::Provider.register(name, klass)
end

# Load bundled model catalog into Ask::ModelCatalog
Ask::LLM::Catalog.load!
