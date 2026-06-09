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
