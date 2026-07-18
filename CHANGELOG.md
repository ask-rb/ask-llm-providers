## [0.8.7] — 2026-07-18

### Fixed

- **`OpenAI#format_message` no longer sends empty `tool_calls: []` on assistant messages** — When a model response has no tool calls, the formatted message previously included `tool_calls: []` in the output. Some providers (notably opencode_go) reject messages with an empty `tool_calls` array. Now the field is only added when there are actual tool calls to report. Fixes multi-turn conversations breaking on all providers that reject empty `tool_calls`.

## [0.8.6] — 2026-07-18

### Added

- **`OpenAICompatible#resolve_credential_from_env_name` now tries both flat key and path segments** — The credential fallback resolves the `api_key_env` name (e.g., `OPENCODE_API_KEY`) both as a flat key (`:opencode_api_key`) and as a nested path (`[:opencode, :api_key]`). This works with the new `Ask::Auth.resolve` multi-name and path segment support from ask-auth 0.2.3.

## [0.8.5] — 2026-07-18

### Fixed

- **`OpenAICompatible#normalize_compat_config` now resolves credentials from `api_key_env` via `Ask::Auth`** — Previously the method only checked explicit config keys and environment variables. Now it also calls `Ask::Auth.resolve` using the downcased `api_key_env` name (e.g., `OPENCODE_API_KEY` → `:opencode_api_key` → resolves through Rails credentials at `opencode.api_key`, env, file, database, or OAuth). This fixes credential resolution for all 26 OpenAI-compatible providers when the API key is stored in Rails credentials, the ask credentials file, or any provider in the auth chain — not just environment variables.

## [0.8.4] — 2026-07-18

### Fixed

- **`normalize_config` (OpenAI) and `normalize_compat_config` (OpenAICompatible) — Config object handling** — `Chat#provider_config` creates an `Ask::LLM::Config` object, but both methods previously bailed out with `return config unless config.is_a?(Hash)`, allowing the Config object to pass through without API key resolution. Now they call `config.to_h` when the object responds to it before the Hash guard, ensuring env vars like `OPENCODE_API_KEY` are properly resolved for all OpenAI-compatible providers. Fixes auth for all 20+ OpenAI-compatible providers when config arrives as a Config object.

## [0.8.1] — 2026-07-17

### Added

- **Rich error categories in HTTP mapper** — `Ask::LLM::HTTP.map_error` now sets `category`, `rate_limit_type`, and `retry_after` on `RateLimitError` instances. Rate limit type is detected from error message keywords (token, budget, concurrent, requests). `retry_after` is extracted from response headers.

## [0.8.0] — 2026-07-17

### Added

- **OpenRouter model source** (`Ask::LLM::Sources::OpenRouter`) — fetches model data from OpenRouter API and fills gaps that models.dev doesn't cover. Adds models for providers like Groq, Together, Fireworks, Cerebras, Meta, Moonshot, Nvidia NIM that aren't in models.dev. Merges with existing models.dev data — models.dev takes priority for overlapping models.
- **`CostCalculator.per_million`** — returns per-million token rates for quick display: `{ input: 2.5, output: 10.0, cache_read: 1.25 }`.
- **Audio token costing** — `calculate` and `breakdown` now accept `audio_input_tokens` and `audio_output_tokens` parameters. Costs are computed from `audio_tokens` pricing data.
- **Tiered pricing** — both `calculate` and `breakdown` accept a `tier:` parameter (`:standard` or `:batch`) that selects the appropriate rate tier.
- **`rake models:update`** — now fetches both models.dev and OpenRouter in sequence.

### Changed

- **Model coverage: 62 → 406 models** across 12 providers, with 397 (98%) having full pricing data.
- **OpenRouter source added** — providers without models.dev coverage (meta, moonshot, nvidia_nim) now have bundled models.
- **`build_model_info`** — pricing hashes are deep-symbolized. `Date.parse` failures handled gracefully via `safe_parse_date`.

## [0.7.0] — 2026-07-17

### Added

- **`Ask::LLM::Sources::ModelsDev`** — fetches model data from `models.dev` API and writes enriched per-provider JSON files with pricing, capabilities, and modalities. Run `rake models:update` before each release to keep bundled model data current.
- **`Ask::LLM::CostCalculator`** — calculates LLM API costs from model pricing data. Supports input, output, cache read/write, and reasoning tokens.

### Changed

- **Model coverage expanded** — from 62 to 289 models across 10 providers, with 284 (98%) having full pricing data. Generated from models.dev API instead of hand-written.
- **`build_model_info` now deep-symbolizes pricing keys** — pricing hashes loaded from JSON now use symbol keys (`:text_tokens`, `:standard`, `:input_per_million`) matching the format produced by `ModelsDevParser` in ask-core.
- **`build_model_info` handles date parsing safely** — `Date.parse` failures no longer silently destroy the entire model entry via a broad `rescue Date::Error`. Invalid dates are gracefully set to `nil` via `safe_parse_date`.

### Fixed

- **Pricing data loss bug** — `rescue Date::Error` in `build_model_info` was catching exceptions from the entire method body, including date parsing and pricing construction. When any model had an unparseable date, its ModelInfo was created with only `id` and `provider`, silently discarding pricing, capabilities, modalities, and all other fields.
- **Pricing key inconsistency** — pricing loaded from JSON had string keys while pricing from `ModelsDevParser` (ask-core) had symbol keys. Both formats now consistently use symbol keys.

## [0.6.1] — 2026-07-17

### Added

- **`Ask::LLM::CostCalculator`** — calculate LLM API costs from model pricing data. Supports input, output, cache read/write, and reasoning tokens. Returns cost in USD or nil if no pricing data available. Works with any object responding to `#pricing` (Ask::ModelInfo, raw hash, etc.).
- **`CostCalculator.breakdown`** — returns a component-by-component cost breakdown hash.

## [0.6.0] — 2026-07-17

### Added

- **14 new OpenAI-compatible providers** — aiml, ai21, anyscale, deepinfra, featherless, friendli, github, hyperbolic, meta, nebius, novita, nscale, nvidia_nim, sambanova. Each is one line in the registry. Total OpenAI-compatible providers: 26. Total providers: 33.
- **Auto-generated tests** — `OpenAICompatibleTest` now builds its test list from `OPENAI_COMPATIBLE` dynamically. Adding a provider automatically generates 5 identity tests (registered, slug, capabilities, api_base, requires_api_key).

## [0.5.0] — 2026-07-17

### Added

- **OpenAI-compatible provider registry** (`Ask::LLM::OPENAI_COMPATIBLE`) — 12 providers defined as data, not classes. Adding a new OpenAI-compatible API (Groq, Together, Fireworks, etc.) is one line in the registry. No new file, no subclass.
- **`Ask::Providers::OpenAICompatible` class** — single class handling all registered providers by reading from the registry. Each provider gets an anonymous subclass with its slug, api_base, env var mapping, and quirks (reasoning_content, extra_headers) set from config.
- **Unified test** — `OpenAICompatibleTest` dynamically tests every registered provider: identity, slug, capabilities, api_base, env var resolution, request building, response parsing, streaming, and tool formatting.

### Removed

- **5 subclass files** — `deepseek.rb`, `openrouter.rb`, `opencode.rb`, `opencode_go.rb`, `mimo.rb` deleted. Replaced by registry entries.
- **DeepSeek-specific test file** — covered by the unified test.

## [0.4.0] — 2026-07-16

### Added

- **`Ask::LLM::ProviderConfig` transformation contract** — Shared module that every provider includes, defining the wire-format interface: `build_request`, `parse_response`, `parse_stream`, `format_tools`, `format_message`. Adding a new provider is now mechanical — implement five methods and the provider works. (Inspired by LiteLLM's `BaseConfig` pattern.)
- **`BaseProviderTests` shared test module** — Every provider test includes this module, which enforces 22 contract tests (interface methods, slug, capabilities, config, request building, error mapping) inherited from LiteLLM's `BaseLLMChatTest` approach. Adding a new provider gives you 22 tests for free.
- **Comprehensive per-provider tests** — Each provider now has dedicated tests for `build_request`, `parse_response`, `parse_stream`, `format_message`, `format_tools`, `parse_error`, and streaming — covering happy paths, edge cases, and error conditions. Total test count: 341 (up from ~33 in v0.1.0).

### Changed

- **Provider refactoring** — OpenAI, Anthropic, Google, Bedrock, Ollama, Cloudflare, and Mistral providers now include `Ask::LLM::ProviderConfig` and implement its transformation contract. The `chat` method in each is a clean orchestrator: build request → HTTP → parse response. Internal methods (`build_chat_payload`, `process_chunk`, etc.) are renamed to the contract standard.
- **Subclass compatibility** — DeepSeek, OpenRouter, OpenCode, OpenCodeGo, and Mimo (all OpenAI subclasses) inherit the transformation contract unchanged. Their `format_messages` overrides continue to work through `build_request`.

### Removed

- **Dead files** — Removed `lib/ask/provider/config.rb` (moved to `lib/ask/llm/provider_config.rb` to avoid namespace collision with `Ask::Provider` class).

## [0.3.1] — 2026-07-14

### Removed
- `Ask::ModelCatalog::PROVIDER_PREFERENCE` removed from ask-core. `find(model_id)` now returns all matching models — no more provider preference disambiguation at the catalog level.

## [0.3.0] — 2026-07-14

### Added
- **Model catalog system** — `Ask::LLM::Catalog` loads model definitions from per-provider JSON files (`lib/ask/llm/models/*.json`), user overrides (`~/.ask-llm-providers/models.json`), and provider API `list_models()` on explicit refresh.
- **Per-provider model JSONs** — 12 JSON files (openai, anthropic, gemini, deepseek, opencode, opencode_go, mimo, openrouter, ollama, mistral, bedrock, cloudflare) with id, name, provider, capabilities, context window, modalities, and pricing.
- **Model aliases** — `Ask::LLM::Aliases` resolves short names (e.g. `claude-sonnet-4` → `claude-sonnet-4-6`). Alias entries are automatically registered into `Ask::ModelCatalog` so `ModelCatalog.find` works with alias names.
- **User config support** — `~/.ask-llm-providers/models.json` overrides bundled model fields or adds custom models.
- **`opencode.json` includes `deepseek-v4-flash`** — matches the default model configuration.

### Changed
- Removed hardcoded `Ask::LLM::Models::OPENAI_MODELS` constants — replaced with catalog-driven model loading.
- `Ask::LLM::Aliases.resolve` now aliases `deepseek-v4` → `deepseek-v4-flash`, `gpt-4o-latest` → `gpt-4o`, `gpt-4.1-latest` → `gpt-4.1`.

### Fixed
- Model entries now include `"provider"` field in JSON files (was missing from generated data).
- User config merges properly override bundled values (was keeping old values on conflict).

## [0.2.2] — 2026-06-25

### Changed
- Extended per-provider tests (Anthropic 18t, Google 14t, DeepSeek 16t, Mistral, Ollama, Cloudflare, Bedrock). Fixed providers_test.rb syntax error. RuboCop, overcommit, gemspec test, SimpleCov, CI.
# Changelog

## [0.1.0] — 2026-06-09

Initial release of `ask-llm-providers`, all LLM providers for the ask-rb ecosystem.

### Added

- **OpenAI provider** — Chat Completions API with streaming, tool calls, vision, structured output, embeddings
- **Anthropic provider** — Messages API with thinking blocks, tool use, prompt caching
- **Google Gemini provider** — `generateContent` API with function calling, streaming, embeddings
- **Amazon Bedrock provider** — Converse API with tool configuration
- **Ollama provider** — Local LLM inference with chat and embeddings endpoints
- **Mistral AI provider** — OpenAI-compatible API with embeddings support
- **Cloudflare provider** — Workers AI direct endpoint and AI Gateway passthrough
- **Error mapping** — Provider-specific HTTP errors → `Ask::Error` types (rate limit, auth, context exceeded, etc.)
- **Provider registration** — All providers auto-registered with `Ask::Provider` on gem load
- **Capabilities introspection** — Each provider exposes supported capabilities
- **Shared HTTP infrastructure** — `Ask::LLM::HTTP` with Faraday connection builder and SSE streaming
- **Test suite** — 33 tests across all providers and error mapping

## [0.1.8] — 2026-06-18

### Added

- **OpenRouter provider** — `Ask::Providers::OpenRouter`, reads `OPENROUTER_API_KEY`,
  sets `HTTP-Referer` and `X-Title` headers.

### Fixed

- **`normalize_config` ENV resolution** — Removed broken monkey-patch that defined
  `normalize_config` on `Object` instead of within the `OpenAI` class. Now resolves
  `api_key` from: explicit config → subclass-specific key → `ENV` var →
  `Ask::Auth.resolve` chain. All OpenAI-compatible subclasses (DeepSeek, OpenCode,
  OpenCodeGo, Mimo, OpenRouter) inherit the fix.

## [0.1.9] — 2026-06-18

### Fixed

- **`format_messages` with Hash tool_calls** — Tool calls can arrive as Hash (keyed
  by call_id) from some chat implementations, or as Array. The method now detects
  both formats with `tc.is_a?(Hash) ? tc.values : tc`. Also handles `OpenStruct`
  tool call objects via `.respond_to?` checks instead of assuming Hash accessors.

## [0.2.0] — 2026-06-19

### Fixed

- **SSE buffering across all streaming providers** — TCP fragmentation in
  Faraday's `on_data` callback caused silent data loss when SSE events were
  split across packets. Added persistent `@_sse_buffer` with complete-event
  extraction via `Ask::LLM::SSEBuffer` module. Affected providers:
  OpenAI, Anthropic, Cloudflare, Google, Ollama. All OpenAI-compatible
  subclasses inherit the fix.

### Added

- **`Ask::LLM::SSEBuffer`** — Shared module providing `init_sse_buffer` and
  `each_sse_event(raw)` for SSE buffering across streaming callbacks.
- **SSE buffering tests** — 5 new tests covering fragmented data, event
  boundaries, multiple events, and `[DONE]` sentinel.

## [0.1.10] — 2026-06-18

### Fixed

- **`chat_stream` nil response body** — Streaming requests consume the response body
  via `on_data` callback, leaving `resp.body` as `nil`. `JSON.parse(nil)` raised
  `TypeError: no implicit conversion of nil into String`. Now checks
  `resp.body` before parsing.
