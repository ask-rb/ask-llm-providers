# ask-llm-providers — All LLM Providers

## Purpose

One gem containing every LLM provider: OpenAI (plus all OpenAI-compatible), Anthropic,
Google Gemini + Vertex, Amazon Bedrock, Ollama, Mistral AI, and Cloudflare Workers AI.
Implements `Ask::Provider` from `ask-core` with a capabilities-based interface.

**IMPORTANT:** This is Phase 3 of the migration. Do NOT build until `ask-core` is built,
tested, and released. The agent stack depends on `ruby_llm` until this gem exists.

## Dependencies

- **Runtime:** `ask-core` (Provider interface, conversation, streaming, model catalog),
  `ask-auth` (credential resolution), `faraday >= 2.0`
- **Build/test:** minitest, mocha, rake, vcr, webmock
- **This gem MUST wait until `ask-core` is built, tested, and released.**

## External Services We Reuse (Do Not Rebuild)

We are building a Ruby-agent framework, not a global model registry, not provider APIs,
not OAuth infrastructure. These services already exist and are proven in production.
We call them — we do not rebuild them.

---

### 1. Model Metadata: models.dev

- **URL:** https://models.dev/api.json
- **Used by:** RubyLLM (production, every request)
- **What it provides:** Model names, provider mapping, capabilities (function_calling,
  structured_output, reasoning, vision), modalities (text, image, audio, pdf, video),
  pricing (input/output tokens, cache read/write), context window sizes, rate limits.
- **Why we use it:** Without it we would need to maintain a static JSON file manually
  and update it every time a new model is released. models.dev is updated by the
  community and covers all major providers.
- **How we use it:** Ask::Models.fetch_on_refresh() calls this API, caches the result,
  merges with provider-registered models. See ruby_llm/lib/ruby_llm/models.rb:
  fetch_models_dev_models() for the reference implementation.
- **Fallback:** If models.dev is unreachable, we use the last cached response.
  If no cache exists, we fall back to models registered by installed providers.

---

### 2. Provider Chat APIs (implemented by ask-llm-providers)

These are the actual LLM endpoints. We implement HTTP clients for them, we do not
rebuild them. Each is documented in its specific provider implementation.

**OpenAI + Compatible Family** (Ask::Provider::OpenAI):
| Provider | Base URL |
|---|---|
| OpenAI | https://api.openai.com/v1 |
| OpenRouter | https://openrouter.ai/api/v1 |
| DeepSeek | https://api.deepseek.com |
| XAI / Grok | https://api.x.ai/v1 |
| Perplexity | https://api.perplexity.ai |
| Azure OpenAI | https://{resource}.openai.azure.com/openai/v1 |
| Cerebras | https://api.cerebras.ai/v1 |
| Fireworks | https://api.fireworks.ai/inference |
| Groq | https://api.groq.com/openai/v1 |
| Together | https://api.together.ai/v1 |
| Moonshot | https://api.moonshot.ai/v1 |

**Reference:** ruby_llm/lib/ruby_llm/providers/openai/ — Chat Completions + Responses API
  llm-proxy/lib/llm_proxy/protocols/ — protocol normalization
  pi/packages/ai/src/providers/openai-completions.ts — alternate implementations

**Anthropic** (Ask::Provider::Anthropic):
- Base URL: https://api.anthropic.com
- Endpoint: /v1/messages
- Reference: ruby_llm/lib/ruby_llm/providers/anthropic/

**Google Gemini** (Ask::Provider::Google):
- Base URL: https://generativelanguage.googleapis.com/v1beta
- Reference: ruby_llm/lib/ruby_llm/providers/gemini/

**Google Vertex AI** (Ask::Provider::VertexAI):
- Base URL: https://{location}-aiplatform.googleapis.com/v1beta1
- Reference: ruby_llm/lib/ruby_llm/providers/vertexai/
  pi/packages/ai/src/providers/google-vertex.ts

**AWS Bedrock** (Ask::Provider::Bedrock):
- Base URL: https://bedrock-runtime.{region}.amazonaws.com
- Reference: ruby_llm/lib/ruby_llm/providers/bedrock/
  pi/packages/ai/src/providers/amazon-bedrock.ts

**Mistral** (Ask::Provider::Mistral):
- Base URL: https://api.mistral.ai/v1
- Reference: ruby_llm/lib/ruby_llm/providers/mistral/

**Cloudflare Workers AI + AI Gateway** (Ask::Provider::Cloudflare):
- Workers AI: https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/v1
- AI Gateway (OpenAI compat): https://gateway.ai.cloudflare.com/v1/{ACCOUNT_ID}/{GATEWAY_ID}/openai
- AI Gateway (Anthropic compat): https://gateway.ai.cloudflare.com/v1/{ACCOUNT_ID}/{GATEWAY_ID}/anthropic
- Reference: pi/packages/ai/src/providers/cloudflare.ts (the canonical implementation)

**Ollama** (Ask::Provider::Ollama):
- Base URL: http://localhost:11434 (default, configurable)
- Reference: ruby_llm/lib/ruby_llm/providers/ollama/

### 3. OAuth Infrastructure

Used for multi-user auth flows. The endpoints are standard OAuth 2.0.

| Provider | Authorize URL | Token URL |
|---|---|---|
| OpenAI | https://auth.openai.com/oauth/authorize | https://auth.openai.com/oauth/token |
| Anthropic | https://claude.ai/oauth/authorize | https://platform.claude.com/v1/oauth/token |
| GitHub | https://github.com/login/oauth/authorize | https://github.com/login/oauth/access_token |
| Google | https://accounts.google.com/o/oauth2/v2/auth | https://oauth2.googleapis.com/token |

**How we use them:** Ask::Auth::OAuth reads these URLs from configuration, performs
the PKCE flow, and stores the result in the configured storage provider (env var,
file, or database). We do NOT implement OAuth infrastructure — we call the standard
endpoints.

**Reference:** pi/packages/ai/src/providers/simple-options.ts (OAuth config)
  pi/packages/ai/src/providers/github-copilot-headers.ts (Copilot OAuth)

### 4. GitHub Copilot API

- **Endpoints:**
  - Chat: https://api.individual.githubcopilot.com
  - Enterprise: https://copilot-api.{enterprise-domain}
  - Token: https://api.{domain}/copilot_internal/v2/token
- **Reference:** pi/packages/ai/src/providers/github-copilot-headers.ts
- **Not currently planned but documented for future.** GitHub Copilot uses a
  custom OAuth flow with device code grant. This could be added to ask-llm-providers
  as Ask::Provider::GitHubCopilot.

### 5. Vercel AI Gateway

- **URL:** https://ai-gateway.vercel.sh
- **Purpose:** Standardized access to multiple providers through one endpoint.
  Supports OpenAI, Anthropic, Google, and more with a unified API.
- **Reference:** pi/packages/ai/src/providers/images (uses Vercel for image generation)
- **How we use it:** Any OpenAI-compatible provider can use ask-openai with
  base_url: https://ai-gateway.vercel.sh/v1. No separate implementation needed.

### What We Do NOT Build (covered by existing services)

| What | Covered by |
|---|---|
| Model catalog / pricing database | models.dev API |
| Provider wire formats | Provider gems call these directly |
| OAuth infrastructure | Standard endpoints, Ask::Auth::OAuth |
| API routing / load balancing | OpenRouter, Vercel AI Gateway |
| Model registry / discovery | models.dev + provider list endpoints |
| Pricing calculation | models.dev provides per-model pricing |
| Rate limiting | Provider APIs do this natively |

### What We DO Build (unique to ask-rb)

| What | Where |
|---|---|
| Agent loop with extension system | ask-agent |
| Rails integration with AR persistence | ask-rails |
| Service context system (ask-github, etc.) | ask-* service gems |
| Credential resolution chain | ask-auth |
| Tool framework + execution tools | ask-tools, ask-tools-shell |
| Unified provider interface with capabilities | ask-core + ask-llm-providers |
| Agent-friendly error messages | every gem |
## External Services We Reuse (Do Not Rebuild)

### models.dev API

- **URL:** https://models.dev/api.json
- **Purpose:** Model metadata — names, capabilities, pricing, modalities
- **Integration:** Models from ask-llm-providers register with Ask::Models, which
  merges provider-registered models with models.dev data.
- **No manual JSON catalog needed.** Models.dev is the source of truth for pricing
  and capabilities. Our provider implementations just register which models they
  support, and models.dev fills in the details.

### Provider APIs

Each provider subsection below documents its specific API endpoint, auth method,
and streaming protocol. See the reference implementations in:
- ruby_llm/lib/ruby_llm/providers/ (for all provider wire formats)
- llm-proxy/lib/llm_proxy/protocols/ (for OpenAI/Anthropic protocol normalization)
- pi/packages/ai/src/providers/ (for Cloudflare, lazy loading patterns)

### What We Do NOT Build

- A provider framework — ask-core provides the interface, we implement it.
- Static model catalogs — models.dev handles that.
- Auth abstraction — ask-auth handles that.
- Streaming infrastructure — ask-core provides Ask::Stream.

### What We DO Build

- Wire format implementations — the raw HTTP calls, JSON serialization, SSE parsing.
- Provider-specific features — thinking blocks (Anthropic), structured output (OpenAI),
  file uploads (Google), model pulling (Ollama).
- Error mapping — provider errors → Ask::Error types.
- Model registration — register each provider's models with Ask::Models on load.


## Provided Providers

| Provider | Class | Models served |
|---|---|---|
| OpenAI + compatible | `Ask::Provider::OpenAI` | OpenAI, OpenRouter, DeepSeek, Azure, XAI, Perplexity, GPUStack |
| Anthropic | `Ask::Provider::Anthropic` | Claude 3/4 series |
| Google | `Ask::Provider::Google` | Gemini series |
| Vertex AI | `Ask::Provider::VertexAI` | Gemini via Vertex |
| Amazon Bedrock | `Ask::Provider::Bedrock` | Claude, Llama, Mistral via AWS |
| Ollama | `Ask::Provider::Ollama` | Any local model |
| Mistral | `Ask::Provider::Mistral` | Mistral series |
| Cloudflare | `Ask::Provider::Cloudflare` | Workers AI + AI Gateway |

## Capabilities-Based Interface Design

### The problem

Providers differ wildly. OpenAI does embeddings, Anthropic and Bedrock don't. Some do
vision, some don't. Models within the same provider differ (`gpt-4o` does audio,
`gpt-4o-mini` doesn't). A rigid interface forces every provider to stub every method.

### The solution

`Ask::Provider` (defined in `ask-core`) defines the FULL interface. Every provider
inherits from it. Optional capabilities raise `Ask::CapabilityNotSupported` by default.
Providers override only what they support.

```ruby
class Ask::Provider::OpenAI < Ask::Provider
  # REQUIRED — every provider must implement this
  def chat(conversation, tools: [], model:, &stream_block)
    # OpenAI implementation
  end

  # OPTIONAL — override only what this provider supports
  def embed(texts, model:)
    Ask::Result.ok(data: client.embeddings(...))
  end

  def paint(prompt, model:, size: "1024x1024")
    # DALL-E or GPT Image
  end

  def transcribe(audio_file, model:, language: nil)
    # Whisper
  end

  def moderate(input, model:)
    # Moderation endpoint
  end

  # Capability introspection
  def capabilities
    [:chat, :streaming, :tool_calls, :vision, :thinking,
     :structured_output, :embed, :transcribe, :paint, :moderate]
  end
end
```

Providers that don't support a capability:
```ruby
class Ask::Provider::Anthropic < Ask::Provider
  # Doesn't override embed, paint, transcribe, moderate
  # Those inherited methods raise Ask::CapabilityNotSupported

  def capabilities
    [:chat, :streaming, :tool_calls, :vision, :thinking, :prompt_caching]
  end
end
```

### Model-level capability granularity

Not every model in a provider supports everything. The model catalog (in `ask-core`)
carries per-model capabilities:

```ruby
Ask::Models.register("gpt-4o", provider: :openai, capabilities: [
  :chat, :streaming, :tool_calls, :vision, :structured_output, :embed
], modalities: [:text, :image, :audio])

Ask::Models.register("text-embedding-3-small", provider: :openai, capabilities: [
  :embed
], modalities: [:text])

Ask::Models.register("claude-sonnet-4-5", provider: :anthropic, capabilities: [
  :chat, :streaming, :tool_calls, :vision, :thinking, :prompt_caching
], modalities: [:text, :image])
```

### Model catalog registration

On gem load, every provider registers its models with the catalog:

```ruby
# In lib/ask-llm-providers.rb
Ask::Models.load(:openai, models: OPENAI_MODELS)
Ask::Models.load(:anthropic, models: ANTHROPIC_MODELS)
# ...
```

This keeps model data close to the provider implementation that knows it best.

### What the agent sees

When `ask-agent` builds the system prompt, it queries `Ask::Models` and
`Ask::Provider.capabilities` and generates:

```
Available providers:
  OpenAI (gpt-4o)
    Chat, streaming, tool calls, vision, embeddings, structured output, moderation
    Install: Set OPENAI_API_KEY
  Anthropic (claude-sonnet-4-5)
    Chat, streaming, tool calls, vision, thinking, prompt caching
    Does NOT support: embeddings, image generation, audio
    Install: Set ANTHROPIC_API_KEY

To use a capability not supported by the current model, try a different provider.
Example: provider.embed(texts, model:) with an OpenAI model that supports embeddings.
```

When the agent calls an unsupported capability:
```ruby
provider.transcribe("meeting.mp3", model: "claude-sonnet-4-5")
# => Ask::CapabilityNotSupported: Anthropic (claude-sonnet-4-5) does not
#    support transcription. Try ask-core's Ask::Auth.resolve(:openai_api_key)
#    with a provider that supports audio, e.g. OpenAI (gpt-4o-audio-preview).
```

## Implementation Steps

### 1. Define gem scaffold
- `lib/ask-llm-providers.rb` — entry point, requires all providers
- `lib/ask/llm/providers.rb` — registry, convenience methods
- `lib/ask/llm/version.rb`

### 2. Implement `Ask::Provider::OpenAI` (`lib/ask/providers/openai.rb`)
- Chat Completions API (`/v1/chat/completions`)
- Responses API (`/v1/responses`) — GPT-5.5+ style
- Streaming via SSE, tool calls, vision, structured output
- Embeddings, image generation (DALL-E / GPT Image), transcription (Whisper), moderation
- `base_url` override — supports OpenRouter, DeepSeek, Azure, XAI, Perplexity, GPUStack
- Auth via `Ask::Auth.resolve(:openai_api_key)`
- Study: `ruby_llm/lib/ruby_llm/providers/openai/`, `llm-proxy/lib/llm_proxy/protocols/`

### 3. Implement `Ask::Provider::Anthropic` (`lib/ask/providers/anthropic.rb`)
- Messages API (`/v1/messages`)
- Thinking blocks (extended thinking, thinking signatures)
- Prompt caching (cache_control, cache_read_* tokens)
- Tool use, vision, streaming
- Auth via `Ask::Auth.resolve(:anthropic_api_key)`
- Study: `ruby_llm/lib/ruby_llm/providers/anthropic/`

### 4. Implement `Ask::Provider::Google` and `Ask::Provider::VertexAI` (`lib/ask/providers/google.rb`)
- Gemini API (direct) — `generativelanguage.googleapis.com`
- Vertex AI — `google-apis-generator` or direct HTTP
- Function calling, safety settings, file uploads
- Auth via `Ask::Auth.resolve(:gemini_api_key)` or GCP service account
- Study: `ruby_llm/lib/ruby_llm/providers/gemini/`, `ruby_llm/lib/ruby_llm/providers/vertexai/`

### 5. Implement `Ask::Provider::Bedrock` (`lib/ask/providers/bedrock.rb`)
- Bedrock Converse API (`bedrock-runtime`)
- AWS credentials chain (env vars, ~/.aws/credentials, instance profiles)
- Cross-region inference, model inference profiles
- No `ask-auth` — uses standard AWS SDK auth
- Study: `ruby_llm/lib/ruby_llm/providers/bedrock/`

### 6. Implement `Ask::Provider::Ollama` (`lib/ask/providers/ollama.rb`)
- Local HTTP API (default `http://localhost:11434`)
- Model pulling, streaming, no auth
- Study: `ruby_llm/lib/ruby_llm/providers/ollama/`

### 7. Implement `Ask::Provider::Mistral` (`lib/ask/providers/mistral.rb`)
- Mistral API, function calling, JSON mode, streaming
- Auth via `Ask::Auth.resolve(:mistral_api_key)`
- Study: `ruby_llm/lib/ruby_llm/providers/mistral/`

### 8. Implement `Ask::Provider::Cloudflare` (`lib/ask/providers/cloudflare.rb`)
- Workers AI direct endpoint + AI Gateway passthrough modes
- Template-based base URLs: `{CF_ACCOUNT_ID}`, `{CF_GATEWAY_ID}`
- Auth via `Ask::Auth.resolve(:cloudflare_api_key)`
- Study: `pi/packages/ai/src/providers/cloudflare.ts`

### 9. Register models in the catalog
- Each provider registers its known models on gem load
- See above for the model catalog design

### 10. Test coverage
- Unit tests per provider: wire format, response parsing, error mapping
- Integration tests with VCR cassettes (modeled on `ruby_llm/spec/`)
- Test streaming and non-streaming paths
- Test tool calls, vision, structured output where supported
- Test error handling: rate limits, auth errors, context length exceeded
- Test capability introspection: `capabilities`, `Ask::CapabilityNotSupported`
- Test model catalog registration and resolution
- Test OpenAI-compatible providers via `base_url` override (mock server)

### 11. README
- Quick start: `provider = Ask::Provider::OpenAI.new`
- Capabilities table (which provider supports what)
- Auth setup for each provider
- Model catalog and model resolution
- Streaming usage
- Error handling

## What "Done" Means

- All 8 provider classes implement the `Ask::Provider` interface
- Capabilities introspection works: `provider.capabilities` returns accurate list
- Unsupported capabilities raise `Ask::CapabilityNotSupported` with helpful messages
- Model catalog is populated with all known models
- Chat completions work for every provider (streaming + non-streaming)
- Tool calls work for every provider that supports them
- Each provider handles auth correctly (ask-auth or AWS chain)
- >90% test coverage with VCR cassettes
- Integration tests exist for at least one provider end-to-end
- README documents every provider with auth setup and examples

## Documentation

### Documentation
- **Update ask-docs** after releasing v0.1.0 — the docs site at github.com/ask-rb/ask-docs must reflect this gems API, usage, and position in the ecosystem.
- The ask-docs repo has a Jekyll site with sections for each gem under core/, providers/, tools/, agent/.
- Add or update the relevant page(s) and submit a PR to ask-docs.
- This is not optional — ask-docs is the public face of the ecosystem.

## Improving Parent Gems During Development

### Improving Parent Gems During Development

If during development you discover something in a parent gem (a dependency of this gem)
that needs to be fixed or improved:

1. Make the change in the parent gem's repository at `/Users/kaka/Code/ask-rb/GEMNAME/`
2. Ensure existing tests in the parent gem still pass: `cd ../PARENT && bundle exec rake test`
3. Ensure tests in THIS gem still pass: `bundle exec rake test`
4. Ensure the parent gem still builds: `gem build *.gemspec`
5. Commit the parent gem change, bump its patch version, and push:
   `cd ../PARENT && git commit -m "fix: ..." && git push`
6. Update this gem's Gemfile to reference the updated parent gem
7. Continue with this gem's implementation using the fixed parent

Do NOT break parent functionality. Do NOT change parent APIs without testing
both gems. Parent gems have their own consumers — treat them with care.

## Release Checklist (Required for v0.1.0)

- [ ] All tests pass with >90% coverage
- [ ] Every public API method has documentation
- [ ] README is complete with capabilities table, auth setup, quick start
- [ ] CHANGELOG.md exists with v0.1.0 entry
- [ ] All code committed and pushed to github.com/ask-rb/ask-llm-providers
- [ ] Gem builds without errors: `gem build ask-llm-providers.gemspec`
- [ ] Gem released on RubyGems
- [ ] A consumer script can install, require, and use any provider with no errors
- [ ] A model can be resolved and a chat completed on at least one real provider

## Development Workflow

### Git conventions
- The default branch is **master**. All work should be based on master unless a specific branch is requested.

- Follow the git-workflow skill.
- Conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.
- One logical change per commit.

### Reference projects
- `ruby_llm/lib/ruby_llm/providers/` — wire formats, streaming, auth
- `llm-proxy/lib/llm_proxy/protocols/` — protocol conversion patterns
- `pi/packages/ai/src/providers/` — lazy loading, registration patterns
- `ruby_llm/spec/` — VCR cassette structure and integration testing
### Reference Repositories (Local)
All ask-rb gem repos are available locally at /Users/kaka/Code/ask-rb/ for reference.
Do not clone from GitHub — use the local directories:
- Source code: /Users/kaka/Code/ask-rb/GEMNAME/lib/
- Tests: /Users/kaka/Code/ask-rb/GEMNAME/test/
- Goal: /Users/kaka/Code/ask-rb/GEMNAME/GOAL.md
- Gemspec: /Users/kaka/Code/ask-rb/GEMNAME/GEMNAME.gemspec

Other reference projects in the same workspace:
- /Users/kaka/Code/ask-rb/ruby_llm/ — RubyLLM gem (providers, models, streaming)
- /Users/kaka/Code/ask-rb/ruby_llm-conductor/ — Original conductor (agent loop, tools)
- /Users/kaka/Code/ask-rb/llm-proxy/ — Protocol normalization patterns
- /Users/kaka/Code/ask-rb/pi/ — Pi agent (TypeScript, provider architecture)
- /Users/kaka/Code/ask-rb/solid_agents/ — Original solid_agents (Rails engine)
- /Users/kaka/Code/ask-rb/composio/ — Composio SDK (MCP tool execution examples)
- /Users/kaka/Code/ask-rb/ask-docs/ — Documentation site (update after release)

### Testing
- Minitest (not RSpec). VCR for external calls.
- Unit tests for every public method.
- Run full suite before every commit: `bundle exec rake test`.
