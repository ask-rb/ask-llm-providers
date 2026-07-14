# frozen_string_literal: true

require "json"

module Ask
  module LLM
    # Resolves model name aliases to canonical model IDs.
    #
    # Aliases are defined in aliases.json and allow users to refer
    # to models by shorter or more familiar names. Resolution is
    # provider-scoped — you can alias "claude-sonnet-4" to different
    # canonical IDs depending on which provider serves it.
    #
    #   Ask::LLM::Aliases.resolve("claude-sonnet-4")
    #   # => "claude-sonnet-4-6"
    #
    # Aliases are loaded lazily from the bundled JSON file.
    module Aliases
      ALIASES_PATH = File.expand_path("aliases.json", __dir__)

      class << self
        # Resolve an alias to a canonical model ID.
        # Returns the input name unchanged if no alias is registered.
        def resolve(name)
          load_aliases unless @aliases
          @aliases[name.to_s] || name.to_s
        end

        # Register a custom alias at runtime.
        def register(short_name, canonical_id)
          load_aliases unless @aliases
          @aliases[short_name.to_s] = canonical_id.to_s
        end

        # Reload aliases from the bundled JSON file.
        def reload!
          @aliases = nil
          load_aliases
        end

        # All registered aliases (for introspection).
        def all
          load_aliases unless @aliases
          @aliases.dup
        end

        private

        def load_aliases
          @aliases = {}
          path = ALIASES_PATH
          return unless File.exist?(path)

          raw = JSON.parse(File.read(path))
          raw.each { |k, v| @aliases[k.to_s] = v.to_s }
        rescue JSON::ParserError
          # Invalid aliases file — log and use empty map
        end
      end
    end
  end
end
