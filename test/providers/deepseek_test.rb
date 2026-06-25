# frozen_string_literal: true

require_relative "../test_helper"

class DeepSeekProviderTest < Minitest::Test
  def setup
    @provider = Ask::Providers::DeepSeek.new(api_key: "sk-deepseek-test")
  end

  def test_api_base
    assert_equal "https://api.deepseek.com", @provider.api_base
  end

  def test_headers
    h = @provider.headers
    assert_equal "Bearer sk-deepseek-test", h["Authorization"]
  end

  def test_slug
    assert_equal "deepseek", Ask::Providers::DeepSeek.slug
  end

  def test_capabilities
    caps = Ask::Providers::DeepSeek.capabilities
    assert caps[:chat]; assert caps[:streaming]; assert caps[:tool_calls]; assert caps[:thinking]
  end

  def test_configuration_requirements
    assert_includes Ask::Providers::DeepSeek.configuration_requirements, :api_key
  end

  def test_chat_payload_builds
    messages = [{ role: "user", content: "Hello" }]
    payload = @provider.send(:build_chat_payload, messages, "deepseek-chat", nil, nil, false, nil)
    assert_equal "deepseek-chat", payload[:model]
    assert_equal false, payload[:stream]
  end

  def test_chat_payload_streaming
    messages = [{ role: "user", content: "Hi" }]
    payload = @provider.send(:build_chat_payload, messages, "deepseek-chat", nil, nil, true, nil)
    assert payload[:stream]
  end

  def test_chat_payload_with_tools
    messages = [{ role: "user", content: "Hi" }]
    tools = [{ name: "get_weather", parameters: { type: "object" } }]
    payload = @provider.send(:build_chat_payload, messages, "deepseek-chat", tools, nil, false, nil)
    assert payload[:tools]
  end

  def test_chat_payload_with_temperature
    messages = [{ role: "user", content: "Hi" }]
    payload = @provider.send(:build_chat_payload, messages, "deepseek-chat", nil, 0.7, false, nil)
    assert_equal 0.7, payload[:temperature]
  end

  def test_response_parsing
    body = { "id" => "chatcmpl-123", "model" => "deepseek-chat",
             "choices" => [{ "index" => 0, "message" => { "role" => "assistant", "content" => "Hello!" }, "finish_reason" => "stop" }],
             "usage" => { "prompt_tokens" => 10, "completion_tokens" => 20 } }
    msg = @provider.send(:parse_response, body, "deepseek-chat")
    assert_equal :assistant, msg.role
    assert_equal "Hello!", msg.content
  end

  def test_response_parsing_with_tool_calls
    body = { "id" => "chatcmpl-456", "model" => "deepseek-chat",
             "choices" => [{ "message" => { "tool_calls" => [{ "id" => "call_1", "function" => { "name" => "get_weather" } }] },
                             "finish_reason" => "tool_calls" }] }
    msg = @provider.send(:parse_response, body, "deepseek-chat")
    assert msg.tool_call?
  end

  def test_process_chunk
    stream = Ask::Stream.new
    data = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"}}]}\n\n"
    @provider.send(:process_chunk, data, stream, "deepseek-chat")
    assert_equal 1, stream.length
  end

  def test_process_chunk_done
    stream = Ask::Stream.new
    data = "data: [DONE]\n\n"
    @provider.send(:process_chunk, data, stream, "deepseek-chat")
    assert_equal 0, stream.length
  end

  def test_process_chunk_invalid_json
    stream = Ask::Stream.new
    @provider.send(:process_chunk, "data: not json\n\n", stream, "deepseek-chat")
    assert_equal 0, stream.length
  end

  def test_parse_error
    response = Object.new
    def response.body; { "error" => { "message" => "Insufficient balance" } }; end
    error = @provider.parse_error(response)
    assert_includes error, "Insufficient"
  end

  def test_responds_to_chat
    assert_respond_to @provider, :chat
  end

  def test_responds_to_list_models
    assert_respond_to @provider, :list_models
  end

  def test_configuration_options
    opts = Ask::Providers::DeepSeek.configuration_options
    assert_includes opts, :api_key
  end
end
