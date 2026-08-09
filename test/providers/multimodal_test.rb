# frozen_string_literal: true

require_relative "../test_helper"

module Ask
  module Providers
    class MultiModalTest < Minitest::Test
      def setup
        # Build minimal configs for each provider
        @openai = OpenAI.new(build_config(api_key: "sk-test"))
        @anthropic = Anthropic.new(build_config(api_key: "sk-ant-test"))
      end

      # --- OpenAI content block formatting ---

      def test_openai_text_block
        block = { type: "text", text: "Hello" }
        result = @openai.send(:format_openai_content_block, block)
        assert_equal({ type: "text", text: "Hello" }, result)
      end

      def test_openai_image_url_block
        block = { type: "image", url: "https://example.com/img.jpg", mime_type: "image/jpeg" }
        result = @openai.send(:format_openai_content_block, block)
        assert_equal "image_url", result[:type]
        assert_equal "https://example.com/img.jpg", result.dig(:image_url, :url)
      end

      def test_openai_image_base64_block
        block = { type: "image", base64: "AAAA", mime_type: "image/png" }
        result = @openai.send(:format_openai_content_block, block)
        assert_equal "image_url", result[:type]
        assert_equal "data:image/png;base64,AAAA", result.dig(:image_url, :url)
      end

      def test_openai_image_file_id_block
        block = { type: "image", file_id: "file_abc" }
        result = @openai.send(:format_openai_content_block, block)
        assert_equal "image_url", result[:type]
        assert_equal "file_abc", result.dig(:image_url, :url)
      end

      def test_openai_audio_url_block
        block = { type: "audio", url: "https://example.com/sound.mp3", mime_type: "audio/mpeg" }
        result = @openai.send(:format_openai_content_block, block)
        assert_equal "input_audio", result[:type]
        assert_equal "https://example.com/sound.mp3", result.dig(:input_audio, :data)
        assert_equal "mp3", result.dig(:input_audio, :format)
      end

      def test_openai_audio_base64_block
        block = { type: "audio", base64: "DATA", mime_type: "audio/wav" }
        result = @openai.send(:format_openai_content_block, block)
        assert_equal "input_audio", result[:type]
        assert_equal "DATA", result.dig(:input_audio, :data)
        assert_equal "wav", result.dig(:input_audio, :format)
      end

      def test_openai_file_block
        block = { type: "file", data: "file content", filename: "notes.txt" }
        result = @openai.send(:format_openai_content_block, block)
        assert_equal "text", result[:type]
        assert_includes result[:text], "[notes.txt]"
        assert_includes result[:text], "file content"
      end

      def test_openai_video_url_block
        block = { type: "video", url: "https://example.com/vid.mp4" }
        result = @openai.send(:format_openai_content_block, block)
        assert_equal "image_url", result[:type]
        assert_equal "https://example.com/vid.mp4", result.dig(:image_url, :url)
      end

      # --- Anthropic content block formatting ---

      def test_anthropic_text_block
        block = { type: "text", text: "Hello" }
        result = @anthropic.send(:format_anthropic_content_block, block)
        assert_equal({ type: "text", text: "Hello" }, result)
      end

      def test_anthropic_image_base64_block
        block = { type: "image", base64: "AAAA", mime_type: "image/png" }
        result = @anthropic.send(:format_anthropic_content_block, block)
        assert_equal "image", result[:type]
        assert_equal "base64", result.dig(:source, :type)
        assert_equal "image/png", result.dig(:source, :media_type)
        assert_equal "AAAA", result.dig(:source, :data)
      end

      def test_anthropic_image_url_block
        block = { type: "image", url: "https://example.com/img.jpg", mime_type: "image/jpeg" }
        result = @anthropic.send(:format_anthropic_content_block, block)
        assert_equal "image", result[:type]
        assert_equal "url", result.dig(:source, :type)
        assert_equal "https://example.com/img.jpg", result.dig(:source, :url)
      end

      def test_anthropic_audio_block_unsupported
        block = { type: "audio", url: "https://example.com/sound.mp3" }
        result = @anthropic.send(:format_anthropic_content_block, block)
        assert_equal "text", result[:type]
        assert_includes result[:text], "audio"
      end

      def test_anthropic_video_block_unsupported
        block = { type: "video", url: "https://example.com/vid.mp4" }
        result = @anthropic.send(:format_anthropic_content_block, block)
        assert_equal "text", result[:type]
        assert_includes result[:text], "video"
      end

      def test_anthropic_file_block
        block = { type: "file", data: "content", filename: "data.csv", mime_type: "text/csv" }
        result = @anthropic.send(:format_anthropic_content_block, block)
        assert_equal "document", result[:type]
        assert_equal "text", result.dig(:source, :type)
        assert_equal "text/csv", result.dig(:source, :media_type)
        assert_equal "content", result.dig(:source, :data)
      end

      # --- Full message formatting (OpenAI) ---

      def test_openai_format_message_with_content_blocks
        msg = {
          role: :user,
          content: [
            { type: "text", text: "What's in this?" },
            { type: "image", url: "https://example.com/img.jpg", mime_type: "image/jpeg" }
          ]
        }
        result = @openai.send(:format_message, msg)

        assert_equal "user", result[:role]
        assert_kind_of Array, result[:content]
        assert_equal 2, result[:content].length
        assert_equal "text", result[:content][0][:type]
        assert_equal "image_url", result[:content][1][:type]
      end

      def test_openai_format_message_plain_text_still_works
        msg = { role: :user, content: "Hello" }
        result = @openai.send(:format_message, msg)

        assert_equal "user", result[:role]
        assert_equal "Hello", result[:content]
      end

      def test_openai_format_message_with_tool_calls_and_blocks
        msg = {
          role: :assistant,
          content: [{ type: "text", text: "Let me check" }],
          tool_calls: [
            { id: "call_1", function: { name: "get_weather", arguments: '{"city":"Paris"}' } }
          ]
        }
        result = @openai.send(:format_message, msg)

        assert_equal "assistant", result[:role]
        assert_kind_of Array, result[:content]
        assert result[:tool_calls]
      end

      # --- Full message formatting (Anthropic) ---

      def test_anthropic_format_message_with_content_blocks
        msg = {
          role: :user,
          content: [
            { type: "text", text: "Describe this image" },
            { type: "image", base64: "AAAA", mime_type: "image/png" }
          ]
        }
        result = @anthropic.send(:format_message, msg)

        assert_equal "user", result[:role]
        assert_kind_of Array, result[:content]
        assert_equal 2, result[:content].length
        assert_equal "text", result[:content][0][:type]
        assert_equal "image", result[:content][1][:type]
      end

      def test_anthropic_format_message_plain_text_still_works
        msg = { role: :user, content: "Hello" }
        result = @anthropic.send(:format_message, msg)

        assert_equal "user", result[:role]
        assert_equal "Hello", result[:content]
      end

      def test_anthropic_format_tool_result_with_blocks
        msg = {
          role: :tool,
          tool_call_id: "toolu_123",
          content: [
            { type: "text", text: "Tool output" },
            { type: "image", base64: "AAAA", mime_type: "image/png" }
          ]
        }
        result = @anthropic.send(:format_message, msg)

        assert_equal "user", result[:role]
        assert_kind_of Array, result[:content]
        assert_equal 1, result[:content].length
        assert_equal "tool_result", result[:content][0][:type]
        assert_kind_of Array, result[:content][0][:content]
        assert_equal 2, result[:content][0][:content].length
      end

      # --- OpenAI Responses API blocks ---

      def test_openai_responses_input_with_blocks
        messages = [{
          role: "user",
          content: [
            { type: "text", text: "Read this" },
            { type: "file", data: "a,b\n1,2\n", filename: "rows.csv", mime_type: "text/csv" }
          ]
        }]

        result = @openai.send(:format_responses_input, messages)
        content = result.first[:content]
        assert_equal "input_text", content[0][:type]
        assert_equal "input_file", content[1][:type]
        assert_equal "rows.csv", content[1][:filename]
        assert_equal "data:text/csv;base64,YSxiCjEsMgo=", content[1][:file_data]
      end

      def test_openai_responses_file_with_url
        block = { type: "file", url: "https://example.com/doc.pdf", filename: "doc.pdf", mime_type: "application/pdf" }
        result = @openai.send(:format_responses_content_block, block)
        assert_equal "input_file", result[:type]
        assert_equal "https://example.com/doc.pdf", result[:file_url]
      end

      def test_openai_responses_file_with_file_id
        block = { type: "file", file_id: "file-xyz", filename: "doc.pdf", mime_type: "application/pdf" }
        result = @openai.send(:format_responses_content_block, block)
        assert_equal "input_file", result[:type]
        assert_equal "file-xyz", result[:file_id]
      end

      def test_openai_responses_image_base64
        block = { type: "image", base64: "AAAA", mime_type: "image/png" }
        result = @openai.send(:format_responses_content_block, block)
        assert_equal "input_image", result[:type]
        assert_equal "data:image/png;base64,AAAA", result[:image_url]
      end

      # --- Anthropic document blocks ---

      def test_anthropic_file_pdf_becomes_base64_document
        block = { type: "file", data: "%PDF-1.7 fake", filename: "doc.pdf", mime_type: "application/pdf" }
        result = @anthropic.send(:format_anthropic_content_block, block)
        assert_equal "document", result[:type]
        assert_equal "base64", result.dig(:source, :type)
        assert_equal "application/pdf", result.dig(:source, :media_type)
        assert_equal Base64.strict_encode64("%PDF-1.7 fake"), result.dig(:source, :data)
        assert_equal "doc.pdf", result[:title]
      end

      def test_anthropic_file_text_becomes_text_document
        block = { type: "file", data: "hello", filename: "notes.txt", mime_type: "text/plain" }
        result = @anthropic.send(:format_anthropic_content_block, block)
        assert_equal "document", result[:type]
        assert_equal "text", result.dig(:source, :type)
        assert_equal "text/plain", result.dig(:source, :media_type)
        assert_equal "hello", result.dig(:source, :data)
      end

      def test_anthropic_file_url_becomes_url_document
        block = { type: "file", url: "https://example.com/doc.pdf", filename: "doc.pdf", mime_type: "application/pdf" }
        result = @anthropic.send(:format_anthropic_content_block, block)
        assert_equal "document", result[:type]
        assert_equal "url", result.dig(:source, :type)
      end

      def test_anthropic_file_id_becomes_file_document
        block = { type: "file", file_id: "file-xyz", filename: "doc.pdf", mime_type: "application/pdf" }
        result = @anthropic.send(:format_anthropic_content_block, block)
        assert_equal "document", result[:type]
        assert_equal "file", result.dig(:source, :type)
        assert_equal "file-xyz", result.dig(:source, :file_id)
      end

      # --- Gemini blocks ---

      def test_google_format_message_with_blocks
        @google = Google.new(build_config(api_key: "google-test"))
        messages = [{
          role: "user",
          content: [
            { type: "text", text: "What is this?" },
            { type: "image", base64: "QUFB", mime_type: "image/png" }
          ]
        }]

        result = @google.send(:format_message, messages.first)
        parts = result[:parts]
        assert_equal({ text: "What is this?" }, parts[0])
        assert_equal({ inlineData: { mimeType: "image/png", data: "QUFB" } }, parts[1])
      end

      def test_google_file_text_inlines_as_text
        @google = Google.new(build_config(api_key: "google-test"))
        block = { type: "file", data: "hello world", filename: "notes.txt", mime_type: "text/plain" }
        result = @google.send(:format_google_content_block, block)
        assert_equal [{ text: "[notes.txt] hello world" }], result
      end

      def test_google_file_binary_becomes_inline_data
        @google = Google.new(build_config(api_key: "google-test"))
        block = { type: "file", data: "%PDF-1.7", filename: "doc.pdf", mime_type: "application/pdf" }
        result = @google.send(:format_google_content_block, block)
        assert_equal :inlineData, result.first.keys.first
        assert_equal "application/pdf", result.first[:inlineData][:mimeType]
        assert_equal Base64.strict_encode64("%PDF-1.7"), result.first[:inlineData][:data]
      end

      def test_google_file_url_becomes_file_data
        @google = Google.new(build_config(api_key: "google-test"))
        block = { type: "file", url: "gs://bucket/doc.pdf", filename: "doc.pdf", mime_type: "application/pdf" }
        result = @google.send(:format_google_content_block, block)
        assert_equal :fileData, result.first.keys.first
        assert_equal "gs://bucket/doc.pdf", result.first[:fileData][:fileUri]
      end

      private

      def build_config(api_key:)
        config = Object.new
        config.define_singleton_method(:api_key) { api_key }
        config.define_singleton_method(:base_url) { nil }
        config.define_singleton_method(:api_base) { nil }
        config.define_singleton_method(:organization_id) { nil }
        config.define_singleton_method(:project_id) { nil }
        config
      end
    end
  end
end
