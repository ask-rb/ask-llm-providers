# frozen_string_literal: true

module Ask
  module LLM
    # Shared HTTP infrastructure for all providers.
    module HTTP
      # Build a Faraday connection for a provider.
      def self.connection(base_url, headers: {}, request: {})
        Faraday.new(url: base_url, headers: headers, request: request) do |f|
          f.request :json
          f.response :json, content_type: /\bjson$/
          f.adapter Faraday.default_adapter
        end
      end

      # Map an HTTP exception or error response to the appropriate Ask::Error.
      def self.map_error(status, body, provider:)
        body = JSON.parse(body) rescue body if body.is_a?(String)
        message = extract_error_message(body, status) || "HTTP #{status} from #{provider}"

        # Check for context length exceeded regardless of status code
        err_code = body.respond_to?(:dig) ? body.dig("error", "code") : nil
        if err_code == "context_length_exceeded"
          return Ask::ContextLengthExceeded.new("#{provider}: #{message}")
        end

        case status
        when 400 then Ask::ProviderError.new(message, status_code: status, response_body: body&.to_json)
        when 401, 403 then Ask::Unauthorized.new("#{provider}: #{message}")
        when 429 then Ask::RateLimitError.new("#{provider}: #{message}")
        when 500 then Ask::ServerError.new("#{provider}: #{message}")
        when 503 then Ask::ServiceUnavailable.new("#{provider}: #{message}")
        else Ask::ProviderError.new("#{provider}: #{message}", status_code: status, response_body: body&.to_json)
        end
      end

      # Extract a human-readable error message from various provider error formats.
      def self.extract_error_message(body, status)
        return nil unless body

        if body.respond_to?(:dig)
          body.dig("error", "message") ||
            body.dig("error", "msg") ||
            body.dig("error", "error") ||
            body["message"] ||
            body.to_s
        else
          body.to_s
        end
      end
    end
  end
end
