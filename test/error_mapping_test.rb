# frozen_string_literal: true

require_relative "test_helper"

class ErrorMappingTest < Minitest::Test
  def test_rate_limit_error
    error = Ask::LLM::HTTP.map_error(429, { "error" => { "message" => "Too fast" } }, provider: "OpenAI")
    assert error.is_a?(Ask::RateLimitError)
    assert_match(/Too fast/, error.message)
  end

  def test_rate_limit_category_is_vendor
    error = Ask::LLM::HTTP.map_error(429, { "error" => { "message" => "Rate limited" } }, provider: "OpenAI")
    assert_equal Ask::RateLimitCategory::VENDOR, error.category
  end

  def test_rate_limit_type_requests_by_default
    error = Ask::LLM::HTTP.map_error(429, { "error" => { "message" => "Too many requests" } }, provider: "OpenAI")
    assert_equal Ask::RateLimitType::REQUESTS, error.rate_limit_type
  end

  def test_rate_limit_type_tokens
    error = Ask::LLM::HTTP.map_error(429, { "error" => { "message" => "Token limit exceeded" } }, provider: "OpenAI")
    assert_equal Ask::RateLimitType::TOKENS, error.rate_limit_type
  end

  def test_rate_limit_type_budget
    error = Ask::LLM::HTTP.map_error(429, { "error" => { "message" => "Budget exceeded" } }, provider: "OpenAI")
    assert_equal Ask::RateLimitType::BUDGET, error.rate_limit_type
  end

  def test_rate_limit_type_concurrent
    error = Ask::LLM::HTTP.map_error(429, { "error" => { "message" => "Too many concurrent requests" } }, provider: "OpenAI")
    assert_equal Ask::RateLimitType::CONCURRENT, error.rate_limit_type
  end

  def test_retry_after_from_headers
    error = Ask::LLM::HTTP.map_error(429, { "error" => { "message" => "Too fast" } }, provider: "OpenAI", headers: { "retry-after" => "30" })
    assert_equal 30, error.retry_after
  end

  def test_retry_after_nil_when_no_headers
    error = Ask::LLM::HTTP.map_error(429, { "error" => { "message" => "Too fast" } }, provider: "OpenAI")
    assert_nil error.retry_after
  end

  def test_rate_limit_type_from_quota_message
    error = Ask::LLM::HTTP.map_error(429, { "error" => { "message" => "Quota exceeded for API requests" } }, provider: "OpenAI")
    assert_equal Ask::RateLimitType::BUDGET, error.rate_limit_type
  end

  def test_auth_error
    error = Ask::LLM::HTTP.map_error(401, { "error" => { "message" => "Invalid key" } }, provider: "OpenAI")
    assert error.is_a?(Ask::Unauthorized)
    assert_match(/Invalid key/, error.message)
  end

  def test_forbidden_error
    error = Ask::LLM::HTTP.map_error(403, { "error" => { "message" => "Forbidden" } }, provider: "Anthropic")
    assert error.is_a?(Ask::Unauthorized)
  end

  def test_server_error
    error = Ask::LLM::HTTP.map_error(500, { "error" => { "message" => "Server error" } }, provider: "OpenAI")
    assert error.is_a?(Ask::ServerError)
  end

  def test_service_unavailable
    error = Ask::LLM::HTTP.map_error(503, nil, provider: "OpenAI")
    assert error.is_a?(Ask::ServiceUnavailable)
  end

  def test_context_length_exceeded
    error = Ask::LLM::HTTP.map_error(400, { "error" => { "code" => "context_length_exceeded", "message" => "Too long" } }, provider: "OpenAI")
    assert error.is_a?(Ask::ContextLengthExceeded)
  end

  def test_generic_provider_error
    error = Ask::LLM::HTTP.map_error(400, { "error" => { "message" => "Bad request" } }, provider: "Mistral")
    assert error.is_a?(Ask::ProviderError)
    assert_equal 400, error.status_code
  end
end
