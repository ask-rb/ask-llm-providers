# frozen_string_literal: true

module Ask
  module Providers
    # Ollama provider for local LLM inference.
    # Connects to a local Ollama server (default: http://localhost:11434).
    class Ollama < Ask::Provider
      include Ask::LLM::ProviderConfig

      def initialize(config = {})
        config = normalize_config(config)
        super(config)
        @http = build_http
      end

      def api_base
        @config.api_base || "http://localhost:11434"
      end

      def headers
        { "Content-Type" => "application/json" }
      end

      def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
        msgs = messages.is_a?(Ask::Conversation) ? messages.to_a : messages
        payload = build_request(msgs, model:, tools:, temperature:, stream:, schema:, **params)
        if stream
          chat_stream(payload, model, &block)
        else
          chat_nonstream(payload, model)
        end
      end

      def embed(texts, model:)
        texts = Array(texts)
        response = @http.post("api/embeddings") { |r| r.body = { model:, prompt: texts.first } }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Ollama") unless response.success?

        Ask::Result.success(response.body["embedding"])
      end

      def list_models
        response = @http.get("api/tags")
        return [] unless response.success?

        response.body["models"].map { |m| Ask::ModelInfo.new(id: m["name"], provider: slug) }
      end

      class << self
        def slug; "ollama"; end

        def capabilities
          { chat: true, streaming: true, tool_calls: true, embed: true, local: true }
        end

        def configuration_options; %i[api_base]; end
        def configuration_requirements; %i[]; end
        def local?; true; end
      end

      # --- Config transformation contract ---

      def build_request(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params)
        payload = {
          model:,
          messages: messages.map { |m| format_message(m) },
          stream: stream || false,
          options: {}
        }
        payload[:options][:temperature] = temperature if temperature
        tool_defs = format_tools(tools) if tools&.any?
        payload[:tools] = tool_defs if tool_defs
        payload.merge(params)
      end

      def parse_response(body, model)
        msg = body["message"] || {}
        Ask::Message.new(
          role: :assistant,
          content: msg["content"],
          metadata: {
            model: body["model"] || model,
            done: body["done"],
            total_duration: body["total_duration"],
            raw: body
          }
        )
      end

      def parse_stream(raw, stream, model, &block)
        @_sse_buffer ||= +""
        @_sse_buffer << raw

        while (line_end = @_sse_buffer.index("\n"))
          line = @_sse_buffer.slice!(0, line_end + 1).strip
          next if line.empty?

          parsed = JSON.parse(line) rescue next
          msg = parsed["message"] || {}
          chunk = Ask::Chunk.new(content: msg["content"])
          stream.add(chunk)
          yield chunk if block_given?
          if parsed["done"]
            chunk = Ask::Chunk.new(finish_reason: "stop", usage: { total_duration: parsed["total_duration"] })
            stream.add(chunk)
            yield chunk if block_given?
          end
        end
      end

      def format_message(msg)
        { role: (msg[:role] || msg["role"]).to_s, content: msg[:content] || msg["content"] }
      end

      def format_tools(tools)
        tools.map do |t|
          {
            type: "function",
            function: {
              name: t.respond_to?(:name) ? t.name : t[:name],
              description: t.respond_to?(:description) ? t.description : t[:description],
              parameters: t.respond_to?(:parameters) ? t.parameters : (t[:parameters] || {})
            }
          }
        end
      end

      private

      def normalize_config(config)
        return config unless config.is_a?(Hash)

        Ask::LLM::Config.new(api_base: config[:api_base] || config["api_base"])
      end

      def build_http
        LLM::HTTP.connection(api_base, headers:, request: { open_timeout: 5, timeout: 600 })
      end

      def chat_nonstream(payload, model)
        response = @http.post("api/chat") { |r| r.body = payload }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Ollama") unless response.success?

        parse_response(response.body, model)
      end

      def chat_stream(payload, model, &block)
        stream = Ask::Stream.new
        @_sse_buffer = +""
        response = @http.post("api/chat") do |req|
          req.body = payload.merge(stream: true)
          req.options.on_data = proc { |data, _bytes, _env| parse_stream(data, stream, model, &block) }
        end
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Ollama") unless response.success?

        stream.finish!
        stream
      end
    end
  end
end
