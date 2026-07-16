# frozen_string_literal: true

# Fetches model data from the models.dev API and writes enriched per-provider
# JSON files to lib/ask/llm/models/. Run before each release to keep bundled
# model data current with pricing, capabilities, and modalities.
#
# Usage:
#   bundle exec ruby -e "require 'ask/llm/sources/models_dev'; Ask::LLM::Sources::ModelsDev.update!"
#
# Or via Rake:
#   bundle exec rake models:update

require "net/http"
require "json"
require "fileutils"
require "ask"
require "ask-llm-providers"

module Ask
  module LLM
    module Sources
      module ModelsDev
        MODELS_DEV_URL = "https://models.dev/api.json"
        MODELS_DIR = File.expand_path("../models", __dir__)

        # Map from models.dev provider keys to ask-rb provider slugs.
        # Only providers we actually register in ask-llm-providers get a file.
        PROVIDER_MAP = {
          "openai" => "openai",
          "anthropic" => "anthropic",
          "google" => "gemini",
          "google-vertex" => "vertex_ai",
          "amazon-bedrock" => "bedrock",
          "deepseek" => "deepseek",
          "mistral" => "mistral",
          "perplexity" => "perplexity",
          "xai" => "xai",
          "github" => "github"
        }.freeze

        class << self
          # Fetch models.dev, parse into ModelInfo objects, write per-provider JSONs.
          def update!
            puts "Fetching models from models.dev..."
            data = fetch
            models = parse(data)
            write_provider_files(models)
            count = models.length
            puts "Wrote #{count} models across #{PROVIDER_MAP.size} provider files."
            count
          end

          private

          def fetch
            uri = URI(MODELS_DEV_URL)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            http.open_timeout = 15
            http.read_timeout = 30
            request = Net::HTTP::Get.new(uri)
            response = http.request(request)
            raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPOK)
            JSON.parse(response.body)
          end

          def parse(api_response)
            api_response.flat_map do |provider_key, provider_data|
              slug = PROVIDER_MAP[provider_key.to_s]
              next [] unless slug

              models_data = provider_data.dig("models") || {}
              models_data.values.map { |m| build_entry(m, slug) }
            end.compact
          end

          def build_entry(model_data, slug)
            modalities = normalize_modalities(model_data["modalities"])
            {
              id: model_data["id"],
              name: model_data["name"] || model_data["id"],
              provider: slug,
              family: model_data["family"],
              context_window: model_data.dig("limit", "context"),
              max_output_tokens: model_data.dig("limit", "output"),
              capabilities: extract_capabilities(model_data, modalities),
              modalities: modalities,
              pricing: build_pricing(model_data["cost"]),
              knowledge_cutoff: model_data["knowledge"],
              created_at: [model_data["release_date"], model_data["last_updated"]].compact.first
            }.compact
          end

          def normalize_modalities(modalities)
            return { input: [], output: [] } unless modalities
            input = %w[text image audio pdf video file]
            output = %w[text image audio video embeddings moderation]
            {
              input: Array(modalities["input"]).compact & input,
              output: Array(modalities["output"]).compact & output
            }
          end

          def extract_capabilities(model_data, modalities)
            caps = []
            caps << "function_calling" if model_data["tool_call"]
            caps << "structured_output" if model_data["structured_output"]
            caps << "reasoning" if model_data["reasoning"] || model_data["reasoning_options"]
            caps << "vision" if modalities[:input].intersect?(%w[image video pdf])
            caps.uniq
          end

          def build_pricing(cost)
            return {} unless cost
            pricing = {}
            text = {
              input_per_million: cost["input"],
              output_per_million: cost["output"],
              cache_read_input_per_million: cost["cache_read"],
              cache_write_input_per_million: cost["cache_write"],
              reasoning_output_per_million: cost["reasoning"]
            }.compact
            pricing[:text_tokens] = { standard: text } if text.any?
            audio = {
              input_per_million: cost["input_audio"],
              output_per_million: cost["output_audio"]
            }.compact
            pricing[:audio_tokens] = { standard: audio } if audio.any?
            pricing
          end

          def write_provider_files(models)
            FileUtils.mkdir_p(MODELS_DIR)
            grouped = models.group_by { |m| m[:provider] }
            grouped.each do |slug, provider_models|
              path = File.join(MODELS_DIR, "#{slug}.json")
              sorted = provider_models.sort_by { |m| [m[:name].to_s, m[:id].to_s] }
              File.write(path, JSON.pretty_generate(sorted) + "\n")
              puts "  #{slug}.json — #{sorted.length} models"
            end
            # Remove stale provider JSONs
            known_slugs = grouped.keys
            Dir["#{MODELS_DIR}/*.json"].each do |path|
              basename = File.basename(path, ".json")
              next if known_slugs.include?(basename) || basename.start_with?("models_schema")
              File.delete(path)
              puts "  (removed stale #{basename}.json)"
            end
          end
        end
      end
    end
  end
end
