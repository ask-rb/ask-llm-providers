# frozen_string_literal: true

require "net/http"
require "json"
require "fileutils"
require "set"

module Ask
  module LLM
    module Sources
      module OpenRouter
        API_URL = "https://openrouter.ai/api/v1/models"
        MODELS_DIR = File.expand_path("../models", __dir__)

        PROVIDER_MAP = {
          "openai"      => "openai",
          "anthropic"   => "anthropic",
          "google"      => "gemini",
          "deepseek"    => "deepseek",
          "mistralai"   => "mistral",
          "meta-llama"  => "meta",
          "x-ai"        => "xai",
          "perplexity"  => "perplexity",
          "amazon"      => "bedrock",
          "groq"        => "groq",
          "together"    => "together",
          "fireworks"   => "fireworks",
          "cerebras"    => "cerebras",
          "moonshotai"  => "moonshot",
          "nvidia"      => "nvidia_nim",
          "cohere"      => nil,
          "qwen"        => nil,
          "minimax"     => nil,
          "z-ai"        => nil,
          "replicate"   => nil,
          "nousresearch" => nil
        }.freeze

        # All provider slugs we support (canonical + OpenAI-compatible).
        REGISTERED_SLUGS = %w[
          openai anthropic gemini bedrock ollama mistral cloudflare
          aiml ai21 anyscale cerebras deepinfra deepseek
          featherless fireworks friendli github groq hyperbolic
          meta mimo moonshot nebius novita nscale nvidia_nim
          opencode opencode_go openrouter perplexity sambanova
          together xai
        ].to_set.freeze

        class << self
          def update!
            models = fetch
            entries = parse(models)
            write_provider_files(entries)
            total = entries.length
            providers = entries.group_by { |e| e[:provider] }.size
            puts "OpenRouter: #{total} models across #{providers} providers."
            total
          end

          private

          def fetch
            uri = URI(API_URL)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            http.open_timeout = 15
            http.read_timeout = 30
            request = Net::HTTP::Get.new(uri)
            response = http.request(request)
            raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPOK)
            JSON.parse(response.body).dig("data") || []
          end

          def parse(models)
            models.filter_map do |m|
              provider_prefix = m["id"].split("/").first
              slug = PROVIDER_MAP[provider_prefix]
              next unless slug && REGISTERED_SLUGS.include?(slug)

              pricing = build_pricing(m["pricing"] || {})
              capabilities = extract_capabilities(m)
              modalities = extract_modalities(m)

              {
                id: m["id"].sub("#{provider_prefix}/", ""),
                name: m["name"] || m["id"],
                provider: slug,
                context_window: m["context_length"],
                max_output_tokens: m["top_provider"]&.dig("max_completion_tokens"),
                capabilities: capabilities,
                modalities: modalities,
                pricing: pricing,
                architecture: m.dig("architecture", "modality"),
                source: "openrouter"
              }.compact
            end
          end

          def build_pricing(pricing)
            return {} unless pricing.is_a?(Hash)

            text = {
              input_per_million: to_per_million(pricing["prompt"]),
              output_per_million: to_per_million(pricing["completion"]),
              cache_read_input_per_million: to_per_million(pricing["input_cache_read"]),
              cache_write_input_per_million: to_per_million(pricing["input_cache_write"]),
              reasoning_output_per_million: to_per_million(pricing["reasoning"])
            }.compact

            result = {}
            result[:text_tokens] = { standard: text } if text.any?

            image = {
              input_per_million: to_per_million(pricing["image"]),
              output_per_million: to_per_million(pricing["request_image"])
            }.compact
            result[:images] = { standard: image } if image.any?

            result
          end

          def to_per_million(value)
            return nil unless value
            (value.to_f * 1_000_000).round(10)
          end

          def extract_capabilities(model)
            caps = []
            caps << "function_calling" if model.dig("features", "tool_call")
            caps << "streaming" if model.dig("features", "streaming")
            caps << "vision" if model.dig("architecture", "modality") == "text+image->text"
            caps << "reasoning" if model.dig("features", "reasoning")
            caps.uniq
          end

          def extract_modalities(model)
            modality = model.dig("architecture", "modality")
            case modality
            when "text+image->text"
              { input: %w[text image], output: %w[text] }
            else
              { input: %w[text], output: %w[text] }
            end
          end

          def write_provider_files(entries)
            FileUtils.mkdir_p(MODELS_DIR)
            grouped = entries.group_by { |e| e[:provider] }

            existing = {}
            Dir["#{MODELS_DIR}/*.json"].each do |path|
              base = File.basename(path, ".json")
              next if base == "models_schema"
              existing[base] = JSON.parse(File.read(path))
            end

            grouped.each do |slug, new_entries|
              existing_entries = existing[slug] || []
              added = merge_with_existing(existing_entries, new_entries)
              merged = existing_entries + added
              path = File.join(MODELS_DIR, "#{slug}.json")
              sorted = merged.sort_by { |m| [m["name"]&.to_s || m[:name].to_s, m["id"]&.to_s || m[:id].to_s] }
              File.write(path, JSON.pretty_generate(sorted) + "\n")
              puts "  #{slug}.json — #{sorted.length} models (#{added.length} new from OpenRouter)"
            end
          end

          def merge_with_existing(existing, new_entries)
            existing_ids = existing.map { |e| e["id"] || e[:id] }.to_set
            new_entries.reject { |e| existing_ids.include?(e[:id]) }
          end
        end
      end
    end
  end
end
