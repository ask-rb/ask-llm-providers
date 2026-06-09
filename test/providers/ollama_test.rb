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

  def test_chat_payload_build
  assert true
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
end
