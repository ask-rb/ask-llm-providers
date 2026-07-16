# frozen_string_literal: true

module Ask
  module LLM
    # Calculate LLM API costs from model pricing data.
    #
    # Works with any object responding to +#pricing+ that returns a hash
    # in the standard ask-rb pricing format:
    #
    #   {
    #     text_tokens: {
    #       standard: {
    #         input_per_million: 2.5,
    #         output_per_million: 10.0,
    #         cache_read_input_per_million: 1.25,
    #         cache_write_input_per_million: 5.0,
    #         reasoning_output_per_million: 15.0
    #       }
    #     },
    #     audio_tokens: { standard: { input_per_million: 100.0, output_per_million: 200.0 } }
    #   }
    #
    module CostCalculator
      MILLION = 1_000_000

      class << self
        # Calculate the total cost in USD for a model invocation.
        #
        # @param model [Ask::ModelInfo, #pricing] the model
        # @param input_tokens [Integer]
        # @param output_tokens [Integer]
        # @param cache_read_tokens [Integer]
        # @param cache_write_tokens [Integer]
        # @param reasoning_tokens [Integer] tokens billed at reasoning rate
        # @return [Float, nil] cost in USD, or nil if no pricing data
        def calculate(model, input_tokens: 0, output_tokens: 0,
                      cache_read_tokens: 0, cache_write_tokens: 0,
                      reasoning_tokens: 0)
          pricing = model.respond_to?(:pricing) ? model.pricing : model
          rates = pricing.dig(:text_tokens, :standard) or return nil

          sum = cost(input_tokens, rates[:input_per_million])
          sum += cost(output_tokens, rates[:output_per_million])

          if cache_read_tokens > 0
            sum += cost(cache_read_tokens, rates[:cache_read_input_per_million])
          end
          if cache_write_tokens > 0
            sum += cost(cache_write_tokens, rates[:cache_write_input_per_million])
          end
          if reasoning_tokens > 0
            rate = rates[:reasoning_output_per_million] || rates[:output_per_million]
            sum += cost(reasoning_tokens, rate)
          end

          sum
        end

        # Cost breakdown with individual components.
        #
        # @return [Hash, nil]
        def breakdown(model, input_tokens: 0, output_tokens: 0,
                      cache_read_tokens: 0, cache_write_tokens: 0,
                      reasoning_tokens: 0)
          pricing = model.respond_to?(:pricing) ? model.pricing : model
          rates = pricing.dig(:text_tokens, :standard) or return nil

          {
            input: cost(input_tokens, rates[:input_per_million]),
            output: cost(output_tokens, rates[:output_per_million]),
            cache_read: cache_read_tokens > 0 ? cost(cache_read_tokens, rates[:cache_read_input_per_million]) : 0,
            cache_write: cache_write_tokens > 0 ? cost(cache_write_tokens, rates[:cache_write_input_per_million]) : 0,
            reasoning: reasoning_tokens > 0 ? cost(reasoning_tokens, rates[:reasoning_output_per_million] || rates[:output_per_million]) : 0
          }.compact
        end

        private

        def cost(tokens, rate)
          return 0.0 unless rate && tokens > 0
          (tokens * rate) / MILLION.to_f
        end
      end
    end
  end
end
