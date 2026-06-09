# frozen_string_literal: true

module Ask
  module Providers
    # OpenAI API provider. Also handles all OpenAI-compatible providers
    # (OpenRouter, DeepSeek, Azure, XAI, Perplexity, GPUStack, etc.) via
    # +base_url+ override.
    class OpenAI < Ask::Provider
      def initialize(config = {})
        config = normalize_config(config)
        super(config)
        @http = build_http
      end

      def api_base
        @config.base_url || "https://api.openai.com/v1"
      end

      def headers
        key = @config.api_key || @config.openai_api_key
        h = { "Content-Type" => "application/json" }
        h["Authorization"] = "Bearer #{key}" if key
        h["OpenAI-Organization"] = @config.organization_id if @config.organization_id
        h["OpenAI-Project"] = @config.project_id if @config.project_id
        h
      end

      def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
        msgs = messages.is_a?(Ask::Conversation) ? messages.to_a : messages
        payload = build_chat_payload(msgs, model, tools, temperature, stream, schema, **params)
        stream ? chat_stream(payload, model, &block) : chat_nonstream(payload, model)
      end

      def embed(texts, model:)
        texts = Array(texts)
        response = @http.post("embeddings") { |r| r.body = { model: model, input: texts } }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "OpenAI") unless response.success?
        embeddings = response.body["data"].map { |d| d["embedding"] }
        Ask::Result.success(embeddings.one? ? embeddings.first : embeddings)
      end

      def list_models
        response = @http.get("models")
        return [] unless response.success?
        response.body["data"].map { |m| Ask::ModelInfo.new(id: m["id"], provider: slug, metadata: { owned_by: m["owned_by"] }) }
      end

      def parse_error(response)
        body = response.body rescue nil
        body&.dig("error", "message") || body&.dig("error", "code")
      end

      class << self
        def capabilities
          { chat: true, streaming: true, tool_calls: true, vision: true, thinking: true, structured_output: true, embed: true, transcribe: true, paint: true, moderate: true }
        end
        def configuration_options; %i[api_key base_url organization_id project_id]; end
        def configuration_requirements; %i[api_key]; end
        def configured?(config)
          (config.respond_to?(:api_key) && !config.api_key.to_s.empty?) ||
            (config.respond_to?(:openai_api_key) && !config.openai_api_key.to_s.empty?)
        end
      end

      private

      def normalize_config(config)
        return config if !config.is_a?(Hash)
        OpenStruct.new(
          api_key: config[:api_key] || config["api_key"] || config[:openai_api_key],
          base_url: config[:base_url] || config["base_url"],
          organization_id: config[:organization_id] || config["organization_id"],
          project_id: config[:project_id] || config["project_id"]
        )
      end

      def build_http
        LLM::HTTP.connection(api_base, headers: headers, request: { open_timeout: 30, timeout: 120 })
      end

      def build_chat_payload(messages, model, tools, temperature, stream, schema, **params)
        payload = { model: model, messages: format_messages(messages), stream: stream || false }
        payload[:temperature] = temperature if temperature
        payload[:tools] = format_tools(tools) if tools&.any?
        payload[:response_format] = { type: "json_schema", json_schema: { name: "response", schema: schema, strict: true } } if schema
        payload.merge(params)
      end

      def format_messages(messages)
        messages.map do |msg|
          role = msg[:role] || msg["role"] || :user
          { role: role.to_s, content: msg[:content] || msg["content"] }.tap do |fm|
            if (tc = msg[:tool_calls] || msg["tool_calls"])
              fm[:tool_calls] = tc.map { |t| { id: t[:id] || t["id"], type: "function", function: { name: t.dig(:function, :name) || t.dig("function", "name") || t[:name], arguments: t.dig(:function, :arguments) || t.dig("function", "arguments") || t[:arguments] } } }
            end
            fm[:tool_call_id] = msg[:tool_call_id] || msg["tool_call_id"] if msg[:tool_call_id] || msg["tool_call_id"]
          end.compact
        end
      end

      def format_tools(tools)
        tools.map { |t| { type: "function", function: { name: t.respond_to?(:name) ? t.name : t[:name], description: t.respond_to?(:description) ? t.description : t[:description], parameters: t.respond_to?(:parameters) ? t.parameters : t[:parameters] } } }
      end

      def chat_nonstream(payload, model)
        response = @http.post("chat/completions") { |r| r.body = payload }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "OpenAI") unless response.success?
        parse_response(response.body, model)
      end

      def parse_response(body, model)
        choice = body.dig("choices", 0)
        return Ask::Message.new(role: :assistant, content: nil) unless choice
        msg = choice["message"]
        usage = body["usage"] || {}
        Ask::Message.new(role: :assistant, content: msg["content"], tool_calls: parse_tool_calls(msg["tool_calls"]), metadata: { model: body["model"] || model, finish_reason: choice["finish_reason"], input_tokens: usage["prompt_tokens"], output_tokens: usage["completion_tokens"], raw: body })
      end

      def parse_tool_calls(calls)
        return nil unless calls&.any?
        calls.map { |tc| { id: tc["id"], type: "function", name: tc.dig("function", "name"), arguments: tc.dig("function", "arguments") } }
      end

      def chat_stream(payload, model, &block)
        stream = Ask::Stream.new
        @http.post("chat/completions") do |req|
          req.body = payload.merge(stream: true)
          req.options.on_data = proc { |data, _bytes, _env| process_chunk(data, stream, model, &block) }
        end.tap { |resp| raise LLM::HTTP.map_error(resp.status, JSON.parse(resp.body), provider: "OpenAI") unless resp.success? }
        stream.finish!
        stream
      end

      def process_chunk(raw, stream, model)
        raw.each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?(":") || !line.start_with?("data: ")
          data = line[6..]; next if data == "[DONE]"
          parsed = JSON.parse(data) rescue next
          choice = parsed.dig("choices", 0) or next
          delta = choice["delta"] || {}
          chunk = Ask::Chunk.new(content: delta["content"], tool_calls: parse_stream_tool_calls(delta["tool_calls"]), finish_reason: choice["finish_reason"], usage: parsed["usage"])
          stream.add(chunk)
          yield chunk if block_given?
        end
      end

      def parse_stream_tool_calls(calls)
        return nil unless calls&.any?
        calls.map { |tc| { id: tc["id"], name: tc.dig("function", "name"), arguments: tc.dig("function", "arguments"), index: tc["index"] } }
      end
    end
  end
end
