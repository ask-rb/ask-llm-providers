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

# Load providers
require_relative "ask/provider/openai"
require_relative "ask/provider/anthropic"
require_relative "ask/provider/google"
require_relative "ask/provider/bedrock"
require_relative "ask/provider/ollama"
require_relative "ask/provider/mistral"
require_relative "ask/provider/cloudflare"

# Register providers with the Ask::Provider registry
Ask::Provider.register(:openai, Ask::Providers::OpenAI)
Ask::Provider.register(:anthropic, Ask::Providers::Anthropic)
Ask::Provider.register(:gemini, Ask::Providers::Google)
Ask::Provider.register(:bedrock, Ask::Providers::Bedrock)
Ask::Provider.register(:ollama, Ask::Providers::Ollama)
Ask::Provider.register(:mistral, Ask::Providers::Mistral)
Ask::Provider.register(:cloudflare, Ask::Providers::Cloudflare)
