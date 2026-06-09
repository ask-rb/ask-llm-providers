# frozen_string_literal: true

module Ask
  module Providers
    # Google Gemini API provider. Also supports Vertex AI via GCP service account auth.
    class Google < Ask::Provider
      def initialize(config = {})
        config = normalize_config(config)
        super(config)
        @http = build_http
        @project_id = config.project_id
      end

      def api_base
        @config.api_base || "https://generativelanguage.googleapis.com/v1beta"
      end

      def headers
        h = { "Content-Type" => "application/json" }
        if @config.api_key
          # Gemini uses query param auth by default
        elsif @config.access_token
          h["Authorization"] = "Bearer #{@config.access_token}"
        elsif @config.vertex_token
          h["Authorization"] = "Bearer #{@config.vertex_token}"
        end
        h
      end

      def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
        msgs = messages.is_a?(Ask::Conversation) ? messages.to_a : messages
        payload = build_chat_payload(msgs, model, tools, temperature, stream, schema, **params)
        path = chat_path(model)
        if stream
          chat_stream(path, payload, model, &block)
        else
          chat_nonstream(path, payload, model)
        end
      end

      def embed(texts, model:)
        texts = Array(texts)
        response = @http.post("models/#{model}:batchEmbedContents") { |r| r.body = { requests: texts.map { |t| { model: "models/#{model}", content: { parts: [{ text: t }] } } } } }
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Google") unless response.success?
        embeddings = response.body.dig("embeddings") || []
        Ask::Result.success(embeddings.map { |e| e["values"] })
      end

      def list_models
        response = @http.get("models") { |r| r.params["key"] = @config.api_key if @config.api_key }
        return [] unless response.success?
        (response.body["models"] || []).map { |m| Ask::ModelInfo.new(id: m["name"].sub("models/", ""), provider: slug) }
      end

      def parse_error(response)
        body = response.body rescue nil
        body&.dig("error", "message")
      end

      class << self
        def capabilities
          { chat: true, streaming: true, tool_calls: true, vision: true, structured_output: true, embed: true, file_upload: true }
        end
        def configuration_options; %i[api_key access_token vertex_token project_id api_base]; end
        def configuration_requirements; %i[api_key]; end
      end

      private

      def normalize_config(config)
        return config unless config.is_a?(Hash)
        key = config[:api_key] || config["api_key"] || config[:gemini_api_key]
        OpenStruct.new(
          api_key: key,
          access_token: config[:access_token] || config["access_token"],
          vertex_token: config[:vertex_token] || config["vertex_token"],
          project_id: config[:project_id] || config["project_id"],
          api_base: config[:api_base] || config["api_base"]
        )
      end

      def build_http
        LLM::HTTP.connection(api_base, headers: headers, request: { open_timeout: 30, timeout: 120 })
      end

      def chat_path(model)
        model_id = model.respond_to?(:id) ? model.id : model.to_s
        "models/#{model_id}:generateContent"
      end

      def build_chat_payload(messages, model, tools, temperature, stream, schema, **params)
        contents = format_contents(messages)
        payload = { contents: contents, systemInstruction: format_system(messages) }

        if tools&.any?
          payload[:tools] = [{ functionDeclarations: tools.map { |t| format_tool(t) } }]
        end
        if schema
          payload[:generationConfig] ||= {}
          payload[:generationConfig][:response_mime_type] = "application/json"
          payload[:generationConfig][:response_schema] = schema
        end
        payload[:generationConfig] ||= {}
        payload[:generationConfig][:temperature] = temperature if temperature
        payload.merge(params)
      end

      def format_contents(messages)
        messages.reject { |m| (m[:role] || m["role"]).to_s == "system" }.map { |m| format_content(m) }
      end

      def format_system(messages)
        sys = messages.select { |m| (m[:role] || m["role"]).to_s == "system" }
        return nil if sys.empty?
        texts = sys.map { |m| m[:content] || m["content"] }.compact
        return nil if texts.empty?
        { parts: texts.map { |t| { text: t } } }
      end

      def format_content(msg)
        role = (msg[:role] || msg["role"]).to_s
        content = msg[:content] || msg["content"]
        google_role = role == "assistant" ? "model" : role

        parts = []
        parts << { text: content } if content

        # Handle tool calls
        if msg[:tool_calls] || msg["tool_calls"]
          (msg[:tool_calls] || msg["tool_calls"]).each do |tc|
            parts << {
              functionCall: {
                name: tc.dig(:function, :name) || tc.dig("function", "name") || tc[:name],
                args: parse_json(tc.dig(:function, :arguments) || tc.dig("function", "arguments") || tc[:arguments] || "{}")
              }
            }
          end
        end

        # Handle tool results
        if msg[:tool_call_id] || msg["tool_call_id"]
          parts << {
            functionResponse: {
              name: msg[:name] || msg["name"] || "function",
              response: { content: content || "" }
            }
          }
        end

        { role: google_role, parts: parts }
      end

      def format_tool(t)
        { name: t.respond_to?(:name) ? t.name : t[:name], description: t.respond_to?(:description) ? t.description : t[:description], parameters: t.respond_to?(:parameters) ? t.parameters : (t[:parameters] || {}) }
      end

      def parse_json(str)
        JSON.parse(str)
      rescue JSON::ParserError
        {}
      end

      def chat_nonstream(path, payload, model)
        response = @http.post(path) do |req|
          req.body = payload
          req.params["key"] = @config.api_key if @config.api_key
        end
        raise LLM::HTTP.map_error(response.status, response.body, provider: "Google") unless response.success?
        parse_response(response.body, model)
      end

      def parse_response(body, model)
        candidate = body.dig("candidates", 0)
        return Ask::Message.new(role: :assistant, content: nil) unless candidate

        content = candidate.dig("content", "parts")&.map { |p| p["text"] }&.compact&.join
        fc = candidate.dig("content", "parts")&.select { |p| p["functionCall"] } || []
        tool_calls = fc.map do |p|
          f = p["functionCall"]
          { id: SecureRandom.hex(8), type: "function", name: f["name"], arguments: JSON.generate(f["args"] || {}) }
        end

        usage = body["usageMetadata"] || {}
        Ask::Message.new(role: :assistant, content: content, tool_calls: tool_calls.empty? ? nil : tool_calls, metadata: { model: model, finish_reason: candidate["finishReason"], input_tokens: usage["promptTokenCount"], output_tokens: usage["candidatesTokenCount"], raw: body })
      end

      def chat_stream(path, payload, model, &block)
        stream = Ask::Stream.new
        response = @http.post(path) do |req|
          req.body = payload
          req.params["key"] = @config.api_key if @config.api_key
          req.options.on_data = proc { |data, _bytes, _env| process_google_chunk(data, stream, model, &block) }
        end
        raise LLM::HTTP.map_error(response.status, JSON.parse(response.body), provider: "Google") unless response.success?
        stream.finish!
        stream
      end

      def process_google_chunk(raw, stream, model)
        raw.each_line do |line|
          next unless line.start_with?("data: ")
          data = line[6..]
          next if data.strip == "[DONE]"
          parsed = JSON.parse(data) rescue next
          candidate = parsed.dig("candidates", 0) or next
          part = candidate.dig("content", "parts", 0)
          next unless part
          chunk = Ask::Chunk.new(content: part["text"])
          stream.add(chunk)
          yield chunk if block_given?
        end
      end
    end
  end
end
