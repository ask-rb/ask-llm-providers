# frozen_string_literal: true

module Ask
  module Providers
    # Mimo API — an OpenAI-compatible provider
    class Mimo < OpenAI
      def api_base
        @config.base_url || ENV["MIMO_API_BASE"] || "https://token-plan-sgp.xiaomimimo.com/v1"
      end

      def headers
        key = @config.api_key || ENV["MIMO_API_KEY"]
        h = { "Content-Type" => "application/json" }
        h["Authorization"] = "Bearer #{key}" if key
        h
      end

      class << self
        def slug; "mimo"; end
        def configuration_options; %i[api_key base_url]; end
        def configuration_requirements; %i[api_key]; end
        def configured?(config)
          key = config.respond_to?(:api_key) ? config.api_key : nil
          key ||= ENV["MIMO_API_KEY"]
          key.to_s.length > 0
        end
      end
    end
  end
end
