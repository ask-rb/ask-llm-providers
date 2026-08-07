# frozen_string_literal: true

require_relative "../test_helper"

# A Faraday-shaped fake: captures the request body/path, replays on_data SSE
# fragments, and returns a fake response.
class FakeResponsesHttp
  attr_reader :last_path, :last_body

  def initialize(body: "{}", status: 200)
    @body = body
    @status = status
  end

  def post(path)
    req = Object.new
    req.define_singleton_method(:body=) { |b| @captured_body = b }
    req.define_singleton_method(:body) { @captured_body }
    options = Object.new
    options.define_singleton_method(:on_data=) { |p| @on_data = p }
    options.define_singleton_method(:on_data) { @on_data }
    req.define_singleton_method(:options) { options }
    yield req
    @last_path = path
    @last_body = req.body
    if req.options.on_data && @status == 200
      @body.to_s.split("\n\n").each do |event|
        next if event.strip.empty?

        req.options.on_data.call(event + "\n\n", nil, nil)
      end
    end
    status = @status
    body = @body
    resp = Object.new
    resp.define_singleton_method(:success?) { status == 200 }
    resp.define_singleton_method(:status) { status }
    resp.define_singleton_method(:body) { JSON.parse(body) rescue body }
    resp
  end
end

class OpenaiCodexProviderTest < Minitest::Test
  def setup
    Ask::ModelCatalog.reset_instance!
    Ask::ModelCatalog.instance.register(Ask::ModelInfo.new(id: "gpt-5.4", provider: "openai_codex"))
    @provider = Ask::Providers::OpenaiCodex.new(api_key: "codex-oauth-token", account_id: "acct_123")
  end

  def messages
    [{role: "user", content: "Hello"}]
  end

  # --- URL / headers ---

  def test_api_base_points_at_the_codex_responses_endpoint
    assert_equal "https://chatgpt.com/backend-api/codex", @provider.api_base
  end

  def test_headers_include_the_bearer_token_and_account_id
    headers = @provider.headers

    assert_equal "Bearer codex-oauth-token", headers["Authorization"]
    assert_equal "acct_123", headers["ChatGPT-Account-Id"]
  end

  # --- Request building (non-stream) ---

  def test_chat_posts_a_responses_payload
    http = FakeResponsesHttp.new(body: JSON.generate(
      "id" => "resp_1",
      "output" => [{"type" => "message", "content" => [{"type" => "output_text", "text" => "Hello!"}]}],
      "usage" => {"input_tokens" => 10, "output_tokens" => 5},
      "status" => "completed"
    ))
    @provider.instance_variable_set(:@http, http)

    message = @provider.chat(messages, model: "gpt-5.4")

    assert_equal "responses", http.last_path
    payload = http.last_body
    assert_equal "gpt-5.4", payload[:model]
    assert payload.key?(:input) # Responses API uses input, not messages
    assert_equal "user", payload[:input][0][:role]
    assert_equal "Hello", payload[:input][0][:content][0][:text]
    assert_equal "Hello!", message.content
    assert_equal 10, message.metadata[:input_tokens]
  end

  def test_chat_includes_regular_tools
    http = FakeResponsesHttp.new
    @provider.instance_variable_set(:@http, http)

    tools = [{name: "get_weather", description: "Get weather", parameters: {type: "object", properties: {}}}]
    @provider.chat(messages, model: "gpt-5.4", tools: tools)

    payload = http.last_body
    assert payload[:tools]
    assert_equal "get_weather", payload[:tools][0][:function][:name]
  end

  def test_chat_parses_tool_calls_from_the_response
    body = JSON.generate(
      "id" => "resp_1",
      "output" => [
        {"type" => "function_call", "id" => "call_1", "name" => "get_weather", "arguments" => "{\"city\":\"Kampala\"}", "status" => "completed"}
      ],
      "usage" => {"input_tokens" => 10, "output_tokens" => 5},
      "status" => "completed"
    )
    http = FakeResponsesHttp.new(body: body)
    @provider.instance_variable_set(:@http, http)

    message = @provider.chat(messages, model: "gpt-5.4")

    assert_equal 1, message.tool_calls.length
    assert_equal "call_1", message.tool_calls[0][:id]
    assert_equal "get_weather", message.tool_calls[0][:name]
  end

  # --- Streaming ---

  def sse_event(type, data)
    "data: #{JSON.generate(data.merge(type: type))}\n\n"
  end

  def test_chat_streams_responses_sse_events
    events = +""
    events << sse_event("response.created", {})
    events << sse_event("response.output_text.delta", {delta: "Hello"})
    events << sse_event("response.output_text.delta", {delta: " world"})
    events << sse_event("response.output_item.added", {item: {id: "call_1", type: "function_call", name: "get_weather"}})
    events << sse_event("response.function_call_arguments.delta", {arguments: "{\"city\":"})
    events << sse_event("response.function_call_arguments.delta", {arguments: "\"Kampala\"}"})
    events << sse_event("response.completed", {response: {status: "completed", usage: {input_tokens: 9, output_tokens: 4}}})

    http = FakeResponsesHttp.new(body: events)
    @provider.instance_variable_set(:@http, http)

    chunks = []
    stream = @provider.chat(messages, model: "gpt-5.4", stream: true) { |chunk| chunks << chunk }

    text = chunks.select { |c| c.content }.map(&:content).join
    assert_equal "Hello world", text
    tool_chunks = chunks.select { |c| c.tool_call? }
    assert_equal 1, tool_chunks.count { |c| c.tool_calls[0][:name] } # id/name arrive once, on output_item.added
    assert_equal '{"city":"Kampala"}', tool_chunks.map { |c| c.tool_calls[0][:arguments] }.compact.join
    finish = chunks.find { |c| c.finish_reason }
    assert_equal "completed", finish.finish_reason
    usage = chunks.find { |c| c.usage }
    assert_equal 9, usage.usage[:input_tokens]
  end
end
