# frozen_string_literal: true

module Ask
  module Providers
    # OpenCode Go API — an OpenAI-compatible provider at opencode.ai/zen/go
    class OpenCodeGo < OpenAI
      def api_base
        @config.base_url || ENV["OPENCODE_GO_API_BASE"] || "https://opencode.ai/zen/go/v1"
      end

      def headers
        key = @config.api_key || ENV["OPENCODE_API_KEY"] || ENV["OPENCODE_GO_API_KEY"]
        h = { "Content-Type" => "application/json" }
        h["Authorization"] = "Bearer #{key}" if key
        h
      end

      class << self
        def slug; "opencode_go"; end
        def configuration_options; %i[api_key base_url]; end
        def configuration_requirements; %i[api_key]; end
        def configured?(config)
          key = config.respond_to?(:api_key) ? config.api_key : nil
          key ||= ENV["OPENCODE_API_KEY"] || ENV["OPENCODE_GO_API_KEY"]
          key.to_s.length > 0
        end
      end
    end
  end
end
