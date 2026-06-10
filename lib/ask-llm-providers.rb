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
require_relative "ask/llm/models/openai"

# Load providers
require_relative "ask/provider/openai"
require_relative "ask/provider/anthropic"
require_relative "ask/provider/google"
require_relative "ask/provider/bedrock"
require_relative "ask/provider/ollama"
require_relative "ask/provider/mistral"
require_relative "ask/provider/cloudflare"
require_relative "ask/provider/opencode"
require_relative "ask/provider/opencode_go"
require_relative "ask/provider/mimo"

# Register providers with the Ask::Provider registry
Ask::Provider.register(:openai, Ask::Providers::OpenAI)
Ask::Provider.register(:anthropic, Ask::Providers::Anthropic)
Ask::Provider.register(:gemini, Ask::Providers::Google)
Ask::Provider.register(:bedrock, Ask::Providers::Bedrock)
Ask::Provider.register(:ollama, Ask::Providers::Ollama)
Ask::Provider.register(:mistral, Ask::Providers::Mistral)
Ask::Provider.register(:cloudflare, Ask::Providers::Cloudflare)


# Register known models for each provider in the catalog
[
  [Ask::Providers::OpenAI, Ask::LLM::Models::OPENAI_MODELS],
  [Ask::Providers::Anthropic, Ask::LLM::Models::ANTHROPIC_MODELS],
  [Ask::Providers::Google, Ask::LLM::Models::GOOGLE_MODELS],
  [Ask::Providers::Mistral, Ask::LLM::Models::MISTRAL_MODELS],
  [Ask::Providers::Ollama, Ask::LLM::Models::OLLAMA_MODELS]
].each do |provider, models|
  models.each do |m|
    Ask::ModelCatalog.instance.register(Ask::ModelInfo.new(
      id: m[:id], provider: provider.slug, family: m[:family],
      capabilities: m[:capabilities],
      context_window: m[:context], max_output_tokens: m[:output]
    ))
  end
end

# configured via environment variables:

