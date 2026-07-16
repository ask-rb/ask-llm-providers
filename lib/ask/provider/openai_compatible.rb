# frozen_string_literal: true

module Ask
  module Providers
    # Single class for all OpenAI-compatible providers.
    #
    # Reads its behavior from {Ask::LLM::OPENAI_COMPATIBLE} via the class-level
    # +compat_config+ that gets set at registration time. Each registered
    # provider is an anonymous subclass with its own compat_config.
    #
    # This eliminates one subclass file per provider — adding a new
    # OpenAI-compatible API is a one-line config entry.
    class OpenAICompatible < Ask::Providers::OpenAI
      class << self
        attr_reader :compat_config

        def slug
          compat_config[:slug].to_s
        end

        def capabilities
          compat_config[:capabilities] || { chat: true, streaming: true, tool_calls: true }
        end

        def configuration_options
          %i[api_key base_url]
        end

        def configuration_requirements
          %i[api_key]
        end

        def configured?(config)
          key = config.respond_to?(:api_key) ? config.api_key : nil
          key ||= ENV[compat_config[:api_key_env].to_s]
          key ||= ENV[compat_config[:alternate_env].to_s] if compat_config[:alternate_env]
          key.to_s.length > 0
        end

        def assume_models_exist?
          false
        end
      end

      def initialize(config = {})
        @compat_cfg = self.class.compat_config || {}
        config = normalize_compat_config(config)
        super(config)
      end

      def api_base
        @config.base_url || @compat_cfg[:api_base] || super
      end

      def headers
        h = { "Content-Type" => "application/json" }
        key = @config.api_key
        h["Authorization"] = "Bearer #{key}" if key
        if (extra = @compat_cfg[:extra_headers])
          extra.each { |k, v| h[k] = v }
        end
        h
      end

      def format_messages(messages)
        result = super
        if @compat_cfg[:reasoning_content]
          result.each { |fm| fm[:reasoning_content] ||= "" if fm[:role] == "assistant" && fm[:tool_calls] }
        end
        result
      end

      private

      def normalize_compat_config(config)
        return config unless config.is_a?(Hash)

        slug = self.class.slug
        api_key = config[:api_key] || config["api_key"] ||
                  config[:"#{slug}_api_key"] ||
                  ENV[@compat_cfg[:api_key_env].to_s] ||
                  (ENV[@compat_cfg[:alternate_env].to_s] if @compat_cfg[:alternate_env]) ||
                  ENV["#{slug.upcase}_API_KEY"]

        base_url = config[:base_url] || config["base_url"] ||
                   ENV["#{slug.upcase}_API_BASE"] ||
                   @compat_cfg[:api_base]

        Ask::LLM::Config.new(api_key:, base_url:)
      end
    end
  end
end
