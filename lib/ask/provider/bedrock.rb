# frozen_string_literal: true

module Ask
  module Providers
    # Amazon Bedrock provider using the Converse API.
    # Uses the AWS SDK for authentication (credentials chain: env, ~/.aws, instance profile).
    class Bedrock < Ask::Provider
      def initialize(config = {})
        config = normalize_config(config)
        super(config)
      end

      def api_base
        @config.region || "us-east-1"
      end

      def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
        msgs = messages.is_a?(Ask::Conversation) ? messages.to_a : messages
        payload = build_converse_payload(msgs, model, tools, temperature, schema, **params)
        if stream
          chat_stream(payload, model, &block)
        else
          chat_nonstream(payload, model)
        end
      end

      def embed(_texts, model: nil)
        raise Ask::UnsupportedFeature, "Bedrock does not support embeddings via Converse API"
      end

      def list_models
        # Bedrock doesn't have a list models endpoint — rely on model catalog
        []
      end

      def parse_error(response)
        response.body["message"] rescue nil
      end

      class << self
        def capabilities
          { chat: true, streaming: true, tool_calls: true, vision: true }
        end
        def configuration_options; %i[region access_key_id secret_access_key session_token]; end
        def configuration_requirements; %i[]; end
        def slug; "bedrock"; end
      end

      private

      def normalize_config(config)
        return config unless config.is_a?(Hash)
        Ask::LLM::Config.new(
          region: config[:region] || config["region"] || ENV["AWS_REGION"] || "us-east-1",
          access_key_id: config[:access_key_id] || config["access_key_id"] || ENV["AWS_ACCESS_KEY_ID"],
          secret_access_key: config[:secret_access_key] || config["secret_access_key"] || ENV["AWS_SECRET_ACCESS_KEY"],
          session_token: config[:session_token] || config["session_token"] || ENV["AWS_SESSION_TOKEN"]
        )
      end

      def build_converse_payload(messages, model, tools, temperature, schema, **params)
        system_msgs, chat_msgs = messages.partition { |m| (m[:role] || m["role"]).to_s == "system" }
        payload = {
          modelId: model,
          messages: chat_msgs.map { |m| format_bedrock_msg(m) },
          inferenceConfig: { temperature: temperature || 1.0 }.compact
        }

        sys = system_msgs.map { |m| m[:content] || m["content"] }.compact
        payload[:system] = sys.map { |s| { text: s } } if sys.any?
        if tools&.any?
          payload[:toolConfig] = { tools: format_bedrock_tools(tools) }
        end
        if schema
          payload[:inferenceConfig][:response_type] = "json_object"
        end
        payload.merge(params)
      end

      def format_bedrock_msg(msg)
        role = (msg[:role] || msg["role"]).to_s
        content = msg[:content] || msg["content"]
        bedrock_role = role == "assistant" ? "assistant" : "user"
        parts = []

        parts << { text: content } if content

        if msg[:tool_calls] || msg["tool_calls"]
          (msg[:tool_calls] || msg["tool_calls"]).each do |tc|
            parts << {
              toolUse: {
                toolUseId: tc[:id] || tc["id"],
                name: tc.dig(:function, :name) || tc.dig("function", "name") || tc[:name],
                input: parse_json(tc.dig(:function, :arguments) || tc.dig("function", "arguments") || tc[:arguments] || "{}")
              }
            }
          end
        end

        if msg[:tool_call_id] || msg["tool_call_id"]
          parts << {
            toolResult: {
              toolUseId: msg[:tool_call_id] || msg["tool_call_id"],
              content: [{ text: content || "" }]
            }
          }
          bedrock_role = "user"
        end

        { role: bedrock_role, content: parts }
      end

      def format_bedrock_tools(tools)
        tools.map do |t|
          { toolSpec: { name: t.respond_to?(:name) ? t.name : t[:name], description: t.respond_to?(:description) ? t.description : t[:description], inputSchema: { json: t.respond_to?(:parameters) ? t.parameters : (t[:parameters] || { type: "object", properties: {} }) } } }
        end
      end

      def parse_json(str)
        JSON.parse(str)
      rescue JSON::ParserError
        {}
      end

      def bedrock_client
        require "aws-sdk-bedrockruntime"
        Aws::BedrockRuntime::Client.new(region: @config.region)
      end

      def chat_nonstream(payload, model)
        client = bedrock_client
        resp = client.converse(payload)
        parse_bedrock_response(resp, model)
      rescue Aws::Errors::ServiceError => e
        raise LLM::HTTP.map_error(e.status_code&.to_i || 500, { message: e.message }, provider: "Bedrock")
      end

      def parse_bedrock_response(resp, model)
        output = resp.output
        return Ask::Message.new(role: :assistant, content: nil) unless output

        msg = output.message
        text = msg.content&.map { |c| c.text }&.compact&.join
        tool_uses = msg.content&.select { |c| c.tool_use } || []
        tool_calls = tool_uses.map do |tu|
          { id: tu.tool_use.tool_use_id, type: "function", name: tu.tool_use.name, arguments: JSON.generate(tu.tool_use.input.to_h) }
        end

        usage = resp.usage || {}
        Ask::Message.new(role: :assistant, content: text, tool_calls: tool_calls.empty? ? nil : tool_calls, metadata: { model: model, stop_reason: resp.stop_reason, input_tokens: usage.input_tokens, output_tokens: usage.output_tokens, raw: resp.to_h })
      end

      def chat_stream(payload, model, &block)
        client = bedrock_client
        stream = Ask::Stream.new
        resp = client.converse_stream(payload)
        resp.stream.each do |event|
          if event.content_block_delta
            delta = event.content_block_delta.delta
            chunk = Ask::Chunk.new(content: delta.text) if delta.respond_to?(:text)
            if chunk
              stream.add(chunk)
              yield chunk if block_given?
            end
          end
          if event.message_stop
            usage = event.message_stop.usage || {}
            chunk = Ask::Chunk.new(finish_reason: "stop", usage: { input_tokens: usage.input_tokens, output_tokens: usage.output_tokens })
            stream.add(chunk)
            yield chunk if block_given?
          end
        end
        stream.finish!
        stream
      rescue Aws::Errors::ServiceError => e
        raise LLM::HTTP.map_error(e.status_code&.to_i || 500, { message: e.message }, provider: "Bedrock")
      end
    end
  end
end
