# ask-llm-providers

All LLM providers for the ask-rb ecosystem in one gem. Implements the
`Ask::Provider` interface from `ask-core` with a capabilities-based interface:
7 canonical provider classes plus 26 OpenAI-compatible registry entries,
a bundled model catalog, and cost calculation. Providers auto-register and
the model catalog auto-loads when the gem is required.

## Installation

```ruby
gem "ask-llm-providers"
```

## Quick Start

```ruby
require "ask-llm-providers"

# Use a provider directly; streaming yields chunks to the block
provider = Ask::Providers::OpenAI.new
provider.chat([{ role: "user", content: "Tell me a story" }], model: "gpt-4o") do |chunk|
  print chunk.content
end

# Look up model metadata (capabilities, pricing, context window)
model = Ask::ModelCatalog.find("gpt-4o")
model.capabilities # => ["chat", "streaming", "tool_calls", ...]
```

## Supported Providers

| Provider | Auth |
|---|---|
| OpenAI | `Ask::Auth.resolve(:openai_api_key)` (env `OPENAI_API_KEY`) |
| Anthropic (Claude) | `Ask::Auth.resolve(:anthropic_api_key)` (env `ANTHROPIC_API_KEY`) |
| Google Gemini | `Ask::Auth.resolve(:gemini_api_key)` (env `GEMINI_API_KEY`); Vertex AI via GCP service account |
| Amazon Bedrock | AWS credentials chain (env, `~/.aws`, instance profile) |
| Ollama (local) | none needed |
| Mistral AI | `Ask::Auth.resolve(:mistral_api_key)` (env `MISTRAL_API_KEY`) |
| Cloudflare Workers AI | `Ask::Auth.resolve(:cloudflare_api_key)` (env `CLOUDFLARE_API_KEY`) |
| 26 OpenAI-compatible | per-provider `*_API_KEY` env var (e.g. `DEEPSEEK_API_KEY`, `GROQ_API_KEY`, `OPENROUTER_API_KEY`) |

Credentials resolve through `Ask::Auth` in order: environment variables,
`~/.ask/credentials.yml`, Rails credentials, then database and OAuth
providers. Keys are read via `Ask::Auth.resolve(:<name>_api_key)`.

The 26 OpenAI-compatible entries are registered from
`Ask::LLM::OPENAI_COMPATIBLE`: DeepSeek, Groq, Together, Fireworks, Cerebras,
xAI, Perplexity, DeepInfra, Anyscale, SambaNova, Nebius, Nvidia NIM, Friendli,
Hyperbolic, Novita, Nscale, Featherless, AI/ML API, AI21, Meta, GitHub Models,
OpenRouter, OpenCode, OpenCode Go, Mimo, and Moonshot. Each uses its own
`*_API_KEY` env var; note that `opencode_go` uses `OPENCODE_GO_API_KEY` (its
own key, not `OPENCODE_API_KEY`).

## Model Catalog

The gem bundles model metadata (capabilities, pricing, context windows,
modalities) as JSON for 12 providers: openai, anthropic, gemini, vertex_ai,
bedrock, deepseek, mistral, perplexity, xai, meta, moonshot, and nvidia_nim,
with 400+ models in total.

```ruby
Ask::ModelCatalog.find("claude-sonnet-4-5") # => Ask::ModelInfo
Ask::ModelCatalog.chat_models               # => filtered catalog
Ask::ModelCatalog.by_provider(:gemini)
Ask::ModelCatalog.refresh!                  # fetch latest from models.dev
```

## Entry Points

| API | Purpose |
|---|---|
| `Ask::Providers::OpenAI/Anthropic/Google/Bedrock/Ollama/Mistral/Cloudflare` | Canonical provider classes |
| `Ask::LLM::OPENAI_COMPATIBLE` | Registry data for the 26 compatible providers |
| `Ask::LLM::Catalog.load!` / `refresh!` | Load bundled + user model data into `Ask::ModelCatalog` |
| `Ask::LLM::Aliases.resolve("claude-sonnet-4")` | Short-name to canonical model ID resolution |
| `Ask::LLM::CostCalculator.calculate(model, input_tokens:, output_tokens:)` | USD cost from model pricing |
| `Ask::Provider.resolve(:openai)` | Class lookup by registered slug |

Providers accept a `base_url` override, so any OpenAI-compatible endpoint can
be used through `Ask::Providers::OpenAI` or `Ask::Providers::OpenAICompatible`.

## Full documentation

The full ask-rb documentation lives at https://ask-rb.github.io/ask-docs.
https://ask-rb.github.io/ask-docs/core/providers covers ask-llm-providers in
depth, including capabilities, streaming, tool calls, and error handling.
API reference: https://ask-rb.github.io/ask-docs/reference/api.

## Development

bundle install
bundle exec rake test

## License

MIT
