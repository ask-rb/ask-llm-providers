# frozen_string_literal: true

require_relative "../test_helper"

class OpenAIProviderTest < Minitest::Test
  include BaseProviderTests
  def provider_class
    Ask::Providers::OpenAI
  end

  def provider_config
    { api_key: "sk-test" }
  end

  def test_model
    "gpt-4o"
  end

  # --- Request building ---

  def test_build_request_basic
    messages = [{ role: "user", content: "Hello" }]
    payload = @provider.build_request(messages, model: test_model)
    assert_equal test_model, payload[:model]
    assert_equal false, payload[:stream]
    assert_equal 1, payload[:messages].length
    assert_equal "user", payload[:messages][0][:role]
    assert_equal "Hello", payload[:messages][0][:content]
  end

  def test_build_request_includes_tools
    tools = [{ name: "get_weather", description: "Get weather", parameters: { type: "object", properties: {} } }]
    payload = @provider.build_request(messages, model: test_model, tools:)
    assert payload[:tools]
    assert_equal 1, payload[:tools].length
  end

  def test_build_request_includes_temperature
    payload = @provider.build_request(messages, model: test_model, temperature: 0.7)
    assert_equal 0.7, payload[:temperature]
  end

  def test_build_request_includes_schema
    schema = { type: "object", properties: { name: { type: "string" } } }
    payload = @provider.build_request(messages, model: test_model, schema:)
    assert payload[:response_format]
    assert_equal "json_schema", payload[:response_format][:type]
  end

  # --- Response parsing ---

  def test_parse_response
    body = {
      "id" => "chatcmpl-123",
      "model" => "gpt-4o",
      "choices" => [{
        "index" => 0,
        "message" => { "role" => "assistant", "content" => "Hello!" },
        "finish_reason" => "stop"
      }],
      "usage" => { "prompt_tokens" => 10, "completion_tokens" => 20 }
    }
    msg = @provider.parse_response(body, test_model)
    assert_equal :assistant, msg.role
    assert_equal "Hello!", msg.content
    assert_equal "stop", msg.metadata[:finish_reason]
    assert_equal 10, msg.metadata[:input_tokens]
  end

  def test_parse_response_with_tool_calls
    body = {
      "id" => "chatcmpl-456",
      "model" => "gpt-4o",
      "choices" => [{
        "index" => 0,
        "message" => {
          "role" => "assistant",
          "content" => nil,
          "tool_calls" => [{
            "id" => "call_1",
            "type" => "function",
            "function" => { "name" => "get_weather", "arguments" => '{"location":"NYC"}' }
          }]
        },
        "finish_reason" => "tool_calls"
      }],
      "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 }
    }
    msg = @provider.parse_response(body, test_model)
    assert msg.tool_call?
    assert_equal 1, msg.tool_calls.length
    assert_equal "get_weather", msg.tool_calls.first[:name]
  end

  def test_parse_response_nil_content
    body = { "choices" => [] }
    msg = @provider.parse_response(body, test_model)
    assert_equal :assistant, msg.role
    assert_nil msg.content
  end

  # --- Streaming ---

  def test_parse_stream_complete_sse_event
    stream = Ask::Stream.new
    data = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"}}]}\n\n"
    @provider.parse_stream(data, stream, test_model)
    assert_equal 1, stream.length
    assert_equal "Hello", stream.chunks.first.content
  end

  def test_parse_stream_fragmented_sse_data
    stream = Ask::Stream.new
    frag1 = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hel"
    frag2 = "lo\"}}]}\n\n"
    @provider.parse_stream(frag1, stream, test_model)
    assert_equal 0, stream.length, "no chunk for incomplete data"
    @provider.parse_stream(frag2, stream, test_model)
    assert_equal 1, stream.length
    assert_equal "Hello", stream.chunks.first.content
  end

  def test_parse_stream_multiple_events
    stream = Ask::Stream.new
    data = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"A\"}}]}\n\n" \
           "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"B\"}}]}\n\n" \
           "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"C\"}}]}\n\n"
    @provider.parse_stream(data, stream, test_model)
    assert_equal 3, stream.length
    assert_equal %w[A B C], stream.chunks.map(&:content)
  end

  def test_parse_stream_done_sentinel
    stream = Ask::Stream.new
    data = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hi\"}}]}\n\ndata: [DONE]\n\n"
    @provider.parse_stream(data, stream, test_model)
    assert_equal 1, stream.length
    assert_equal "Hi", stream.chunks.first.content
  end

  def test_parse_stream_invalid_json
    stream = Ask::Stream.new
    @provider.parse_stream("data: not json\n\n", stream, test_model)
    assert_equal 0, stream.length
  end

  # --- Headers ---

  def test_headers
    headers = @provider.headers
    assert_equal "Bearer sk-test", headers["Authorization"]
    assert_equal "application/json", headers["Content-Type"]
  end

  def test_api_base_default
    assert_equal "https://api.openai.com/v1", @provider.api_base
  end

  def test_api_base_custom
    provider = provider_class.new(api_key: "sk-test", base_url: "https://openrouter.ai/api/v1")
    assert_equal "https://openrouter.ai/api/v1", provider.api_base
  end

  def test_organization_id_header
    provider = provider_class.new(api_key: "sk-test", organization_id: "org-123")
    assert_equal "org-123", provider.headers["OpenAI-Organization"]
  end

  # --- Format tools ---

  def test_format_tools
    tools = [{ name: "get_weather", description: "Get weather", parameters: { type: "object" } }]
    formatted = @provider.format_tools(tools)
    assert_equal 1, formatted.length
    assert_equal "function", formatted[0][:type]
    assert_equal "get_weather", formatted[0][:function][:name]
  end

  def test_format_tools_with_tool_objects
    tool = Object.new
    def tool.name; "get_weather"; end
    def tool.description; "Get weather"; end
    def tool.parameters; { type: "object" }; end
    formatted = @provider.format_tools([tool])
    assert_equal "get_weather", formatted[0][:function][:name]
  end

  # --- Format messages ---

  def test_format_message_with_tool_calls
    msg = { role: :assistant, content: nil,
            tool_calls: [{ id: "call_1", type: "function",
                           function: { name: "get_weather", arguments: '{"loc":"NYC"}' } }] }
    formatted = @provider.format_message(msg)
    assert_equal "assistant", formatted[:role]
    assert formatted[:tool_calls]
    assert_equal "call_1", formatted[:tool_calls][0][:id]
  end

  def test_format_message_with_tool_call_id
    msg = { role: :tool, content: "34°F", tool_call_id: "call_1" }
    formatted = @provider.format_message(msg)
    assert_equal "tool", formatted[:role]
    assert_equal "call_1", formatted[:tool_call_id]
  end

  # --- Config normalization ---

  def test_accepts_ask_llm_config_object
    config = Ask::LLM::Config.new({ api_key: "sk-config-object" })
    provider = provider_class.new(config)
    assert_equal "sk-config-object", provider.config.api_key
  end

  def test_accepts_ask_llm_config_object_with_base_url
    config = Ask::LLM::Config.new({ api_key: "sk-test", base_url: "https://custom.api.com/v1" })
    provider = provider_class.new(config)
    assert_equal "https://custom.api.com/v1", provider.api_base
    assert_equal "sk-test", provider.config.api_key
  end

  # --- Parse error ---

  def test_parse_error
    response = Object.new
    def response.body; { "error" => { "message" => "Insufficient balance" } }; end
    error = @provider.parse_error(response)
    assert_includes error, "Insufficient"
  end

  def test_parse_error_nil_body
    response = Object.new
    def response.body; nil; end
    assert_nil @provider.parse_error(response)
  end

  # --- Contribution guarantees (from BaseProviderTest) ---

  # Override test_build_request_includes_model since OpenAI stores model as :model key
  def test_build_request_includes_model
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model)
    assert_equal test_model, result[:model]
  end

  def test_build_request_includes_stream_flag
    result = @provider.build_request([{ role: "user", content: "Hello" }], model: test_model, stream: true)
    assert_equal true, result[:stream]
  end

  private

  def messages
    [{ role: "user", content: "Hi" }]
  end
end
