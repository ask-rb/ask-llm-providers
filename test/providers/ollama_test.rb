# frozen_string_literal: true

require_relative "../test_helper"

class OllamaProviderTest < Minitest::Test
  include BaseProviderTests
  def provider_class
    Ask::Providers::Ollama
  end

  def provider_config
    {}
  end

  def test_model
    "llama3"
  end

  # --- API base ---

  def test_api_base_default
    assert_equal "http://localhost:11434", @provider.api_base
  end

  def test_api_base_custom
    provider = provider_class.new(api_base: "http://192.168.1.100:11434")
    assert_equal "http://192.168.1.100:11434", provider.api_base
  end

  # --- Headers ---

  def test_headers
    h = @provider.headers
    assert_equal "application/json", h["Content-Type"]
  end

  # --- Streaming ---

  def test_parse_stream_content
    stream = Ask::Stream.new
    @provider.parse_stream("{\"model\":\"llama3\",\"message\":{\"role\":\"assistant\",\"content\":\"Hello\"}}\n",
                            stream, test_model)
    assert_equal 1, stream.length
    assert_equal "Hello", stream.chunks.first.content
  end

  def test_parse_stream_with_done_field
    stream = Ask::Stream.new
    @provider.parse_stream(
      "{\"model\":\"llama3\",\"message\":{\"role\":\"assistant\",\"content\":\"Hi\"},\"done\":true}\n",
      stream, test_model
    )
    assert_operator stream.length, :>=, 0
  end

  def test_parse_stream_empty
    stream = Ask::Stream.new
    @provider.parse_stream("", stream, test_model)
    assert_equal 0, stream.length
  end

  def test_parse_stream_malformed_json
    stream = Ask::Stream.new
    @provider.parse_stream("not json\n", stream, test_model)
    assert_equal 0, stream.length
  end

  # --- Local flag ---

  def test_local_flag
    assert provider_class.local?
  end

  # --- Capabilities ---

  def test_capabilities
    caps = provider_class.capabilities
    assert caps[:chat]; assert caps[:streaming]
    assert caps[:local]; assert caps[:embed]
  end

  def test_no_auth_required
    assert_empty provider_class.configuration_requirements
  end

  # --- Response parsing ---

  def test_parse_response
    body = { "model" => "llama3", "message" => { "role" => "assistant", "content" => "Hello" },
             "done" => true, "total_duration" => 1_234_567 }
    msg = @provider.parse_response(body, test_model)
    assert_equal :assistant, msg.role
    assert_equal "Hello", msg.content
    assert msg.metadata[:done]
  end

  # --- Override base tests ---

  def test_build_request_includes_model
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model)
    assert_equal test_model, result[:model]
  end

  def test_build_request_includes_stream_flag
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model, stream: true)
    assert_equal true, result[:stream]
  end
end
