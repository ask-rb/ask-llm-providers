require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

desc "Fetch models.dev + OpenRouter data and build the single-file bundled registry"
task :"models:update" do
  require "ask-llm-providers"
  require File.expand_path("lib/ask/llm/sources/models_dev", __dir__)
  require File.expand_path("lib/ask/llm/sources/openrouter", __dir__)

  puts "=== models.dev ==="
  Ask::LLM::Sources::ModelsDev.update!

  puts "\n=== OpenRouter ==="
  Ask::LLM::Sources::OpenRouter.update!

  puts "\n=== build bundled registry ==="
  require "json"
  models_dir = File.expand_path("lib/ask/llm/models", __dir__)
  bundled = File.expand_path("lib/ask/llm/models.json", __dir__)
  entries = Dir[File.join(models_dir, "*.json")].sort.flat_map { |p| JSON.parse(File.read(p)) }
  entries.sort_by! { |e| [e["provider"].to_s, e["id"].to_s] }
  File.write(bundled, JSON.pretty_generate(entries) + "\n")
  puts "  #{bundled} — #{entries.size} models (#{File.size(bundled)} bytes)"

  if entries.size < 100
    warn "WARNING: bundled registry has only #{entries.size} models; expected >100 — aborting"
    exit 1
  end
end

desc "Rebuild lib/ask/llm/models.json from the existing shards without fetching"
task :"models:bundle" do
  require "json"
  models_dir = File.expand_path("lib/ask/llm/models", __dir__)
  bundled = File.expand_path("lib/ask/llm/models.json", __dir__)
  entries = Dir[File.join(models_dir, "*.json")].sort.flat_map { |p| JSON.parse(File.read(p)) }
  entries.sort_by! { |e| [e["provider"].to_s, e["id"].to_s] }
  File.write(bundled, JSON.pretty_generate(entries) + "\n")
  puts "#{bundled} — #{entries.size} models (#{File.size(bundled)} bytes)"
end
