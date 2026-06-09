# ask-llm-providers

All LLM providers for the ask-rb ecosystem in one gem. Implements `Ask::Provider`
from `ask-core` with a capabilities-based interface.

## Supported Providers

| Provider | Auth | Implementation |
|---|---|---|
| **OpenAI** + all OpenAI-compatible | `Ask::Auth.resolve(:openai_api_key)` | `Ask::Providers::OpenAI` |
| **Anthropic** (Claude) | `Ask::Auth.resolve(:anthropic_api_key)` | `Ask::Providers::Anthropic` |
| **Google Gemini** | `Ask::Auth.resolve(:gemini_api_key)` | `Ask::Providers::Google` |
| **Vertex AI** | GCP service account | `Ask::Providers::Google` (via Vertex) |
| **Amazon Bedrock** | AWS credentials chain | `Ask::Providers::Bedrock` |
| **Ollama** (local) | None needed | `Ask::Providers::Ollama` |
| **Mistral AI** | `Ask::Auth.resolve(:mistral_api_key)` | `Ask::Providers::Mistral` |
| **Cloudflare Workers AI** | `Ask::Auth.resolve(:cloudflare_api_key)` | `Ask::Providers::Cloudflare` |

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
provider = Ask::Providers::OpenAI.new
provider.chat(conversation, tools: [], model: "gpt-4o") do |chunk|
  print chunk.content
end
```

## Capabilities

Each provider and model exposes its capabilities:

```ruby
provider = Ask::Providers::OpenAI.new
provider.capabilities
# => { chat: true, streaming: true, tool_calls: true, vision: true, thinking: true,
#     :structured_output, :embed, :transcribe, :paint, :moderate]

model = Ask::Models.find("claude-sonnet-4-5")
model[:capabilities]
# => { chat: true, streaming: true, tool_calls: true, vision: true, thinking: true, :prompt_caching]

# Unsupported capabilities raise a helpful error
provider = Ask::Providers::Anthropic.new
provider.embed(["text"], model: "claude-sonnet-4-5")
# => Ask::CapabilityNotSupported: Anthropic (claude-sonnet-4-5) does not support embeddings.
```



## Streaming

```ruby
stream = provider.chat(
  [{ role: "user", content: "Tell me a story" }],
  model: "gpt-4o",
  stream: true
) do |chunk|
  print chunk.content
end

# After streaming completes, you can access the full response
puts stream.accumulated_text
puts stream.accumulated_usage
```

## Tool Calls

```ruby
tools = [{
  name: "get_weather",
  description: "Get weather for a location",
  parameters: {
    type: "object",
    properties: { location: { type: "string" } },
    required: ["location"]
  }
}]

response = provider.chat(
  [{ role: "user", content: "What's the weather in NYC?" }],
  model: "gpt-4o",
  tools: tools
)
# response.tool_call? => true
# response.tool_calls => [{ id: "call_1", name: "get_weather", arguments: '{"location":"NYC"}' }]
```

## Error Handling

Provider errors map to structured `Ask::Error` types:

```ruby
Ask::RateLimitError       # 429 — retry with backoff
Ask::Unauthorized         # 401/403 — check your API key
Ask::ServerError          # 500 — provider issue
Ask::ServiceUnavailable   # 503 — temporary
Ask::ContextLengthExceeded # context window exceeded
Ask::ProviderError        # other provider errors
Ask::CapabilityNotSupported # feature not available on this model
```

## Development

```bash
bin/setup
bundle exec rake test
```

## License

MIT
