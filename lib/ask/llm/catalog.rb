# frozen_string_literal: true

require "json"
require "fileutils"

module Ask
  module LLM
    # Orchestrates model catalog loading from multiple sources:
    #
    #   1. Bundled JSON files in lib/ask/llm/models/*.json (shipped with the gem)
    #   2. ~/.ask-llm-providers/models.json (user-defined overrides)
    #   3. Provider API list_models() calls (on explicit refresh!)
    #
    # Loaded models are registered into Ask::ModelCatalog for use
    # by ask-agent, ask-mcp, and llm-proxy.
    #
    #   Ask::LLM::Catalog.load!  # load bundled + user config
    #   Ask::LLM::Catalog.refresh!  # also fetch from provider APIs
    #
    class Catalog
      class Error < StandardError; end
      class LoadError < Error; end

      USER_CONFIG_PATH = File.expand_path("~/.ask-llm-providers/models.json").freeze

      class << self
        # Load bundled model definitions and user overrides into Ask::ModelCatalog.
        # Idempotent — subsequent calls clear and reload.
        def load!
          instance.clear
          instance.load_bundled
          instance.load_user_config
          instance.register_all
          true
        end

        # Like load! but also fetches model lists from configured providers'
        # list_models() APIs. Unknown models are added with minimal metadata.
        def refresh!
          load!
          instance.fetch_from_providers
          instance.register_all
          true
        end

      private

      def symbolize_keys(hash)
        hash.transform_keys { |k| k.respond_to?(:to_sym) ? k.to_sym : k }
      end

        def instance
          @instance ||= new
        end
      end

      def initialize
        @entries = []
        @model_keys = Set.new
      end

      def clear
        @entries.clear
        @model_keys.clear
      end

      # Load bundled model JSONs from the gem's lib/ask/llm/models/ directory.
      def load_bundled
        pattern = File.expand_path("models/*.json", __dir__)
        Dir[pattern].sort.each do |path|
          raw = JSON.parse(File.read(path))
          raw.each { |entry| add_entry(entry) }
        end
      end

      # Load user-defined model overrides from ~/.ask-llm-providers/models.json.
      # Silently skipped if the file doesn't exist.
      def load_user_config
        path = USER_CONFIG_PATH
        return unless File.exist?(path)

        raw = JSON.parse(File.read(path))
        unless raw.is_a?(Array)
          warn "Warning: #{path} should be a JSON array of model entries, got #{raw.class}"
          return
        end

        raw.each { |entry| merge_or_add(entry) }
      rescue JSON::ParserError => e
        warn "Warning: Failed to parse #{path}: #{e.message}"
      end

      # Fetch model lists from all configured providers via their list_models() API.
      # Adds unknown models with minimal metadata (no capability guessing).
      def fetch_from_providers
        Ask::Provider.providers.each do |slug, provider_class|
          next unless provider_class.configured?(nil)

          begin
            provider = provider_class.new
            models = provider.list_models
            models.each do |m|
              add_entry(m) unless @model_keys.include?([m[:id], slug.to_s])
            end
          rescue StandardError => e
            warn "Warning: Failed to fetch models from #{slug}: #{e.message}"
          end
        end
      end

      # Register all accumulated entries into Ask::ModelCatalog.
      # Also registers alias entries so models can be found by alias name.
      def register_all
        @entries.each do |entry|
          info = build_model_info(entry)
          Ask::ModelCatalog.instance.register(info)
        end

        register_alias_entries
      end

      private

      # For each alias (short_name → canonical_id), register a duplicate
      # ModelInfo for every canonical entry whose id matches.
      def register_alias_entries
        Ask::LLM::Aliases.all.each do |short_name, canonical_id|
          next if short_name == canonical_id

          @entries.each do |entry|
            next unless entry["id"] == canonical_id || entry[:id] == canonical_id

            alias_entry = entry.merge("id" => short_name)
            info = build_model_info(alias_entry)
            Ask::ModelCatalog.instance.register(info)
          end
        end
      end

      def symbolize_keys(hash)
        hash.transform_keys { |k| k.respond_to?(:to_sym) ? k.to_sym : k }
      end

      def add_entry(entry)
        key = entry_key(entry)
        return if @model_keys.include?(key)

        @entries << entry
        @model_keys << key
      end

      def merge_or_add(entry)
        key = entry_key(entry)
        existing = @entries.find { |e| entry_key(e) == key }

        if existing
          existing.merge!(entry)
        else
          @entries << entry
          @model_keys << key
        end
      end

      def entry_key(entry)
        id = entry["id"] || entry[:id]
        provider = entry["provider"] || entry[:provider]
        [id, provider.to_s]
      end

      def build_model_info(entry)
        e = entry.transform_keys(&:to_sym)
        modalities = e[:modalities]
        modalities = symbolize_keys(modalities) if modalities

        Ask::ModelInfo.new(
          id: e[:id],
          name: e[:name] || e[:id],
          provider: e[:provider],
          family: e[:family],
          capabilities: Array(e[:capabilities]),
          context_window: e[:context_window],
          max_output_tokens: e[:max_output_tokens],
          modalities: modalities || { input: %w[text], output: %w[text] },
          pricing: e[:pricing] || {},
          knowledge_cutoff: e[:knowledge_cutoff] ? Date.parse(e[:knowledge_cutoff].to_s) : nil,
          created_at: e[:created_at] ? Date.parse(e[:created_at].to_s) : nil,
          metadata: (e[:metadata] || {}).merge(source: e[:metadata]&.dig("source") || "bundled")
        )
      rescue Date::Error
        Ask::ModelInfo.new(id: e[:id], provider: e[:provider])
      end
    end
  end
end
