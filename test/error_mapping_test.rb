# frozen_string_literal: true

require_relative "test_helper"

class ErrorMappingTest < Minitest::Test
  def test_rate_limit_error
    error = Ask::LLM::HTTP.map_error(429, { "error" => { "message" => "Too fast" } }, provider: "OpenAI")
    assert error.is_a?(Ask::RateLimitError)
    assert_match(/Too fast/, error.message)
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
