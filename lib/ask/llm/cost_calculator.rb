# frozen_string_literal: true

module Ask
  module LLM
    # Calculate LLM API costs from model pricing data.
    module CostCalculator
      MILLION = 1_000_000

      class << self
        # Calculate total cost in USD for a model invocation.
        #
        # @param model [Ask::ModelInfo, #pricing] the model or a pricing hash
        # @param input_tokens [Integer]
        # @param output_tokens [Integer]
        # @param cache_read_tokens [Integer]
        # @param cache_write_tokens [Integer]
        # @param reasoning_tokens [Integer]
        # @param audio_input_tokens [Integer]
        # @param audio_output_tokens [Integer]
        # @param tier [Symbol] pricing tier (:standard or :batch)
        # @return [Float, nil] cost in USD, or nil if no pricing data
        def calculate(model, input_tokens: 0, output_tokens: 0,
                      cache_read_tokens: 0, cache_write_tokens: 0,
                      reasoning_tokens: 0,
                      audio_input_tokens: 0, audio_output_tokens: 0,
                      tier: :standard)
          pricing = extract_pricing(model)
          return nil unless pricing

          rates = pricing.dig(:text_tokens, tier) or return nil

          sum = cost(input_tokens, rates[:input_per_million])
          sum += cost(output_tokens, rates[:output_per_million])
          sum += cost(cache_read_tokens, rates[:cache_read_input_per_million])
          sum += cost(cache_write_tokens, rates[:cache_write_input_per_million])

          if reasoning_tokens > 0
            rate = rates[:reasoning_output_per_million] || rates[:output_per_million]
            sum += cost(reasoning_tokens, rate)
          end

          if audio_input_tokens > 0 || audio_output_tokens > 0
            audio = pricing.dig(:audio_tokens, tier)
            sum += cost(audio_input_tokens, audio[:input_per_million]) if audio
            sum += cost(audio_output_tokens, audio[:output_per_million]) if audio
          end

          sum
        end

        # Per-million rates for quick display.
        #
        # @param model [Ask::ModelInfo, #pricing]
        # @param tier [Symbol] (:standard or :batch)
        # @return [Hash, nil]
        def per_million(model, tier: :standard)
          pricing = extract_pricing(model)
          return nil unless pricing

          rates = pricing.dig(:text_tokens, tier) or return nil

          {
            input: rates[:input_per_million],
            output: rates[:output_per_million],
            cache_read: rates[:cache_read_input_per_million],
            cache_write: rates[:cache_write_input_per_million],
            reasoning: rates[:reasoning_output_per_million]
          }.compact
        end

        # Per-component cost breakdown.
        #
        # @return [Hash, nil]
        def breakdown(model, input_tokens: 0, output_tokens: 0,
                      cache_read_tokens: 0, cache_write_tokens: 0,
                      reasoning_tokens: 0,
                      audio_input_tokens: 0, audio_output_tokens: 0,
                      tier: :standard)
          pricing = extract_pricing(model)
          return nil unless pricing

          rates = pricing.dig(:text_tokens, tier) or return nil

          result = {
            input: cost(input_tokens, rates[:input_per_million]),
            output: cost(output_tokens, rates[:output_per_million]),
            cache_read: cost(cache_read_tokens, rates[:cache_read_input_per_million]),
            cache_write: cost(cache_write_tokens, rates[:cache_write_input_per_million]),
            reasoning: cost(reasoning_tokens, rates[:reasoning_output_per_million] || rates[:output_per_million])
          }.compact

          if audio_input_tokens > 0 || audio_output_tokens > 0
            audio = pricing.dig(:audio_tokens, tier)
            result[:audio_input] = cost(audio_input_tokens, audio[:input_per_million]) if audio
            result[:audio_output] = cost(audio_output_tokens, audio[:output_per_million]) if audio
          end

          result
        end

        private

        def extract_pricing(model)
          model.respond_to?(:pricing) ? model.pricing : model
        end

        def cost(tokens, rate)
          return 0.0 unless rate && tokens > 0
          (tokens * rate) / MILLION.to_f
        end
      end
    end
  end
end
