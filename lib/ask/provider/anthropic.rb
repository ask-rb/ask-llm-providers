# frozen_string_literal: true

module Ask
  module Providers
    # Anthropic Claude API provider.
    class Anthropic < Ask::Provider
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
        payload = build_chat_payload(msgs, model, tools, temperature, stream, schema, **params)
        if stream
          chat_stream(payload, model, &block)
        else
          chat_nonstream(payload, model)
        end
      end

      def embed(_texts, model: nil)
        raise Ask::UnsupportedFeature, "Anthropic does not support embeddings"
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
        def capabilities
          { chat: true, streaming: true, tool_calls: true, vision: true, thinking: true, prompt_caching: true, structured_output: true }
        end
        def configuration_options; %i[api_key api_base]; end
        def configuration_requirements; %i[api_key]; end
        def slug; "anthropic"; end
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
        LLM::HTTP.connection(api_base, headers: headers, request: { open_timeout: 30, timeout: 120 })
      end

      def build_chat_payload(messages, model, tools, temperature, stream, schema, **params)
        system_msgs, chat_msgs = messages.partition { |m| (m[:role] || m["role"]).to_s == "system" }
        system_content = format_system_content(system_msgs)
        tools_array = format_tools(tools) if tools&.any?

        payload = {
          model: model,
          messages: chat_msgs.map { |m| format_message(m) },
          max_tokens: params.delete(:max_tokens) || 4096,
          stream: stream || false
        }

        payload[:system] = system_content if system_content
        payload[:tools] = tools_array if tools_array
        payload[:temperature] = temperature if temperature
        payload.merge(params)
      end

      def format_system_content(messages)
        return nil if messages.empty?
        texts = messages.map { |m| m[:content] || m["content"] }.compact
        return nil if texts.empty?
        texts.join("\n")
      end

      def format_message(msg)
        role = (msg[:role] || msg["role"]).to_s
        content = msg[:content] || msg["content"]

        # Handle tool calls
        if msg[:tool_calls] || msg["tool_calls"]
          tc = msg[:tool_calls] || msg["tool_calls"]
          return {
            role: role,
            content: content,
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

        # Handle tool results
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

        { role: role, content: content }.compact
      end

      def parse_json(str)
        JSON.parse(str)
      rescue JSON::ParserError
        {}
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

      def chat_nonstream(payload, model)
        response = @http.post("v1/messages") { |r| r.body = payload }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Anthropic") unless response.success?
        parse_response(response.body, model)
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
          thinking: thinking_blocks.map { |b| b["thinking"] || b["text"] }.compact.join("\n"),
          raw: body
        }.compact

        Ask::Message.new(role: :assistant, content: text_content.empty? ? nil : text_content, tool_calls: tool_calls.empty? ? nil : tool_calls, metadata: metadata)
      end

      def chat_stream(payload, model, &block)
        stream = Ask::Stream.new
        response = @http.post("v1/messages") do |req|
          req.body = payload.merge(stream: true)
          req.options.on_data = proc { |data, _bytes, _env| process_anthropic_chunk(data, stream, model, &block) }
        end
        raise LLM::HTTP.map_error(response.status, JSON.parse(response.body), provider: "Anthropic") unless response.success?
        stream.finish!
        stream
      end

      def process_anthropic_chunk(raw, stream, model)
        raw.each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?(":")
          next unless line.start_with?("event:") || line.start_with?("data:")

          if line.start_with?("data: ")
            data = line[6..]
            begin
              parsed = JSON.parse(data)
            rescue JSON::ParserError
              next
            end

            case parsed["type"]
            when "content_block_delta"
              delta = parsed.dig("delta")
              next unless delta
              chunk = Ask::Chunk.new(
                content: delta["text"],
                finish_reason: delta["type"] == "thinking_delta" ? nil : nil
              )
              stream.add(chunk)
              yield chunk if block_given?
            when "message_stop"
              usage = parsed["usage"] || parsed["message"]&.dig("usage")
              if usage
                chunk = Ask::Chunk.new(finish_reason: "stop", usage: usage)
                stream.add(chunk)
                yield chunk if block_given?
              end
            when "message_start"
              # Message started — no content yet
            end
          end
        end
      end
    end
  end
end
