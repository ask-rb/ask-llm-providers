# frozen_string_literal: true

require_relative "../test_helper"

class CostCalculatorTest < Minitest::Test
  def setup
    @pricing = {
      text_tokens: {
        standard: {
          input_per_million: 2.5,
          output_per_million: 10.0,
          cache_read_input_per_million: 1.25,
          cache_write_input_per_million: 5.0,
          reasoning_output_per_million: 15.0
        }
      },
      audio_tokens: {
        standard: {
          input_per_million: 100.0,
          output_per_million: 200.0
        }
      }
    }
    @model = Ask::ModelInfo.new(id: "gpt-4o", provider: "openai", pricing: @pricing)
  end

  def test_calculate_input_only
    cost = Ask::LLM::CostCalculator.calculate(@model, input_tokens: 1000)
    assert_in_delta 0.0025, cost, 0.0001
  end

  def test_calculate_output_only
    cost = Ask::LLM::CostCalculator.calculate(@model, output_tokens: 500)
    assert_in_delta 0.005, cost, 0.0001
  end

  def test_calculate_input_and_output
    cost = Ask::LLM::CostCalculator.calculate(@model, input_tokens: 1000, output_tokens: 500)
    assert_in_delta 0.0075, cost, 0.0001
  end

  def test_calculate_with_cache_read
    cost = Ask::LLM::CostCalculator.calculate(@model, input_tokens: 1000, cache_read_tokens: 2000)
    assert_in_delta 0.005, cost, 0.0001
  end

  def test_calculate_with_cache_write
    cost = Ask::LLM::CostCalculator.calculate(@model, input_tokens: 1000, cache_write_tokens: 500)
    assert_in_delta 0.005, cost, 0.0001
  end

  def test_calculate_with_reasoning
    cost = Ask::LLM::CostCalculator.calculate(@model, reasoning_tokens: 200)
    assert_in_delta 0.003, cost, 0.0001
  end

  def test_calculate_all_components
    cost = Ask::LLM::CostCalculator.calculate(@model,
      input_tokens: 1000, output_tokens: 500,
      cache_read_tokens: 2000, cache_write_tokens: 500,
      reasoning_tokens: 200)
    # input: 1000*2.5/1M = 0.0025
    # output: 500*10/1M = 0.005
    # cache_read: 2000*1.25/1M = 0.0025
    # cache_write: 500*5/1M = 0.0025
    # reasoning: 200*15/1M = 0.003
    # total: 0.0155
    assert_in_delta 0.0155, cost, 0.0001
  end

  def test_nil_when_no_pricing
    model = Ask::ModelInfo.new(id: "unknown", provider: "test")
    assert_nil Ask::LLM::CostCalculator.calculate(model, input_tokens: 100)
  end

  def test_zero_tokens_returns_zero
    cost = Ask::LLM::CostCalculator.calculate(@model)
    assert_in_delta 0.0, cost, 0.0001
  end

  def test_works_with_raw_pricing_hash
    cost = Ask::LLM::CostCalculator.calculate(@pricing, input_tokens: 1000)
    assert_in_delta 0.0025, cost, 0.0001
  end

  def test_breakdown_returns_all_components
    b = Ask::LLM::CostCalculator.breakdown(@model,
      input_tokens: 1000, output_tokens: 500,
      cache_read_tokens: 2000, reasoning_tokens: 200)
    assert_in_delta 0.0025, b[:input], 0.0001
    assert_in_delta 0.005, b[:output], 0.0001
    assert_in_delta 0.0025, b[:cache_read], 0.0001
    assert_equal 0, b[:cache_write]
    assert_in_delta 0.003, b[:reasoning], 0.0001
  end

  def test_breakdown_nil_when_no_pricing
    assert_nil Ask::LLM::CostCalculator.breakdown({}, input_tokens: 100)
  end

  def test_missing_rate_uses_output_rate_for_reasoning
    pricing = { text_tokens: { standard: { input_per_million: 2.5, output_per_million: 10.0 } } }
    cost = Ask::LLM::CostCalculator.calculate(pricing, reasoning_tokens: 100)
    assert_in_delta 0.001, cost, 0.0001
  end

  def test_audio_tokens_dont_affect_text_calculation
    cost = Ask::LLM::CostCalculator.calculate(@model, input_tokens: 1000, output_tokens: 500)
    assert_in_delta 0.0075, cost, 0.0001
  end
end
