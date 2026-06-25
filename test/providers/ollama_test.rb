# frozen_string_literal: true

require_relative "../test_helper"

class OllamaProviderTest < Minitest::Test
  def setup
    @provider = Ask::Providers::Ollama.new
  end

  def test_api_base_default
    assert_equal "http://localhost:11434", @provider.api_base
  end

  def test_api_base_custom
    provider = Ask::Providers::Ollama.new(api_base: "http://192.168.1.100:11434")
    assert_equal "http://192.168.1.100:11434", provider.api_base
  end

  def test_headers
    h = @provider.headers
    assert_equal "application/json", h["Content-Type"]
  end

  def test_process_ollama_chunk_content
    stream = Ask::Stream.new
    @provider.__send__(:process_ollama_chunk, "{\"model\":\"llama3\",\"message\":{\"role\":\"assistant\",\"content\":\"Hello\"}}\n", stream, "llama3")
    assert_equal 1, stream.length
    assert_equal "Hello", stream.chunks.first.content
  end

  def test_process_chunk_with_done_field
    stream = Ask::Stream.new
    @provider.__send__(:process_ollama_chunk, "{\"model\":\"llama3\",\"message\":{\"role\":\"assistant\",\"content\":\"Hi\"},\"done\":true}\n", stream, "llama3")
    assert_operator stream.length, :>=, 0
  end

  def test_process_chunk_empty
    stream = Ask::Stream.new
    @provider.__send__(:process_ollama_chunk, "", stream, "llama3")
    assert_equal 0, stream.length
  end

  def test_process_chunk_malformed_json
    stream = Ask::Stream.new
    @provider.__send__(:process_ollama_chunk, "not json\n", stream, "llama3")
    assert_equal 0, stream.length
  end

  def test_local_flag
    assert Ask::Providers::Ollama.local?
    assert Ask::Providers::Ollama.assume_models_exist?
  end

  def test_capabilities
    caps = Ask::Providers::Ollama.capabilities
    assert caps[:chat]
    assert caps[:streaming]
    assert caps[:local]
    assert caps[:embed]
  end

  def test_no_auth_required
    assert_empty Ask::Providers::Ollama.configuration_requirements
  end

  def test_slug
    assert_equal "ollama", Ask::Providers::Ollama.slug
  end

  def test_configuration_options
    opts = Ask::Providers::Ollama.configuration_options
    assert_includes opts, :api_base
  end

  def test_responds_to_chat
    assert_respond_to @provider, :chat
  end

  def test_responds_to_embed
    assert_respond_to @provider, :embed
  end

  def test_responds_to_list_models
    assert_respond_to @provider, :list_models
  end
end
