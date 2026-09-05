# frozen_string_literal: true

require "json"
require "date"
require "fileutils"
require "rbconfig"
require "set"

module Ask
  module LLM
    # Orchestrates model catalog loading from multiple sources:
    #
    #   1. Single bundled JSON file lib/ask/llm/models.json (shipped with the gem)
    #      — legacy shard dir lib/ask/llm/models/*.json is still supported
    #   2. OS-specific user cache (~/Library/Caches/ask-llm-providers/models.json
    #      on macOS, $XDG_CACHE_HOME/ask-llm-providers/models.json on Linux)
    #      populated by Catalog.refresh!
    #   3. Explicit user overrides in ~/.ask-llm-providers/models.json
    #   4. Provider API list_models() calls (on explicit refresh!)
    #
    # Mirrors ruby_llm's store → file → bundle fallback and pi's
    # manifest-validated data dir.
    #
    #   Ask::LLM::Catalog.load!          # bundled + cache + user config
    #   Ask::LLM::Catalog.ensure_loaded! # no-op if already loaded (lazy)
    #   Ask::LLM::Catalog.refresh!       # also fetch from provider APIs
    #
    class Catalog
      class Error < StandardError; end
      class LoadError < Error; end

      USER_CONFIG_PATH = File.expand_path("~/.ask-llm-providers/models.json").freeze
      BUNDLED_FILE = File.expand_path("models.json", __dir__).freeze
      LEGACY_SHARD_PATTERN = File.expand_path("models/*.json", __dir__).freeze
      SCHEMA_VERSION = 1

      class << self
        # Load bundled + cached + user overrides into Ask::ModelCatalog.
        # Idempotent — subsequent calls clear and reload.
        def load!
          instance.clear
          instance.load_bundled
          instance.load_cached
          instance.load_user_config
          instance.register_all
          @loaded = true
          true
        end

        # Ensure the catalog has been loaded at least once. Cheap no-op
        # after the first load; lets callers be lazy like ruby_llm.
        def ensure_loaded!
          return true if @loaded
          load!
        end

        def loaded?
          !!@loaded
        end

        # Like load! but also fetches model lists from configured providers'
        # list_models() APIs. Unknown models are added with minimal metadata.
        # Persists the merged result to the OS cache.
        def refresh!
          load!
          instance.fetch_from_providers
          instance.register_all
          instance.persist_cached
          true
        end

        # OS-aware cache path, like ruby_llm's ModelRegistry.cache_path.
        def cache_path
          return @cache_path if defined?(@cache_path) && @cache_path

          env_path = ENV["ASK_LLM_PROVIDERS_CACHE"]
          if env_path && !env_path.strip.empty?
            return @cache_path = env_path
          end

          home = Dir.home
          host_os = RbConfig::CONFIG["host_os"]

          dir = if host_os.match?(/darwin/i)
                  File.join(home, "Library", "Caches", "ask-llm-providers")
                elsif host_os.match?(/mswin|mingw|cygwin/i)
                  local = ENV.fetch("LOCALAPPDATA", nil)
                  local = File.join(home, "AppData", "Local") if local.to_s.empty?
                  File.join(local, "ask-llm-providers", "Cache")
                else
                  xdg = ENV.fetch("XDG_CACHE_HOME", nil)
                  xdg = File.join(home, ".cache") if xdg.to_s.empty?
                  File.join(xdg, "ask-llm-providers")
                end

          @cache_path = File.join(dir, "models.json")
        rescue ArgumentError
          @cache_path = nil
        end

        def cache_etag_path
          cp = cache_path
          cp ? "#{cp}.etag" : nil
        end

        def manifest_path
          cp = cache_path
          cp ? File.join(File.dirname(cp), ".manifest.json") : nil
        end

        def read_cached_etag
          path = cache_etag_path
          return nil unless path && File.file?(path)
          v = File.read(path).strip
          v.empty? ? nil : v
        rescue SystemCallError
          nil
        end

        private

        def write_cached_etag(etag)
          path = cache_etag_path
          return unless path
          if etag && !etag.to_s.strip.empty?
            FileUtils.mkdir_p(File.dirname(path))
            atomic_write(path, "#{etag.strip}\n")
          else
            FileUtils.rm_f(path)
          end
        end

        def write_manifest(data)
          path = manifest_path
          return unless path
          require "digest"
          sorted = data.sort_by { |e| [e["provider"].to_s, e["id"].to_s] }
          hash = Digest::SHA256.hexdigest(JSON.generate(sorted))
          manifest = {
            "schemaVersion" => SCHEMA_VERSION,
            "generatedAt" => Time.now.utc.iso8601,
            "count" => data.size,
            "sha256" => hash
          }
          FileUtils.mkdir_p(File.dirname(path))
          atomic_write(path, JSON.pretty_generate(manifest) + "\n")
        end

        def atomic_write(destination, contents)
          dir = File.dirname(destination)
          FileUtils.mkdir_p(dir)
          basename = File.basename(destination)
          require "tempfile"
          Tempfile.create([basename, ".tmp"], dir) do |tmp|
            tmp.binmode
            tmp.write(contents)
            tmp.flush
            tmp.fsync
            mode = File.exist?(destination) ? (File.stat(destination).mode & 0o7777) : (0o666 & ~File.umask)
            tmp.chmod(mode)
            begin
              File.rename(tmp.path, destination)
            rescue Errno::EACCES, Errno::EEXIST
              FileUtils.rm_f(destination)
              File.rename(tmp.path, destination)
            end
          end
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

      # Load bundled model data. Prefers the single file; falls back to
      # the legacy per-provider shard dir for local dev and for
      # backwards-compatibility if the bundle is absent.
      def load_bundled
        if File.exist?(self.class::BUNDLED_FILE)
          raw = JSON.parse(File.read(self.class::BUNDLED_FILE))
          raw.each { |entry| add_entry(entry) }
        else
          Dir[LEGACY_SHARD_PATTERN].sort.each do |path|
            raw = JSON.parse(File.read(path))
            raw.each { |entry| add_entry(entry) }
          end
        end
      end

      # Load the writable OS cache (populated by refresh!). Valid array
      # entries are merged over the bundle; invalid cache is ignored like
      # ruby_llm's models_from_file.
      def load_cached
        path = self.class.cache_path
        return unless path && File.file?(path)
        raw = JSON.parse(File.read(path))
        return unless raw.is_a?(Array)
        raw.each { |entry| merge_or_add(entry) }
      rescue JSON::ParserError => e
        warn "Warning: Failed to parse cache #{path}: #{e.message}"
      rescue SystemCallError => e
        warn "Warning: Failed to read cache #{path}: #{e.message}"
      end

      # Persist the current entries to the OS cache (used after refresh!).
      def persist_cached
        path = self.class.cache_path
        return unless path
        return if @entries.empty?
        FileUtils.mkdir_p(File.dirname(path))
        data = @entries.sort_by { |e| [(e["provider"] || e[:provider]).to_s, (e["id"] || e[:id]).to_s] }
        # Normalize to string-keyed hashes for stable JSON
        normalized = data.map { |e| e.transform_keys(&:to_s) }
        self.class.send(:atomic_write, path, JSON.pretty_generate(normalized) + "\n")
        self.class.send(:write_manifest, normalized)
      rescue SystemCallError => e
        warn "Warning: Failed to persist cache #{path}: #{e.message}"
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
        catalog = Ask::ModelCatalog.instance
        catalog.instance_variable_set(:@models, [])

        @entries.each do |entry|
          info = build_model_info(entry)
          catalog.register(info)
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

      def deep_symbolize_keys(hash)
        hash.each_with_object({}) { |(k, v), h|
          hk = k.respond_to?(:to_sym) ? k.to_sym : k
          h[hk] = v.is_a?(Hash) ? deep_symbolize_keys(v) : v
        }
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

        modalities = symbolize_keys(e[:modalities]) if e[:modalities]

        pricing = {}
        if e[:pricing] && e[:pricing].any?
          deep_symbolize_keys(e[:pricing]).each { |k, v| pricing[k] = v }
        end

        knowledge_cutoff = safe_parse_date(e[:knowledge_cutoff])
        created_at = safe_parse_date(e[:created_at])

        Ask::ModelInfo.new(
          id: e[:id],
          name: e[:name] || e[:id],
          provider: e[:provider],
          family: e[:family],
          capabilities: Array(e[:capabilities]),
          context_window: e[:context_window],
          max_output_tokens: e[:max_output_tokens],
          modalities: modalities || { input: %w[text], output: %w[text] },
          pricing: pricing,
          knowledge_cutoff: knowledge_cutoff,
          created_at: created_at,
          metadata: (e[:metadata] || {}).merge(source: e[:metadata]&.dig("source") || "bundled")
        )
      end

      def safe_parse_date(value)
        return nil if value.nil?
        return value if value.is_a?(Date)
        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
