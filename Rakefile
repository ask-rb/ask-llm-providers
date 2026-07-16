require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

desc "Fetch models.dev data and update bundled model JSONs"
task :"models:update" do
  require_relative "lib/ask/llm/sources/models_dev"
  Ask::LLM::Sources::ModelsDev.update!
end
