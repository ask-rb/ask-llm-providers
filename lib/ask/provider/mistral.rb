# frozen_string_literal: true

module Ask
  module Providers
    # Mistral AI provider. Uses OpenAI-compatible wire format.
    class Mistral < Ask::Provider
      def initialize(config = {})
        config = normalize_config(config)
        super(config)
        @http = build_http
      end

      def api_base
        @config.api_base || "https://api.mistral.ai/v1"
      end

      def headers
        { "Content-Type" => "application/json", "Authorization" => "Bearer #{@config.api_key}" }.compact
      end

      def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
        # Reuse OpenAI provider's logic since Mistral is OpenAI-compatible
        openai = Providers::OpenAI.new(api_key: @config.api_key, base_url: api_base)
        openai.chat(messages, model: model, tools: tools, temperature: temperature, stream: stream, schema: schema, **params, &block)
      end

      def embed(texts, model:)
        texts = Array(texts)
        response = @http.post("embeddings") { |r| r.body = { model: model, input: texts } }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Mistral") unless response.success?
        embeddings = response.body["data"].map { |d| d["embedding"] }
        Ask::Result.success(embeddings.one? ? embeddings.first : embeddings)
      end

      def list_models
        response = @http.get("models")
        return [] unless response.success?
        response.body["data"].map { |m| Ask::ModelInfo.new(id: m["id"], provider: slug) }
      end

      def parse_error(response)
        body = response.body rescue nil
        body&.dig("error", "message") || body&.dig("error", "type")
      end

      class << self
        def capabilities
          { chat: true, streaming: true, tool_calls: true, structured_output: true, embed: true }
        end
        def configuration_options; %i[api_key api_base]; end
        def configuration_requirements; %i[api_key]; end
        def slug; "mistral"; end
      end

      private

      def normalize_config(config)
        return config unless config.is_a?(Hash)
        Ask::LLM::Config.new(
          api_key: config[:api_key] || config["api_key"] || config[:mistral_api_key],
          api_base: config[:api_base] || config["api_base"]
        )
      end

      def build_http
        LLM::HTTP.connection(api_base, headers: headers, request: { open_timeout: 30, timeout: 120 })
      end
    end
  end
end
