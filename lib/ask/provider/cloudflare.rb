# frozen_string_literal: true

module Ask
  module Providers
    # Cloudflare Workers AI provider. Supports both direct Workers AI and AI Gateway.
    class Cloudflare < Ask::Provider
      include Ask::LLM::SSEBuffer
      include Ask::LLM::ProviderConfig

      def initialize(config = {})
        config = normalize_config(config)
        super(config)
        @http = build_http
      end

      def api_base
        if @config.gateway_id
          "https://gateway.ai.cloudflare.com/v1/#{@config.account_id}/#{@config.gateway_id}"
        else
          "https://api.cloudflare.com/client/v4/accounts/#{@config.account_id}/ai/v1"
        end
      end

      def headers
        { "Content-Type" => "application/json", "Authorization" => "Bearer #{@config.api_key}" }.compact
      end

      def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
        msgs = messages.is_a?(Ask::Conversation) ? messages.to_a : messages
        payload = build_request(msgs, model:, tools:, temperature:, stream:, schema:, **params)
        endpoint = @config.gateway_id ? "chat/completions" : "run/#{model}"
        if stream && @config.gateway_id
          chat_stream_gateway(endpoint, payload, model, &block)
        else
          chat_nonstream(endpoint, payload, model)
        end
      end

      def list_models
        []
      end

      def parse_error(response)
        body = response.body rescue nil
        body&.dig("errors", 0, "message") || body&.dig("error", "message")
      end

      class << self
        def slug; "cloudflare"; end

        def capabilities
          { chat: true, streaming: true, vision: true }
        end

        def configuration_options; %i[api_key account_id gateway_id]; end
        def configuration_requirements; %i[api_key account_id]; end
      end

      # --- Config transformation contract ---

      def build_request(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params)
        if @config.gateway_id
          payload = {
            model:,
            messages: messages.map { |m| format_message(m) },
            stream: stream || false
          }
        else
          payload = {
            messages: messages.map { |m| format_message(m) }
          }
        end
        payload[:temperature] = temperature if temperature
        payload.merge(params)
      end

      def parse_response(body, model)
        if @config.gateway_id
          parse_openai_response(body, model)
        else
          result = body["result"] || {}
          Ask::Message.new(role: :assistant, content: result["response"], metadata: { model:, raw: body })
        end
      end

      def parse_stream(raw, stream, model, &block)
        each_sse_event(raw) do |data|
          parsed = JSON.parse(data) rescue next
          delta = parsed.dig("choices", 0, "delta") || {}
          chunk = Ask::Chunk.new(content: delta["content"])
          stream.add(chunk)
          yield chunk if block_given?
        end
      end

      def format_message(msg)
        { role: (msg[:role] || msg["role"]).to_s, content: msg[:content] || msg["content"] }
      end

      private

      def normalize_config(config)
        return config unless config.is_a?(Hash)

        Ask::LLM::Config.new(
          api_key: config[:api_key] || config["api_key"] || config[:cloudflare_api_key],
          account_id: config[:account_id] || config["account_id"] || config[:cf_account_id],
          gateway_id: config[:gateway_id] || config["gateway_id"] || config[:cf_gateway_id]
        )
      end

      def build_http
        LLM::HTTP.connection(api_base, headers:, request: { open_timeout: 30, timeout: 120 })
      end

      def parse_openai_response(body, model)
        choice = body.dig("choices", 0)
        return Ask::Message.new(role: :assistant, content: nil) unless choice

        msg = choice["message"]
        Ask::Message.new(role: :assistant, content: msg["content"], metadata: { model:, finish_reason: choice["finish_reason"], raw: body })
      end

      def chat_nonstream(endpoint, payload, model)
        response = @http.post(endpoint) { |r| r.body = payload }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Cloudflare") unless response.success?

        parse_response(response.body, model)
      end

      def chat_stream_gateway(endpoint, payload, model, &block)
        stream = Ask::Stream.new
        init_sse_buffer
        response = @http.post(endpoint) do |req|
          req.body = payload.merge(stream: true)
          req.options.on_data = proc { |data, _bytes, _env| parse_stream(data, stream, model, &block) }
        end
        raise LLM::HTTP.map_error(response.status, JSON.parse(response.body), provider: "Cloudflare") unless response.success?

        stream.finish!
        stream
      end
    end
  end
end
