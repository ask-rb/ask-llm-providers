# frozen_string_literal: true

# Model definitions for OpenAI and compatible providers.
# Registered on gem load via Ask::Models.register.
module Ask
  module LLM
    module Models
      OPENAI_MODELS = [
        { id: "gpt-4o", family: "gpt4o", capabilities: %w[chat streaming function_calling structured_output vision], context: 128000, output: 16384 },
        { id: "gpt-4o-mini", family: "gpt4o_mini", capabilities: %w[chat streaming function_calling structured_output vision], context: 128000, output: 16384 },
        { id: "gpt-4.1", family: "gpt41", capabilities: %w[chat streaming function_calling structured_output vision], context: 1047576, output: 32768 },
        { id: "gpt-4.1-mini", family: "gpt41_mini", capabilities: %w[chat streaming function_calling structured_output vision], context: 1047576, output: 32768 },
        { id: "gpt-4.1-nano", family: "gpt41_nano", capabilities: %w[chat streaming function_calling structured_output vision], context: 1047576, output: 32768 },
        { id: "gpt-4-turbo", family: "gpt4_turbo", capabilities: %w[chat streaming function_calling vision], context: 128000, output: 4096 },
        { id: "gpt-4", family: "gpt4", capabilities: %w[chat streaming function_calling], context: 8192, output: 8192 },
        { id: "o1", family: "o1", capabilities: %w[chat streaming function_calling structured_output reasoning], context: 200000, output: 100000 },
        { id: "o1-mini", family: "o1_mini", capabilities: %w[chat streaming function_calling reasoning], context: 128000, output: 65536 },
        { id: "o3-mini", family: "o3_mini", capabilities: %w[chat streaming function_calling structured_output reasoning], context: 200000, output: 100000 },
        { id: "gpt-4o-audio-preview", family: "gpt4o_audio", capabilities: %w[chat streaming audio], context: 128000 },
        { id: "gpt-4o-realtime-preview", family: "gpt4o_realtime", capabilities: %w[chat streaming audio], context: 128000 },
        { id: "gpt-4o-mini-realtime-preview", family: "gpt4o_mini_realtime", capabilities: %w[chat streaming audio], context: 128000 },
        { id: "gpt-4.5-preview", family: "gpt45", capabilities: %w[chat streaming function_calling structured_output vision], context: 128000, output: 16384 },
        { id: "text-embedding-3-large", family: "embedding3_large", capabilities: %w[embed], context: 8191 },
        { id: "text-embedding-3-small", family: "embedding3_small", capabilities: %w[embed], context: 8191 },
        { id: "whisper-1", family: "whisper", capabilities: %w[transcribe] },
        { id: "tts-1", family: "tts1", capabilities: %w[tts] },
        { id: "tts-1-hd", family: "tts1_hd", capabilities: %w[tts] },
        { id: "dall-e-3", family: "dall_e", capabilities: %w[paint] },
        { id: "dall-e-2", family: "dall_e", capabilities: %w[paint] }
      ].freeze

      ANTHROPIC_MODELS = [
        { id: "claude-sonnet-4-5", family: "claude_sonnet", capabilities: %w[chat streaming function_calling vision thinking prompt_caching], context: 200000, output: 8192 },
        { id: "claude-sonnet-4", family: "claude_sonnet", capabilities: %w[chat streaming function_calling vision thinking prompt_caching], context: 200000, output: 8192 },
        { id: "claude-4-opus", family: "claude_opus", capabilities: %w[chat streaming function_calling vision thinking prompt_caching], context: 200000, output: 8192 },
        { id: "claude-3.5-sonnet", family: "claude_sonnet", capabilities: %w[chat streaming function_calling vision thinking], context: 200000, output: 8192 },
        { id: "claude-3.5-haiku", family: "claude_haiku", capabilities: %w[chat streaming function_calling vision thinking], context: 200000, output: 8192 },
        { id: "claude-3-opus", family: "claude_opus", capabilities: %w[chat streaming function_calling vision thinking], context: 200000, output: 4096 },
        { id: "claude-3-sonnet", family: "claude_sonnet", capabilities: %w[chat streaming function_calling vision], context: 200000, output: 4096 },
        { id: "claude-3-haiku", family: "claude_haiku", capabilities: %w[chat streaming function_calling vision], context: 200000, output: 4096 }
      ].freeze

      GOOGLE_MODELS = [
        { id: "gemini-2.5-pro", family: "gemini", capabilities: %w[chat streaming function_calling structured_output vision reasoning], context: 1048576, output: 65536 },
        { id: "gemini-2.5-flash", family: "gemini", capabilities: %w[chat streaming function_calling structured_output vision], context: 1048576, output: 65536 },
        { id: "gemini-2.0-flash", family: "gemini", capabilities: %w[chat streaming function_calling structured_output vision], context: 1048576, output: 8192 },
        { id: "gemini-1.5-pro", family: "gemini", capabilities: %w[chat streaming function_calling structured_output vision], context: 2097152, output: 8192 },
        { id: "gemini-1.5-flash", family: "gemini", capabilities: %w[chat streaming function_calling structured_output vision], context: 1048576, output: 8192 },
        { id: "text-embedding-004", family: "embedding", capabilities: %w[embed], context: 2048 }
      ].freeze

      MISTRAL_MODELS = [
        { id: "mistral-large-2501", family: "mistral", capabilities: %w[chat streaming function_calling structured_output], context: 128000, output: 4096 },
        { id: "mistral-small-2501", family: "mistral", capabilities: %w[chat streaming function_calling structured_output], context: 128000, output: 4096 },
        { id: "mistral-embed", family: "mistral", capabilities: %w[embed], context: 8192 }
      ].freeze

      OLLAMA_MODELS = [
        { id: "llama3.2", family: "llama", capabilities: %w[chat streaming], context: 8192 },
        { id: "llama3.3", family: "llama", capabilities: %w[chat streaming], context: 8192 },
        { id: "mistral", family: "mistral", capabilities: %w[chat streaming], context: 8192 },
        { id: "gemma3", family: "gemma", capabilities: %w[chat streaming], context: 8192 },
        { id: "phi4", family: "phi", capabilities: %w[chat streaming], context: 8192 },
        { id: "qwen2.5", family: "qwen", capabilities: %w[chat streaming], context: 32768 },
        { id: "deepseek-r1", family: "deepseek", capabilities: %w[chat streaming reasoning], context: 8192 }
      ].freeze
    end
  end
end
