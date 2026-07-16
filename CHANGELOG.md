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
