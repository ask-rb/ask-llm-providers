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
require_relative "ask/provider/deepseek"
require_relative "ask/provider/openrouter"

# Register providers with the Ask::Provider registry
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
Ask::Provider.register(:openrouter, Ask::Providers::OpenRouter)

# Load bundled model catalog into Ask::ModelCatalog
Ask::LLM::Catalog.load!
