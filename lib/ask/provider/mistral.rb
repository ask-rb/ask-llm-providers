# frozen_string_literal: true

module Ask
  module Providers
    # Mistral AI provider. Uses OpenAI-compatible wire format.
    class Mistral < Ask::Provider
      include Ask::LLM::ProviderConfig

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
        response = @http.post("embeddings") { |r| r.body = { model:, input: texts } }
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
        def slug; "mistral"; end

        def capabilities
          { chat: true, streaming: true, tool_calls: true, structured_output: true, embed: true }
        end

        def configuration_options; %i[api_key api_base]; end
        def configuration_requirements; %i[api_key]; end
      end

      # --- Config transformation contract ---

      def build_request(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params)
        payload = {
          model:,
          messages: messages.map { |m| format_message(m) },
          stream: stream || false
        }
        payload[:temperature] = temperature if temperature
        tool_defs = format_tools(tools) if tools&.any?
        payload[:tools] = tool_defs if tool_defs
        if schema
          payload[:response_format] = {
            type: "json_schema",
            json_schema: { name: "response", schema:, strict: true }
          }
        end
        payload.merge(params)
      end

      def parse_response(body, model)
        choice = body.dig("choices", 0)
        return Ask::Message.new(role: :assistant, content: nil) unless choice

        msg = choice["message"]
        usage = body["usage"] || {}
        Ask::Message.new(
          role: :assistant,
          content: msg["content"],
          tool_calls: parse_tool_calls(msg["tool_calls"]),
          metadata: {
            model: body["model"] || model,
            finish_reason: choice["finish_reason"],
            input_tokens: usage["prompt_tokens"],
            output_tokens: usage["completion_tokens"],
            raw: body
          }
        )
      end

      def parse_stream(raw, stream, model, &block)
        each_sse_event(raw) do |data|
          parsed = JSON.parse(data) rescue next
          choice = parsed.dig("choices", 0) or next
          delta = choice["delta"] || {}
          chunk = Ask::Chunk.new(
            content: delta["content"],
            tool_calls: parse_stream_tool_calls(delta["tool_calls"]),
            finish_reason: choice["finish_reason"],
            usage: parsed["usage"]
          )
          stream.add(chunk)
          yield chunk if block_given?
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
              parameters: t.respond_to?(:parameters) ? t.parameters : t[:parameters]
            }
          }
        end
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
        LLM::HTTP.connection(api_base, headers:, request: { open_timeout: 30, timeout: 120 })
      end

      def parse_tool_calls(calls)
        return nil unless calls&.any?

        calls.map { |tc|
          { id: tc["id"], type: "function", name: tc.dig("function", "name"), arguments: tc.dig("function", "arguments") }
        }
      end

      def parse_stream_tool_calls(calls)
        return nil unless calls&.any?

        calls.map { |tc|
          { id: tc["id"], name: tc.dig("function", "name"), arguments: tc.dig("function", "arguments"), index: tc["index"] }
        }
      end

      def each_sse_event(raw)
        @_sse_buffer ||= +""
        @_sse_buffer << raw

        while (event_end = @_sse_buffer.index("\n\n"))
          event_data = @_sse_buffer.slice!(0, event_end + 2).strip
          next if event_data.empty?

          data_content = extract_data(event_data)
          next if data_content.empty?
          break if data_content == "[DONE]"

          yield data_content
        end
      end

      def extract_data(event_data)
        content = +""
        event_data.each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?(":")
          if line.start_with?("data: ")
            content << line[6..]
          elsif line.start_with?("data:")
            content << line[5..]
          end
        end
        content
      end

      def chat_nonstream(payload, model)
        response = @http.post("chat/completions") { |r| r.body = payload }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Mistral") unless response.success?

        parse_response(response.body, model)
      end

      def chat_stream(payload, model, &block)
        stream = Ask::Stream.new
        @_sse_buffer = +""
        response = @http.post("chat/completions") do |req|
          req.body = payload.merge(stream: true)
          req.options.on_data = proc { |data, _bytes, _env| parse_stream(data, stream, model, &block) }
        end
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Mistral") unless response.success?

        stream.finish!
        stream
      end
    end
  end
end
