# frozen_string_literal: true

module Ask
  module Providers
    # OpenAI API provider. Also handles all OpenAI-compatible providers
    # (OpenRouter, DeepSeek, Azure, XAI, Perplexity, GPUStack, etc.) via
    # +base_url+ override.
    class OpenAI < Ask::Provider
      include Ask::LLM::SSEBuffer
      def initialize(config = {})
        @provider_keys = extract_provider_keys(config)
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
        def slug; "openai"; end
        def capabilities
          { chat: true, streaming: true, tool_calls: true, vision: true, thinking: true, structured_output: true, embed: true, transcribe: true, paint: true, moderate: true }
        end
        def configuration_options; %i[api_key base_url organization_id project_id]; end
        def configuration_requirements; %i[api_key]; end
        def assume_models_exist?; false; end
      end

      private

      # Extract and store any provider-specific config keys (e.g., opencode_api_key).
      # These are not part of the standard OpenAI config but are used by subclasses.
      def extract_provider_keys(config)
        return {} unless config.is_a?(Hash)
        known = %i[api_key base_url organization_id project_id openai_api_key]
        config.reject { |k, _| known.include?(k.to_sym) }
      end

      # Resolve provider config from passed options, env vars, and ask-auth chain.
      def normalize_config(config)
        return config if !config.is_a?(Hash)

        slug = self.class.slug
        auth_key = Ask::Auth.resolve(:"#{slug}_api_key") rescue nil

        merged = {
          api_key: config[:api_key] || config["api_key"] ||
                   config[:"#{slug}_api_key"] || config[:openai_api_key] ||
                   auth_key,
          base_url: config[:base_url] || config["base_url"] ||
                    ENV["#{slug.upcase}_API_BASE"],
          organization_id: config[:organization_id] || config["organization_id"],
          project_id: config[:project_id] || config["project_id"]
        }.merge(config.reject { |k, _| %i[api_key base_url organization_id project_id openai_api_key].include?(k.to_sym) })

        Ask::LLM::Config.new(merged)
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
              calls = tc.is_a?(Hash) ? tc.values : tc
              fm[:tool_calls] = calls.map { |t|
                id = t.respond_to?(:id) ? t.id : (t[:id] || t["id"])
                name = t.respond_to?(:name) ? t.name : (t.dig(:function, :name) || t.dig("function", "name") || t[:name])
                raw_args = t.respond_to?(:arguments) ? t.arguments : (t.dig(:function, :arguments) || t.dig("function", "arguments") || t[:arguments])
                args = raw_args.is_a?(String) ? raw_args : JSON.generate(raw_args)
                { id: id, type: "function", function: { name: name, arguments: args } }
              }
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
        init_sse_buffer
        @http.post("chat/completions") do |req|
          req.body = payload.merge(stream: true)
          req.options.on_data = proc { |data, _bytes, _env| process_chunk(data, stream, model, &block) }
        end.tap { |resp|
          unless resp.success?
            err_body = case resp.body
            when Hash then resp.body
            when String then (JSON.parse(resp.body) rescue { "error" => { "message" => "HTTP #{resp.status}: #{resp.body[0..200]}" } })
            else { "error" => { "message" => "HTTP #{resp.status}: empty response body" } }
            end
            err_body["error"] ||= {}
            err_body["error"]["_status"] = resp.status
            raise LLM::HTTP.map_error(resp.status, err_body, provider: "OpenAI")
          end
        }
        stream.finish!
        stream
      end

      def process_chunk(raw, stream, model)
        each_sse_event(raw) do |data|
          parsed = JSON.parse(data) rescue next
          choice = parsed.dig("choices", 0) or next
          delta = choice["delta"] || {}
          thinking = extract_thinking(parsed, delta)
          chunk = Ask::Chunk.new(content: delta["content"], tool_calls: parse_stream_tool_calls(delta["tool_calls"]), finish_reason: choice["finish_reason"], usage: parsed["usage"], thinking: thinking)
          stream.add(chunk)
          yield chunk if block_given?
        end
      end

      # Extract thinking/reasoning content from provider response.
      # Some providers (Anthropic, DeepSeek) send thinking in a separate field.
      def extract_thinking(parsed, delta)
        delta["reasoning_content"] || delta["thinking"] ||
          parsed.dig("choices", 0, "delta", "reasoning_content") ||
          parsed.dig("choices", 0, "delta", "thinking") ||
          parsed.dig("choices", 0, "reasoning_content")
      end

      def parse_stream_tool_calls(calls)
        return nil unless calls&.any?
        calls.map { |tc| { id: tc["id"], name: tc.dig("function", "name"), arguments: tc.dig("function", "arguments"), index: tc["index"] } }
      end
    end
  end
end
