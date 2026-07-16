# frozen_string_literal: true

module Ask
  module LLM
    # Shared contract for provider request/response transformation.
    #
    # Every provider includes this module and implements the core methods
    # that define its wire format. The provider's {#chat} method orchestrates
    # between building requests, making HTTP calls, and parsing responses.
    #
    # This separation makes each wire-format concern testable in isolation
    # and adding a new provider mechanical — you implement four methods and
    # the provider works.
    module ProviderConfig
      # Build a provider-native request payload from internal message format.
      #
      # @param messages [Array<Hash>] normalized messages with :role, :content,
      #   :tool_calls, :tool_call_id
      # @param model [String] model ID
      # @param tools [Array<Hash>, nil] tool definitions
      # @param temperature [Float, nil] sampling temperature
      # @param stream [Boolean] whether streaming will be used
      # @param schema [Hash, nil] JSON schema for structured output
      # @return [Hash] provider-native request body
      def build_request(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params)
        raise NotImplementedError, "#{self.class} must implement #build_request"
      end

      # Parse a non-streaming response into an Ask::Message.
      #
      # @param body [Hash] parsed response body
      # @param model [String] model ID
      # @return [Ask::Message]
      def parse_response(body, model)
        raise NotImplementedError, "#{self.class} must implement #parse_response"
      end

      # Parse raw stream data and yield Ask::Chunks.
      #
      # @param raw [String] raw data from the stream callback
      # @param stream [Ask::Stream] the accumulating stream
      # @param model [String] model ID
      # @yield [Ask::Chunk] optional per-chunk callback
      def parse_stream(raw, stream, model, &block)
        raise NotImplementedError, "#{self.class} must implement #parse_stream"
      end

      # Format tool definitions for this provider's wire format.
      #
      # @param tools [Array] tool definitions (Ask::Tool instances or Hashes)
      # @return [Array] provider-native tool format
      def format_tools(tools)
        tools
      end

      # Format a single message for this provider's wire format.
      #
      # @param msg [Hash] message with :role, :content, :tool_calls, :tool_call_id
      # @return [Hash] provider-native message format
      def format_message(msg)
        msg
      end
    end
  end
end
