# frozen_string_literal: true

module Ask
  module LLM
    # Simple config wrapper without requiring ostruct.
    # Wraps a hash and provides method-based access.
    class Config
      def initialize(hash = {})
        @hash = (hash || {}).transform_keys(&:to_sym)
        # Also accept string keys
        hash.each { |k, v| @hash[k.to_sym] = v if k.is_a?(String) }
      end

      def method_missing(name, *args, &block)
        if name.to_s.end_with?("=")
          @hash[name.to_s.chomp("=").to_sym] = args.first
        elsif args.empty?
          @hash.key?(name) ? @hash[name] : nil
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        @hash.key?(name.to_s.sub(/=$/, "").to_sym) || super
      end

      def to_h
        @hash.dup
      end
    end
  end
end
