# frozen_string_literal: true

module Ask
  module LLM
    # Registry of OpenAI-compatible providers (data, not classes).
    #
    # Each entry is configuration for {Ask::Providers::OpenAICompatible}.
    # To add a new provider, add one line here — no new file, no subclass.
    #
    # @example Adding Groq
    #   groq: { api_base: "https://api.groq.com/openai/v1", api_key_env: "GROQ_API_KEY" }
    #
    OPENAI_COMPATIBLE = {
      deepseek:    { api_base: "https://api.deepseek.com",                      api_key_env: "DEEPSEEK_API_KEY",
                     reasoning_content: true,
                     capabilities: { chat: true, streaming: true, tool_calls: true, thinking: true } },

      openrouter:  { api_base: "https://openrouter.ai/api/v1",                  api_key_env: "OPENROUTER_API_KEY",
                     extra_headers: { "HTTP-Referer" => "https://github.com/ask-rb",
                                      "X-Title" => "ask-rb" },
                     capabilities: { chat: true, streaming: true, tool_calls: true, vision: true,
                                     thinking: true, structured_output: true } },

      opencode:    { api_base: "https://opencode.ai/zen/v1",                    api_key_env: "OPENCODE_API_KEY",
                     capabilities: { chat: true, streaming: true, tool_calls: true } },

      opencode_go: { api_base: "https://opencode.ai/zen/go/v1",                 api_key_env: "OPENCODE_GO_API_KEY",
                     alternate_env: "OPENCODE_API_KEY",
                     capabilities: { chat: true, streaming: true, tool_calls: true } },

      mimo:        { api_base: "https://token-plan-sgp.xiaomimimo.com/v1",      api_key_env: "MIMO_API_KEY",
                     capabilities: { chat: true, streaming: true } },

      groq:        { api_base: "https://api.groq.com/openai/v1",                api_key_env: "GROQ_API_KEY",
                     capabilities: { chat: true, streaming: true, tool_calls: true, vision: true } },

      together:    { api_base: "https://api.together.xyz/v1",                   api_key_env: "TOGETHER_API_KEY",
                     capabilities: { chat: true, streaming: true, tool_calls: true } },

      fireworks:   { api_base: "https://api.fireworks.ai/inference/v1",         api_key_env: "FIREWORKS_API_KEY",
                     capabilities: { chat: true, streaming: true, tool_calls: true } },

      perplexity:  { api_base: "https://api.perplexity.ai",                     api_key_env: "PERPLEXITY_API_KEY",
                     capabilities: { chat: true, streaming: true } },

      cerebras:    { api_base: "https://api.cerebras.ai/v1",                    api_key_env: "CEREBRAS_API_KEY",
                     capabilities: { chat: true, streaming: true, tool_calls: true } },

      xai:         { api_base: "https://api.x.ai/v1",                           api_key_env: "XAI_API_KEY",
                     capabilities: { chat: true, streaming: true, tool_calls: true, vision: true,
                                     thinking: true } },

      moonshot:    { api_base: "https://api.moonshot.ai/v1",                    api_key_env: "MOONSHOT_API_KEY",
                     capabilities: { chat: true, streaming: true } }
    }.freeze
  end
end
