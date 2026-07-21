# frozen_string_literal: true

module Ask
  module Providers
    # Anthropic Claude API provider.
    class Anthropic < Ask::Provider
      include Ask::LLM::SSEBuffer
      include Ask::LLM::ProviderConfig

      def initialize(config = {})
        config = normalize_config(config)
        super(config)
        @http = build_http
      end

      def api_base
        @config.api_base || "https://api.anthropic.com"
      end

      def headers
        {
          "x-api-key" => @config.api_key,
          "anthropic-version" => "2023-06-01",
          "Content-Type" => "application/json"
        }
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

      def embed(_texts, model: nil)
        raise Ask::CapabilityNotSupported, "Anthropic does not support embeddings"
      end

      def list_models
        response = @http.get("v1/models")
        return [] unless response.success?

        response.body["data"].map { |m| Ask::ModelInfo.new(id: m["id"], provider: slug) }
      end

      def parse_error(response)
        body = response.body rescue nil
        body&.dig("error", "message") || body&.dig("error", "type")
      end

      class << self
        def slug; "anthropic"; end

        def capabilities
          {
            chat: true, streaming: true, tool_calls: true, vision: true,
            thinking: true, prompt_caching: true, structured_output: true
          }
        end

        def configuration_options; %i[api_key api_base]; end
        def configuration_requirements; %i[api_key]; end
      end

      # --- Config transformation contract ---

      def build_request(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params)
        system_msgs, chat_msgs = messages.partition { |m| (m[:role] || m["role"]).to_s == "system" }
        prompt_caching = params.delete(:prompt_caching) || false

        payload = {
          model:,
          messages: chat_msgs.map { |m| format_message(m) },
          max_tokens: params.delete(:max_tokens) || 4096,
          stream: stream || false
        }

        if prompt_caching
          payload[:system] = format_system_with_caching(system_msgs, chat_msgs)
          # Mark the last user message for caching (required by Anthropic for conversation caching)
          if payload[:messages].any?
            last_user_idx = payload[:messages].rindex { |m| m[:role] == "user" }
            if last_user_idx
              content = payload[:messages][last_user_idx][:content]
              payload[:messages][last_user_idx][:content] = wrap_content_for_caching(content)
            end
          end
        else
          system_content = format_system_content(system_msgs)
          payload[:system] = system_content if system_content
        end

        tool_defs = format_tools(tools) if tools&.any?
        payload[:tools] = tool_defs if tool_defs
        payload[:temperature] = temperature if temperature
        payload.merge(params)
      end

      def parse_response(body, model)
        content_blocks = body["content"] || []
        text_content = content_blocks.select { |c| c["type"] == "text" }.map { |c| c["text"] }.join
        tool_blocks = content_blocks.select { |c| c["type"] == "tool_use" }
        thinking_blocks = content_blocks.select { |c| %w[thinking redacted_thinking].include?(c["type"]) }
        usage = body["usage"] || {}

        tool_calls = tool_blocks.map do |tb|
          { id: tb["id"], type: "function", name: tb["name"], arguments: JSON.generate(tb["input"]) }
        end

        metadata = {
          model: body["model"] || model,
          stop_reason: body["stop_reason"],
          stop_sequence: body["stop_sequence"],
          input_tokens: usage["input_tokens"],
          output_tokens: usage["output_tokens"],
          cache_creation_input_tokens: usage["cache_creation_input_tokens"],
          cache_read_input_tokens: usage["cache_read_input_tokens"],
          thinking: thinking_blocks.map { |b| b["thinking"] || b["text"] }.compact.join("\n"),
          raw: body
        }.compact

        text = text_content.empty? ? nil : text_content
        Ask::Message.new(role: :assistant, content: text, tool_calls: tool_calls.empty? ? nil : tool_calls, metadata:)
      end

      def parse_stream(raw, stream, model, &block)
        each_sse_event(raw) do |data|
          parsed = JSON.parse(data) rescue next

          case parsed["type"]
          when "content_block_delta"
            delta = parsed.dig("delta")
            next unless delta

            chunk = Ask::Chunk.new(content: delta["text"])
            stream.add(chunk)
            yield chunk if block_given?
          when "message_stop"
            usage = parsed["usage"] || parsed["message"]&.dig("usage")
            if usage
              chunk = Ask::Chunk.new(finish_reason: "stop", usage:)
              stream.add(chunk)
              yield chunk if block_given?
            end
          when "message_start"
            # Handled by content_block_start instead
          end
        end
      end

      def format_tools(tools)
        tools.map do |t|
          {
            name: t.respond_to?(:name) ? t.name : t[:name],
            description: t.respond_to?(:description) ? t.description : t[:description],
            input_schema: t.respond_to?(:parameters) ? t.parameters : (t[:parameters] || { type: "object", properties: {} })
          }
        end
      end

      def format_message(msg)
        role = (msg[:role] || msg["role"]).to_s
        content = msg[:content] || msg["content"]

        if msg[:tool_calls] || msg["tool_calls"]
          tc = msg[:tool_calls] || msg["tool_calls"]
          return {
            role:,
            content:,
            tool_calls: tc.map { |t|
              {
                type: "tool_use",
                id: t[:id] || t["id"],
                name: t.dig(:function, :name) || t.dig("function", "name") || t[:name],
                input: parse_json(t.dig(:function, :arguments) || t.dig("function", "arguments") || t[:arguments] || "{}")
              }
            }.compact
          }.compact
        end

        if msg[:tool_call_id] || msg["tool_call_id"]
          return {
            role: "user",
            content: [{
              type: "tool_result",
              tool_use_id: msg[:tool_call_id] || msg["tool_call_id"],
              content: content || ""
            }]
          }
        end

        { role:, content: }.compact
      end

      private

      def normalize_config(config)
        return config unless config.is_a?(Hash)

        Ask::LLM::Config.new(
          api_key: config[:api_key] || config["api_key"] || config[:anthropic_api_key],
          api_base: config[:api_base] || config["api_base"]
        )
      end

      def build_http
        LLM::HTTP.connection(api_base, headers:, request: { open_timeout: 30, timeout: 120 })
      end

      def format_system_content(messages)
        return nil if messages.empty?

        texts = messages.map { |m| m[:content] || m["content"] }.compact
        return nil if texts.empty?

        texts.join("\n")
      end

      def format_system_with_caching(system_msgs, chat_msgs)
        texts = system_msgs.map { |m| m[:content] || m["content"] }.compact
        return nil if texts.empty?

        combined = texts.join("\n")
        [{ type: "text", text: combined, cache_control: { type: "ephemeral" } }]
      end

      # Wrap the last user message content for caching.
      # Plain strings become [{ type: "text", text: content, cache_control: { type: "ephemeral" } }].
      # Already-structured content blocks get cache_control appended.
      def wrap_content_for_caching(content)
        case content
        when Array
          content.map { |c|
            if c.is_a?(Hash)
              c.merge(cache_control: { type: "ephemeral" })
            else
              { type: "text", text: c.to_s, cache_control: { type: "ephemeral" } }
            end
          }
        else
          [{ type: "text", text: content.to_s, cache_control: { type: "ephemeral" } }]
        end
      end

      def parse_json(str)
        JSON.parse(str)
      rescue JSON::ParserError
        {}
      end

      def chat_nonstream(payload, model)
        response = @http.post("v1/messages") { |r| r.body = payload }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Anthropic") unless response.success?

        parse_response(response.body, model)
      end

      def chat_stream(payload, model, &block)
        stream = Ask::Stream.new
        init_sse_buffer
        response = @http.post("v1/messages") do |req|
          req.body = payload.merge(stream: true)
          req.options.on_data = proc { |data, _bytes, _env| parse_stream(data, stream, model, &block) }
        end
        raise LLM::HTTP.map_error(response.status, JSON.parse(response.body), provider: "Anthropic") unless response.success?

        stream.finish!
        stream
      end
    end
  end
end
