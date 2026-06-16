# frozen_string_literal: true

module Ask
  module Providers
    # OpenRouter API — an OpenAI-compatible aggregator at openrouter.ai.
    # Provides access to many models through a single endpoint.
    #
    # Configuration via environment:
    #   OPENROUTER_API_KEY  — required, your OpenRouter API key
    #   OPENROUTER_API_BASE — optional, base URL (default: https://openrouter.ai/api/v1)
    class OpenRouter < OpenAI
      def api_base
        @config.base_url || ENV["OPENROUTER_API_BASE"] || "https://openrouter.ai/api/v1"
      end

      def headers
        h = super
        key = @config.api_key || ENV["OPENROUTER_API_KEY"]
        h["Authorization"] = "Bearer #{key}" if key
        h["HTTP-Referer"] = ENV["OPENROUTER_REFERER"] || "https://github.com/ask-rb"
        h["X-Title"] = ENV["OPENROUTER_APP_TITLE"] || "ask-rb"
        h
      end

      class << self
        def slug; "openrouter"; end
        def configuration_options; %i[api_key base_url]; end
        def configuration_requirements; %i[api_key]; end
        def configured?(config)
          key = config.respond_to?(:api_key) ? config.api_key : nil
          key ||= ENV["OPENROUTER_API_KEY"]
          key.to_s.length > 0
        end
      end
    end
  end
end
