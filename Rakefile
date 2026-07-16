require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

desc "Fetch models.dev + OpenRouter data and update bundled model JSONs"
task :"models:update" do
  require "ask-llm-providers"
  require File.expand_path("lib/ask/llm/sources/models_dev", __dir__)
  require File.expand_path("lib/ask/llm/sources/openrouter", __dir__)

  puts "=== models.dev ==="
  Ask::LLM::Sources::ModelsDev.update!

  puts "\n=== OpenRouter ==="
  Ask::LLM::Sources::OpenRouter.update!
end
