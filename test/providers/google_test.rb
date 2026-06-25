# frozen_string_literal: true

require_relative "../test_helper"

class GoogleProviderTest < Minitest::Test
  def setup
    @provider = Ask::Providers::Google.new(api_key: "google-test-key")
  end

  def test_headers
    h = @provider.headers
    assert_equal "application/json", h["Content-Type"]
  end

  def test_api_base
    assert_equal "https://generativelanguage.googleapis.com/v1beta", @provider.api_base
  end

  def test_capabilities
    caps = Ask::Providers::Google.capabilities
    assert caps[:chat]; assert caps[:streaming]; assert caps[:tool_calls]; assert caps[:vision]
  end

  def test_slug
    assert_equal "gemini", Ask::Providers::Google.slug
  end

  def test_configuration_options
    opts = Ask::Providers::Google.configuration_options
    assert_includes opts, :api_key
  end

  def test_chat_payload_builds
    messages = [{ role: "user", content: "Hello" }]
    payload = @provider.send(:build_chat_payload, messages, "gemini-2.0-flash", nil, nil, false, nil)
    assert payload[:contents]
  end

  def test_chat_path
    path = @provider.send(:chat_path, "gemini-2.0-flash")
    assert_includes path, "gemini-2.0-flash"
  end

  def test_parse_response
    body = { "candidates" => [{ "content" => { "parts" => [{ "text" => "Hello from Gemini" }] }, "finishReason" => "STOP" }],
             "usageMetadata" => { "promptTokenCount" => 10, "candidatesTokenCount" => 20 } }
    msg = @provider.send(:parse_response, body, "gemini-2.0-flash")
    assert_equal :assistant, msg.role
    assert_equal "Hello from Gemini", msg.content
  end

  def test_format_content
    formatted = @provider.send(:format_content, { role: :user, content: "Hello" })
    assert formatted[:parts]
    assert formatted[:parts][0][:text]
  end

  def test_parse_error
    response = Object.new
    def response.body; { "error" => { "message" => "API key invalid" } }; end
    error = @provider.parse_error(response)
    assert_includes error, "API key"
  end

  def test_responds_to_chat
    assert_respond_to @provider, :chat
  end

  def test_responds_to_embed
    assert_respond_to @provider, :embed
  end

  def test_configuration_requirements
    reqs = Ask::Providers::Google.configuration_requirements
    assert_includes reqs, :api_key
  end
end
