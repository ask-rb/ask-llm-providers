# frozen_string_literal: true

module Ask
  module LLM
    # Registry of OpenAI-compatible providers (data, not classes).
    #
    # Each entry is configuration for {Ask::Providers::OpenAICompatible}.
    # To add a new provider, add one line here — no new file, no subclass.
    #
    # @example
    #   groq: { api_base: "https://api.groq.com/openai/v1", api_key_env: "GROQ_API_KEY" }
    #
    OPENAI_COMPATIBLE = {
      aiml:          { api_base: "https://api.aimlapi.com/v1",                    api_key_env: "AIML_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      ai21:          { api_base: "https://api.ai21.com/studio/v1",                api_key_env: "AI21_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      anyscale:      { api_base: "https://api.endpoints.anyscale.com/v1",         api_key_env: "ANYSCALE_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      cerebras:      { api_base: "https://api.cerebras.ai/v1",                    api_key_env: "CEREBRAS_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      deepinfra:     { api_base: "https://api.deepinfra.com/v1/openai",           api_key_env: "DEEPINFRA_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      deepseek:      { api_base: "https://api.deepseek.com",                      api_key_env: "DEEPSEEK_API_KEY",
                       reasoning_content: true,
                       capabilities: { chat: true, streaming: true, tool_calls: true, thinking: true } },

      featherless:   { api_base: "https://api.featherless.ai/v1",                 api_key_env: "FEATHERLESS_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      fireworks:     { api_base: "https://api.fireworks.ai/inference/v1",         api_key_env: "FIREWORKS_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      friendli:      { api_base: "https://api.friendli.ai/serverless/v1",         api_key_env: "FRIENDLI_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      github:        { api_base: "https://models.inference.ai.azure.com",         api_key_env: "GITHUB_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true, vision: true } },

      groq:          { api_base: "https://api.groq.com/openai/v1",                api_key_env: "GROQ_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true, vision: true } },

      hyperbolic:    { api_base: "https://api.hyperbolic.xyz/v1",                 api_key_env: "HYPERBOLIC_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      meta:          { api_base: "https://api.llama.com/compat/v1",               api_key_env: "LLAMA_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      mimo:          { api_base: "https://token-plan-sgp.xiaomimimo.com/v1",      api_key_env: "MIMO_API_KEY",
                       capabilities: { chat: true, streaming: true } },

      moonshot:      { api_base: "https://api.moonshot.ai/v1",                    api_key_env: "MOONSHOT_API_KEY",
                       capabilities: { chat: true, streaming: true } },

      nebius:        { api_base: "https://api.studio.nebius.ai/v1",               api_key_env: "NEBIUS_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      novita:        { api_base: "https://api.novita.ai/v3/openai",               api_key_env: "NOVITA_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      nscale:        { api_base: "https://inference.api.nscale.com/v1",           api_key_env: "NSCALE_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      nvidia_nim:    { api_base: "https://integrate.api.nvidia.com/v1",           api_key_env: "NVIDIA_NIM_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      opencode:      { api_base: "https://opencode.ai/zen/v1",                    api_key_env: "OPENCODE_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      opencode_go:   { api_base: "https://opencode.ai/zen/go/v1",                 api_key_env: "OPENCODE_API_KEY",
                        capabilities: { chat: true, streaming: true, tool_calls: true } },

      openrouter:    { api_base: "https://openrouter.ai/api/v1",                  api_key_env: "OPENROUTER_API_KEY",
                       extra_headers: { "HTTP-Referer" => "https://github.com/ask-rb",
                                        "X-Title" => "ask-rb" },
                       capabilities: { chat: true, streaming: true, tool_calls: true, vision: true,
                                       thinking: true, structured_output: true } },

      perplexity:    { api_base: "https://api.perplexity.ai",                     api_key_env: "PERPLEXITY_API_KEY",
                       capabilities: { chat: true, streaming: true } },

      sambanova:     { api_base: "https://api.sambanova.ai/v1",                   api_key_env: "SAMBANOVA_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      together:      { api_base: "https://api.together.xyz/v1",                   api_key_env: "TOGETHER_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true } },

      xai:           { api_base: "https://api.x.ai/v1",                           api_key_env: "XAI_API_KEY",
                       capabilities: { chat: true, streaming: true, tool_calls: true, vision: true,
                                       thinking: true } }
    }.freeze

    OPENAI_COMPATIBLE_COUNT = OPENAI_COMPATIBLE.size
  end
end
