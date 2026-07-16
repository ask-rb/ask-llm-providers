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
      #
      # @param status [Integer] HTTP status code
      # @param body [Hash, String, nil] response body
      # @param provider [String] provider name for error messages
      # @param headers [Hash, nil] response headers (for retry-after etc.)
      # @return [Ask::Error]
      def self.map_error(status, body, provider:, headers: nil)
        body = JSON.parse(body) rescue body if body.is_a?(String)
        message = extract_error_message(body, status) || "HTTP #{status} from #{provider}"

        # Check for context length exceeded regardless of status code
        err_code = body.respond_to?(:dig) ? body.dig("error", "code") : nil
        if err_code == "context_length_exceeded"
          return Ask::ContextLengthExceeded.new("#{provider}: #{message}")
        end

        case status
        when 400
          Ask::ProviderError.new(message, status_code: status, response_body: body&.to_json)
        when 401, 403
          Ask::Unauthorized.new("#{provider}: #{message}")
        when 429
          retry_after = extract_retry_after(headers)
          rate_limit_type = detect_rate_limit_type(body)
          Ask::RateLimitError.new(
            "#{provider}: #{message}",
            category: Ask::RateLimitCategory::VENDOR,
            rate_limit_type: rate_limit_type,
            retry_after: retry_after
          )
        when 500
          Ask::ServerError.new("#{provider}: #{message}")
        when 503
          Ask::ServiceUnavailable.new("#{provider}: #{message}")
        else
          Ask::ProviderError.new("#{provider}: #{message}", status_code: status, response_body: body&.to_json)
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

      # Extract retry_after from response headers.
      # Providers send Retry-After as seconds (integer) or HTTP-date.
      # @param headers [Hash, nil]
      # @return [Integer, nil]
      def self.extract_retry_after(headers)
        return nil unless headers.is_a?(Hash)

        raw = headers["retry-after"] || headers["Retry-After"] || headers["retry_after"]
        return nil unless raw

        int = Integer(raw) rescue nil
        return int if int

        Time.parse(raw) - Time.now rescue nil
      end

      # Detect rate limit type from error body.
      # @param body [Hash, nil]
      # @return [Symbol, nil]
      def self.detect_rate_limit_type(body)
        return nil unless body.respond_to?(:dig)

        msg = body.dig("error", "message") || body.dig("error", "code") || ""
        msg_lower = msg.to_s.downcase

        return Ask::RateLimitType::BUDGET if msg_lower.include?("budget") || msg_lower.include?("quota")
        return Ask::RateLimitType::TOKENS if msg_lower.include?("token") || msg_lower.include?("tpm")
        return Ask::RateLimitType::CONCURRENT if msg_lower.include?("concurrent") || msg_lower.include?("parallel")
        Ask::RateLimitType::REQUESTS
      end
    end
  end
end
