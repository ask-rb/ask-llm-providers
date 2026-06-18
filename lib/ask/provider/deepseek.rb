# frozen_string_literal: true

module Ask
  module Providers
    # DeepSeek API — an OpenAI-compatible provider at api.deepseek.com.
    # Supports DeepSeek V2, V3, V4 Chat, R1 reasoning, and all DeepSeek models
    # via the OpenAI-compatible endpoint.
    #
    # Configuration via environment:
    #   DEEPSEEK_API_KEY  — required, your DeepSeek API key
    #   DEEPSEEK_API_BASE — optional, base URL (default: https://api.deepseek.com)
    class DeepSeek < OpenAI
      def api_base
        @config.base_url || ENV["DEEPSEEK_API_BASE"] || "https://api.deepseek.com"
      end

      def headers
        key = @config.api_key || ENV["DEEPSEEK_API_KEY"]
        h = { "Content-Type" => "application/json" }
        h["Authorization"] = "Bearer #{key}" if key
        h
      end

      # DeepSeek requires reasoning_content in every assistant message
      # that includes tool_calls. Override format_messages to inject it.
      def format_messages(messages)
        super.map do |fm|
          if fm[:role] == "assistant" && fm[:tool_calls]
            fm[:reasoning_content] = fm[:reasoning_content] || ""
          end
          fm
        end
      end

      class << self
        def slug; "deepseek"; end
        def configuration_options; %i[api_key base_url]; end
        def configuration_requirements; %i[api_key]; end
        def configured?(config)
          key = config.respond_to?(:api_key) ? config.api_key : nil
          key ||= ENV["DEEPSEEK_API_KEY"]
          key.to_s.length > 0
        end
      end
    end
  end
end
