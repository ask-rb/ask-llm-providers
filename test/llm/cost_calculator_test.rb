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
        },
        batch: {
          input_per_million: 1.25,
          output_per_million: 5.0
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

  # --- Basic text token costing ---

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
    # 0.0025 + 0.005 + 0.0025 + 0.0025 + 0.003 = 0.0155
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

  def test_missing_rate_uses_output_rate_for_reasoning
    pricing = { text_tokens: { standard: { input_per_million: 2.5, output_per_million: 10.0 } } }
    cost = Ask::LLM::CostCalculator.calculate(pricing, reasoning_tokens: 100)
    assert_in_delta 0.001, cost, 0.0001
  end

  # --- Audio token costing ---

  def test_calculate_audio_input
    cost = Ask::LLM::CostCalculator.calculate(@model, audio_input_tokens: 1000)
    assert_in_delta 0.1, cost, 0.0001
  end

  def test_calculate_audio_output
    cost = Ask::LLM::CostCalculator.calculate(@model, audio_output_tokens: 500)
    assert_in_delta 0.1, cost, 0.0001
  end

  def test_calculate_audio_and_text
    cost = Ask::LLM::CostCalculator.calculate(@model,
      input_tokens: 1000, output_tokens: 500,
      audio_input_tokens: 1000, audio_output_tokens: 500)
    # 0.0025 + 0.005 + 0.1 + 0.1 = 0.2075
    assert_in_delta 0.2075, cost, 0.0001
  end

  # --- Tiered pricing ---

  def test_batch_tier_pricing
    cost = Ask::LLM::CostCalculator.calculate(@model, input_tokens: 1000, output_tokens: 500, tier: :batch)
    # 1000*1.25/1M + 500*5/1M = 0.00375
    assert_in_delta 0.00375, cost, 0.0001
  end

  def test_batch_tier_nil_when_no_batch_pricing
    pricing = { text_tokens: { standard: { input_per_million: 2.5, output_per_million: 10.0 } } }
    cost = Ask::LLM::CostCalculator.calculate(pricing, input_tokens: 100, tier: :batch)
    assert_nil cost
  end

  # --- per_million accessor ---

  def test_per_million
    pm = Ask::LLM::CostCalculator.per_million(@model)
    refute_nil pm
    assert_in_delta 2.5, pm[:input], 0.001
    assert_in_delta 10.0, pm[:output], 0.001
    assert_in_delta 1.25, pm[:cache_read], 0.001
    assert_in_delta 5.0, pm[:cache_write], 0.001
    assert_in_delta 15.0, pm[:reasoning], 0.001
  end

  def test_per_million_nil_when_no_pricing
    assert_nil Ask::LLM::CostCalculator.per_million({})
  end

  def test_per_million_batch_tier
    pm = Ask::LLM::CostCalculator.per_million(@model, tier: :batch)
    refute_nil pm
    assert_in_delta 1.25, pm[:input], 0.001
    assert_in_delta 5.0, pm[:output], 0.001
  end

  # --- Breakdown ---

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

  def test_breakdown_includes_audio
    b = Ask::LLM::CostCalculator.breakdown(@model, audio_input_tokens: 500, audio_output_tokens: 200)
    assert_in_delta 0.05, b[:audio_input], 0.0001 if b[:audio_input]
    assert_in_delta 0.04, b[:audio_output], 0.0001 if b[:audio_output]
  end
end
