# frozen_string_literal: true

require_relative "openai"
require_relative "../llm/sse_buffer"

module Ask
  module Providers
    # OpenAI Codex — requests routed through a ChatGPT subscription via OAuth
    # (the access token + account id come from ask-auth's OpenaiCodex
    # provider, passed explicitly by the host app: api_key / account_id).
    #
    # Always speaks the Responses API at
    # chatgpt.com/backend-api/codex/responses, and streams the Responses SSE
    # event shape (response.output_text.delta, function_call item events,
    # response.completed) — the chat/completions parsing in the base class
    # doesn't apply here.
    class OpenaiCodex < OpenAI
      API_BASE = "https://chatgpt.com/backend-api/codex"
      SLUG = "openai_codex"

      def self.slug
        SLUG
      end

      def api_base
        @config.base_url || API_BASE
      end

      def headers
        super.tap do |h|
          h["ChatGPT-Account-Id"] = @config.account_id if @config.account_id
        end
      end

      def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
        msgs = messages.is_a?(Ask::Conversation) ? messages.to_a : messages
        regular_tools, = split_tools(tools)

        payload = {
          model: model,
          input: format_responses_input(msgs)
        }
        payload[:tools] = format_tools(regular_tools) if regular_tools&.any?
        payload[:temperature] = temperature if temperature
        payload.merge!(params)

        if stream
          codex_stream(payload, model, &block)
        else
          responses_chat_nonstream(payload, model, [])
        end
      end

      private

      def codex_stream(payload, model, &block)
        stream = Ask::Stream.new
        init_sse_buffer
        @http.post("responses") do |req|
          req.body = payload.merge(stream: true)
          req.options.on_data = proc { |data, _bytes, _env| parse_codex_stream(data, stream, model, &block) }
        end.tap do |resp|
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
        end
        stream.finish!
        stream
      end

      # Responses-API SSE events:
      #   response.output_text.delta          -> text content
      #   response.output_item.added          -> function_call id/name
      #   response.function_call_arguments.delta -> tool-call argument fragment
      #   response.completed                  -> usage + finish status
      def parse_codex_stream(raw, stream, model, &block)
        each_sse_event(raw) do |data|
          parsed = JSON.parse(data) rescue next
          chunk =
            case parsed["type"]
            when "response.output_text.delta"
              Ask::Chunk.new(content: parsed["delta"])
            when "response.output_item.added"
              item = parsed["item"] || {}
              next unless item["type"] == "function_call"

              Ask::Chunk.new(tool_calls: [{index: 0, id: item["id"], name: item["name"]}])
            when "response.function_call_arguments.delta"
              Ask::Chunk.new(tool_calls: [{index: 0, arguments: parsed["arguments"]}])
            when "response.completed"
              response = parsed["response"] || {}
              usage = response["usage"] || {}
              Ask::Chunk.new(
                content: nil,
                finish_reason: response["status"],
                usage: {input_tokens: usage["input_tokens"], output_tokens: usage["output_tokens"]}
              )
            end
          next unless chunk

          stream.add(chunk)
          yield chunk if block_given?
        end
      end
    end
  end
end
