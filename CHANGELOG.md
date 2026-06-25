## [0.2.2] - 2026-06-25

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
