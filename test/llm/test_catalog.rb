# frozen_string_literal: true

require_relative "../test_helper"

describe Ask::LLM::Catalog do
  before do
    Ask::ModelCatalog.reset_instance!
    Ask::LLM::Catalog.send(:instance).clear
  end

  it "loads bundled models into Ask::ModelCatalog" do
    Ask::LLM::Catalog.load!
    catalog = Ask::ModelCatalog.instance
    _(catalog.all.length).must_be :>=, 60
  end

  it "loads models with correct providers" do
    Ask::LLM::Catalog.load!
    catalog = Ask::ModelCatalog.instance

    openai = catalog.find("gpt-4o")
    _(openai.provider).must_equal "openai"

    deepseek = catalog.find("deepseek-v4-flash")
    _(deepseek.provider).must_equal "opencode"

    claude = catalog.find("claude-sonnet-4-6")
    _(claude.provider).must_equal "opencode"
  end

  it "does not duplicate models with same id across providers" do
    Ask::LLM::Catalog.load!
    catalog = Ask::ModelCatalog.instance
    matches = catalog.all.select { |m| m.id == "deepseek-v4-flash" }
    _(matches.length).must_be :>=, 2
  end

  it "loads models with correct capabilities" do
    Ask::LLM::Catalog.load!
    gpt4o = Ask::ModelCatalog.instance.find("gpt-4o")
    _(gpt4o.supports?(:vision)).must_equal true
    _(gpt4o.supports?(:function_calling)).must_equal true
    _(gpt4o.supports?(:streaming)).must_equal true
    _(gpt4o.context_window).must_equal 128000
  end

  it "loads reasoning models with reasoning capability" do
    Ask::LLM::Catalog.load!
    model = Ask::ModelCatalog.instance.find("o1")
    _(model.supports?(:reasoning)).must_equal true
  end

  it "loads user config overrides from ~/.ask-llm-providers/models.json" do
    config_path = File.expand_path("~/.ask-llm-providers/models.json")
    config_dir = File.dirname(config_path)
    FileUtils.mkdir_p(config_dir)

    user_models = [
      { "id" => "custom-model", "provider" => "ollama", "context_window" => 65536 }
    ]
    File.write(config_path, JSON.generate(user_models))

    Ask::LLM::Catalog.load!
    model = Ask::ModelCatalog.instance.find("custom-model")
    _(model).wont_be_nil
    _(model.provider).must_equal "ollama"
    _(model.context_window).must_equal 65536
  ensure
    File.delete(config_path) if File.exist?(config_path)
  end

  it "user config overrides bundled model fields" do
    config_path = File.expand_path("~/.ask-llm-providers/models.json")
    config_dir = File.dirname(config_path)
    FileUtils.mkdir_p(config_dir)

    user_models = [
      { "id" => "gpt-4o", "provider" => "openai", "context_window" => 999999 }
    ]
    File.write(config_path, JSON.generate(user_models))

    Ask::LLM::Catalog.load!
    model = Ask::ModelCatalog.instance.find("gpt-4o", "openai")
    _(model.context_window).must_equal 999999
  ensure
    File.delete(config_path) if File.exist?(config_path)
  end

  it "handles missing user config gracefully" do
    config_path = File.expand_path("~/.ask-llm-providers/models.json")
    File.delete(config_path) if File.exist?(config_path)

    Ask::LLM::Catalog.load!
    _(Ask::ModelCatalog.instance.all.length).must_be :>=, 60
  end

  it "handles malformed user config gracefully" do
    config_path = File.expand_path("~/.ask-llm-providers/models.json")
    config_dir = File.dirname(config_path)
    FileUtils.mkdir_p(config_dir)
    File.write(config_path, "not valid json")

    Ask::LLM::Catalog.load!
    _(Ask::ModelCatalog.instance.all.length).must_be :>=, 60
  ensure
    File.delete(config_path) if File.exist?(config_path)
  end

  it "load! is idempotent" do
    Ask::LLM::Catalog.load!
    count1 = Ask::ModelCatalog.instance.all.length
    Ask::LLM::Catalog.load!
    count2 = Ask::ModelCatalog.instance.all.length
    _(count2).must_equal count1
  end

  it "aliases resolve cross-provider model names" do
    Ask::LLM::Aliases.reload!
    _(Ask::LLM::Aliases.resolve("claude-sonnet-4")).must_equal "claude-sonnet-4-6"
    _(Ask::LLM::Aliases.resolve("deepseek-v4")).must_equal "deepseek-v4-flash"
    _(Ask::LLM::Aliases.resolve("unknown-model")).must_equal "unknown-model"
  end

  it "registers custom aliases at runtime" do
    Ask::LLM::Aliases.reload!
    Ask::LLM::Aliases.register("my-model", "gpt-4o")
    _(Ask::LLM::Aliases.resolve("my-model")).must_equal "gpt-4o"
  end

  it "all aliases returns a hash" do
    Ask::LLM::Aliases.reload!
    all = Ask::LLM::Aliases.all
    _(all).must_be_kind_of Hash
    _(all.length).must_be :>=, 9
  end

  it "loads models with modalities" do
    Ask::LLM::Catalog.load!
    model = Ask::ModelCatalog.instance.find("gpt-4o")
    _(model.modalities[:input]).must_include "text"
    _(model.modalities[:input]).must_include "image"
    _(model.modalities[:output]).must_include "text"
  end

  it "loads image models with vision" do
    Ask::LLM::Catalog.load!
    model = Ask::ModelCatalog.instance.find("claude-sonnet-4-6")
    _(model.supports?(:vision)).must_equal true
    _(model.modalities[:input]).must_include "image"
  end

  it "resolves aliases through ModelCatalog.find without provider" do
    Ask::LLM::Catalog.load!
    model = Ask::ModelCatalog.instance.find("deepseek-v4")
    _(model.id).must_equal "deepseek-v4"
    _(model.provider).must_equal "opencode"
  end

  it "resolves aliases through ModelCatalog.find with provider" do
    Ask::LLM::Catalog.load!
    model = Ask::ModelCatalog.instance.find("deepseek-v4", "deepseek")
    _(model.id).must_equal "deepseek-v4"
    _(model.provider).must_equal "deepseek"
  end

  it "alias entry has same capabilities as canonical" do
    Ask::LLM::Catalog.load!
    alias_m = Ask::ModelCatalog.instance.find("deepseek-v4")
    canonical_m = Ask::ModelCatalog.instance.find("deepseek-v4-flash")
    _(alias_m.capabilities).must_equal canonical_m.capabilities
    _(alias_m.context_window).must_equal canonical_m.context_window
  end
end
