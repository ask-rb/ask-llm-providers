# frozen_string_literal: true

module Ask
  module Providers
    # OpenAI API provider. Also handles all OpenAI-compatible providers
    # (OpenRouter, DeepSeek, Azure, XAI, Perplexity, GPUStack, etc.) via
    # +base_url+ override.
    class OpenAI < Ask::Provider
      include Ask::LLM::SSEBuffer
      include Ask::LLM::ProviderConfig

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

        # Separate provider tools from regular tools
        regular_tools, provider_tools = split_tools(tools)

        if provider_tools.any?
          # Use the Responses API when provider tools are involved
          responses_chat(msgs, model:, regular_tools:, provider_tools:,
                         temperature:, stream:, schema:, **params, &block)
        else
          payload = build_request(msgs, model:, tools: regular_tools,
                                  temperature:, stream:, schema:, **params)
          stream ? chat_stream(payload, model, &block) : chat_nonstream(payload, model)
        end
      end

      def embed(texts, model:)
        texts = Array(texts)
        response = @http.post("embeddings") { |r| r.body = { model:, input: texts } }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "OpenAI") unless response.success?

        embeddings = response.body["data"].map { |d| d["embedding"] }
        Ask::Result.success(embeddings.one? ? embeddings.first : embeddings)
      end

      def list_models
        response = @http.get("models")
        return [] unless response.success?

        response.body["data"].map { |m|
          Ask::ModelInfo.new(id: m["id"], provider: slug, metadata: { owned_by: m["owned_by"] })
        }
      end

      def parse_error(response)
        body = response.body rescue nil
        body&.dig("error", "message") || body&.dig("error", "code")
      end

      class << self
        def slug; "openai"; end

        def capabilities
          {
            chat: true, streaming: true, tool_calls: true, vision: true,
            thinking: true, structured_output: true, embed: true,
            transcribe: true, paint: true, moderate: true,
            prompt_caching: true
          }
        end

        def configuration_options; %i[api_key base_url organization_id project_id]; end
        def configuration_requirements; %i[api_key]; end
      end

      # --- Config transformation contract ---

      def build_request(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params)
        payload = { model:, messages: format_messages(messages), stream: stream || false }
        payload[:temperature] = temperature if temperature
        payload[:tools] = format_tools(tools) if tools&.any?
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
	            cached_tokens: usage.dig("prompt_tokens_details", "cached_tokens"),
	            raw: body
	          }
	        )
      end

      def parse_stream(raw, stream, model, &block)
        each_sse_event(raw) do |data|
          parsed = JSON.parse(data) rescue next
          choice = parsed.dig("choices", 0) or next
          delta = choice["delta"] || {}
          thinking = extract_thinking(parsed, delta)
          chunk = Ask::Chunk.new(
            content: delta["content"],
            tool_calls: parse_stream_tool_calls(delta["tool_calls"]),
            finish_reason: choice["finish_reason"],
            usage: parsed["usage"],
            thinking:
          )
          stream.add(chunk)
          yield chunk if block_given?
        end
      end

      def split_tools(tools)
        return [[], []] unless tools&.any?

        tools.partition { |t| !t.respond_to?(:provider_tool?) || !t.provider_tool? }
      end

      def format_tools(tools)
        return [] unless tools&.any?

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

      def format_responses_tools(provider_tools)
        provider_tools.map do |pt|
          case pt.name
          when "web_search"
            { type: "web_search" }.merge(pt.args)
          when "file_search"
            { type: "file_search" }.merge(pt.args)
          when "code_interpreter"
            { type: "code_interpreter" }.merge(pt.args)
          else
            { type: pt.name }.merge(pt.args)
          end
        end
      end

      def format_message(msg)
        role = msg[:role] || msg["role"] || :user
        { role: role.to_s, content: msg[:content] || msg["content"] }.tap do |fm|
          if (tc = msg[:tool_calls] || msg["tool_calls"]) && tc.respond_to?(:any?) && tc.any?
            calls = tc.is_a?(Hash) ? tc.values : tc
            fm[:tool_calls] = calls.map { |t|
              id = t.respond_to?(:id) ? t.id : (t[:id] || t["id"])
              name = t.respond_to?(:name) ? t.name : (t.dig(:function, :name) || t.dig("function", "name") || t[:name])
              raw_args = t.respond_to?(:arguments) ? t.arguments : (t.dig(:function, :arguments) || t.dig("function", "arguments") || t[:arguments])
              args = raw_args.is_a?(String) ? raw_args : JSON.generate(raw_args)
              { id:, type: "function", function: { name:, arguments: args } }
            }
          end
          fm[:tool_call_id] = msg[:tool_call_id] || msg["tool_call_id"] if msg[:tool_call_id] || msg["tool_call_id"]
        end.compact
      end

      # Use the OpenAI Responses API, which supports provider-executed tools
      # like web_search, file_search, and code_interpreter.
      def responses_chat(messages, model:, regular_tools:, provider_tools:,
                         temperature: nil, stream: nil, schema: nil, **params, &block)
        payload = {
          model: model,
          input: format_responses_input(messages)
        }

        all_tools = []
        all_tools.concat(format_tools(regular_tools)) if regular_tools&.any?
        all_tools.concat(format_responses_tools(provider_tools)) if provider_tools&.any?
        payload[:tools] = all_tools if all_tools.any?
        payload[:temperature] = temperature if temperature
        payload.merge!(params)

        if stream
          responses_chat_stream(payload, model, provider_tools, &block)
        else
          responses_chat_nonstream(payload, model, provider_tools)
        end
      end

      def responses_chat_nonstream(payload, model, provider_tools)
        response = @http.post("responses") { |r| r.body = payload }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "OpenAI") unless response.success?

        body = response.body
        output = body["output"] || []

        # Extract text content and provider-executed tool results
        text_parts = output.select { |o| o["type"] == "message" }
        content = text_parts.flat_map { |m| (m["content"] || []) }
                            .select { |c| c["type"] == "output_text" }
                            .map { |c| c["text"] }
                            .join

        # Extract provider-executed tool results
        provider_results = extract_responses_provider_results(output, provider_tools)

        # Extract regular tool calls
        regular_calls = extract_responses_tool_calls(output)

        usage = body["usage"] || {}
        Ask::Message.new(
          role: :assistant,
          content: content,
          tool_calls: regular_calls,
          metadata: {
            model: body["model"] || model,
            finish_reason: body.dig("status"),
            input_tokens: usage["input_tokens"],
            output_tokens: usage["output_tokens"],
            provider_results: provider_results,
            raw: body
          }
        )
      end

      def responses_chat_stream(payload, model, provider_tools, &block)
        # Streaming with the Responses API — for now, fall back to non-streaming
        # and return the full result. Full streaming support can be added later.
        responses_chat_nonstream(payload, model, provider_tools)
      end

      def format_responses_input(messages)
        messages.map do |msg|
          role = msg[:role] || msg["role"] || "user"
          content = msg[:content] || msg["content"] || ""

          entry = { role: role.to_s }
          entry[:content] = [{ type: "input_text", text: content.to_s }]

          # Handle tool calls in assistant messages
          if (tc = msg[:tool_calls] || msg["tool_calls"]) && tc.respond_to?(:any?) && tc.any?
            calls = tc.is_a?(Hash) ? tc.values : tc
            entry[:content] = calls.map { |t|
              id = t.respond_to?(:id) ? t.id : (t[:id] || t["id"])
              name = t.respond_to?(:name) ? t.name : (t[:name] || t["name"] || t.dig(:function, :name))
              raw_args = t.respond_to?(:arguments) ? t.arguments : (t[:arguments] || t["arguments"] || t.dig(:function, :arguments))
              args = raw_args.is_a?(String) ? raw_args : JSON.generate(raw_args)
              { type: "function_call", id: id, name: name, arguments: args, status: "completed" }
            }
          end

          # Handle tool results
          if (tid = msg[:tool_call_id] || msg["tool_call_id"])
            entry[:content] = [{ type: "function_call_output", id: tid, output: content.to_s }]
          end

          entry
        end
      end

      def extract_responses_provider_results(output, provider_tools)
        results = {}
        provider_tool_names = provider_tools.map(&:name)

        output.each do |item|
          case item["type"]
          when "web_search_call"
            result_item = output.find { |o| o["type"] == "web_search_result" && o["id"] == item["id"] }
            if result_item
              results[item["id"]] = {
                provider_executed: true,
                tool_name: "web_search",
                message: result_item.to_s,
                status: "success"
              }
            end
          when "file_search_call"
            result_item = output.find { |o| o["type"] == "file_search_result" && o["id"] == item["id"] }
            if result_item
              results[item["id"]] = {
                provider_executed: true,
                tool_name: "file_search",
                message: result_item.to_s,
                status: "success"
              }
            end
          when "function_call"
            # Regular tool call — handled elsewhere
          end
        end
        results
      end

      def extract_responses_tool_calls(output)
        output.select { |o| o["type"] == "function_call" }.map do |fc|
          { id: fc["id"], type: "function", name: fc["name"], arguments: fc["arguments"] }
        end
      end

      private

      def extract_provider_keys(config)
        return {} unless config.is_a?(Hash)

        known = %i[api_key base_url organization_id project_id openai_api_key]
        config.reject { |k, _| known.include?(k.to_sym) }
      end

      def normalize_config(config)
        config = config.to_h if config.respond_to?(:to_h)
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
        LLM::HTTP.connection(api_base, headers:, request: { open_timeout: 30, timeout: 120 })
      end

      def format_messages(messages)
        messages.map { |msg| format_message(msg) }
      end

      def chat_nonstream(payload, model)
        response = @http.post("chat/completions") { |r| r.body = payload }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "OpenAI") unless response.success?

        parse_response(response.body, model)
      end

      def chat_stream(payload, model, &block)
        stream = Ask::Stream.new
        init_sse_buffer
        @http.post("chat/completions") do |req|
          req.body = payload.merge(stream: true)
          req.options.on_data = proc { |data, _bytes, _env| parse_stream(data, stream, model, &block) }
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

      def extract_thinking(parsed, delta)
        delta["reasoning_content"] || delta["thinking"] ||
          parsed.dig("choices", 0, "delta", "reasoning_content") ||
          parsed.dig("choices", 0, "delta", "thinking") ||
          parsed.dig("choices", 0, "reasoning_content")
      end
    end
  end
end
