# ask-llm-providers

All LLM providers for the ask-rb ecosystem in one gem. Implements `Ask::Provider`
from `ask-core` with a capabilities-based interface.

## Supported Providers

| Provider | Auth | Implementation |
|---|---|---|
| **OpenAI** + all OpenAI-compatible | `Ask::Auth.resolve(:openai_api_key)` | `Ask::Provider::OpenAI` |
| **Anthropic** (Claude) | `Ask::Auth.resolve(:anthropic_api_key)` | `Ask::Provider::Anthropic` |
| **Google Gemini** | `Ask::Auth.resolve(:gemini_api_key)` | `Ask::Provider::Google` |
| **Vertex AI** | GCP service account | `Ask::Provider::VertexAI` |
| **Amazon Bedrock** | AWS credentials chain | `Ask::Provider::Bedrock` |
| **Ollama** (local) | None needed | `Ask::Provider::Ollama` |
| **Mistral AI** | `Ask::Auth.resolve(:mistral_api_key)` | `Ask::Provider::Mistral` |
| **Cloudflare Workers AI** | `Ask::Auth.resolve(:cloudflare_api_key)` | `Ask::Provider::Cloudflare` |

## Installation

```ruby
gem "ask-llm-providers"
```

## Usage

```ruby
require "ask-llm-providers"

# All providers are auto-registered with Ask::Models
models = Ask::Models.find("gpt-4o")
# => { provider: :openai, capabilities: [...] }

# Use a provider directly
provider = Ask::Provider::OpenAI.new
provider.chat(conversation, tools: [], model: "gpt-4o") do |chunk|
  print chunk.content
end
```

## Capabilities

Each provider and model exposes its capabilities:

```ruby
provider = Ask::Provider::OpenAI.new
provider.capabilities
# => [:chat, :streaming, :tool_calls, :vision, :thinking,
#     :structured_output, :embed, :transcribe, :paint, :moderate]

model = Ask::Models.find("claude-sonnet-4-5")
model[:capabilities]
# => [:chat, :streaming, :tool_calls, :vision, :thinking, :prompt_caching]

# Unsupported capabilities raise a helpful error
provider = Ask::Provider::Anthropic.new
provider.embed(["text"], model: "claude-sonnet-4-5")
# => Ask::CapabilityNotSupported: Anthropic (claude-sonnet-4-5) does not support embeddings.
```

## Development

```bash
bin/setup
bundle exec rake test
```

## License

MIT
