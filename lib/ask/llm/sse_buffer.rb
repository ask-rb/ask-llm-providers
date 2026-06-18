# frozen_string_literal: true

module Ask
  module LLM
    module SSEBuffer
      def init_sse_buffer
        @_sse_buffer = +""
      end

      def each_sse_event(raw)
        @_sse_buffer ||= +""
        @_sse_buffer << raw

        while (event_end = @_sse_buffer.index("\n\n"))
          event_data = @_sse_buffer.slice!(0, event_end + 2).strip
          next if event_data.empty?

          data_content = extract_data(event_data)
          next if data_content.empty?
          break if data_content == "[DONE]"

          yield data_content
        end
      end

      private

      def extract_data(event_data)
        content = +""
        event_data.each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?(":")
          if line.start_with?("data: ")
            content << line[6..]
          elsif line.start_with?("data:")
            content << line[5..]
          end
        end
        content
      end
    end
  end
end
