# frozen_string_literal: true

module Ask
  module LLM
    # Shared HTTP infrastructure for all providers.
    # Handles Faraday connection setup, streaming SSE, and error mapping.
    module HTTP
      # Build a Faraday connection for a provider.
      # @param base_url [String] API base URL
      # @param headers [Hash] default headers
      # @param request [Hash] request options (timeout, etc.)
      # @return [Faraday::Connection]
      def self.connection(base_url, headers: {}, request: {})
        Faraday.new(url: base_url, headers: headers, request: request) do |f|
          f.request :json
          f.response :json, content_type: /\bjson$/
          f.adapter Faraday.default_adapter
        end
      end

      # Parse an SSE stream from a Faraday response.
      # Yields parsed JSON data from each SSE event.
      # @param response [Faraday::Response] the streaming response
      # @yield [Hash] parsed JSON data from the event
      def self.each_sse_event(response, &block)
        response.body.each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?(":")

          if line.start_with?("data: ")
            data = line[6..]
            next if data == "[DONE]"

            yield JSON.parse(data)
          end
        end
      end

      # Map an HTTP exception or error response to the appropriate Ask::Error.
      # @param status [Integer] HTTP status code
      # @param body [Hash, nil] parsed response body
      # @param provider [String] provider name for error messages
      # @return [Ask::Error]
      def self.map_error(status, body, provider:)
        message = extract_error_message(body, status) || "HTTP #{status} from #{provider}"

        case status
        when 400 then Ask::ProviderError.new(message, status_code: status, response_body: body&.to_json)
        when 401, 403 then Ask::Unauthorized.new("#{provider}: #{message}")
        when 429 then Ask::RateLimitError.new("#{provider}: #{message}")
        when 500 then Ask::ServerError.new("#{provider}: #{message}")
        when 503 then Ask::ServiceUnavailable.new("#{provider}: #{message}")
        else
          if body&.dig("error", "code") == "context_length_exceeded"
            Ask::ContextLengthExceeded.new("#{provider}: #{message}")
          else
            Ask::ProviderError.new("#{provider}: #{message}", status_code: status, response_body: body&.to_json)
          end
        end
      end

      # Extract a human-readable error message from various provider error formats.
      def self.extract_error_message(body, status)
        return nil unless body

        body.dig("error", "message") ||
          body.dig("error", "msg") ||
          body.dig("error", "error") ||
          body.dig("message") ||
          body.to_s
      end

      # Make a streaming POST request and yield parsed Ask::Chunks.
      # @param conn [Faraday::Connection] the HTTP connection
      # @param path [String] API path (e.g. "/v1/chat/completions")
      # @param payload [Hash] request body
      # @yield [Ask::Chunk] streaming chunks
      # @return [Ask::Stream] accumulated stream
      def self.streaming_post(conn, path, payload, &block)
        stream = Ask::Stream.new
        response = conn.post(path, payload.merge(stream: true)) do |req|
          req.options.on_data = proc do |chunk, _bytes, _env|
            chunk.each_line do |line|
              line = line.strip
              next if line.empty? || line.start_with?(":")

              if line.start_with?("data: ")
                data = line[6..]
                next if data == "[DONE]"

                begin
                  parsed = JSON.parse(data)
                  yield parsed if block
                rescue JSON::ParserError
                  # Skip malformed lines
                end
              end
            end
          end
        end

        stream.finish!
        stream
      end
    end
  end
end
