require_relative "lib/ask/llm/version"

Gem::Specification.new do |spec|
  spec.name = "ask-llm-providers"
  spec.version = Ask::LLM::VERSION
  spec.authors = ["Kaka Ruto"]
  spec.email = ["kaka@myrrlabs.com"]

  spec.summary = "All LLM providers for the ask-rb ecosystem"
  spec.description = "Supports OpenAI, Anthropic, Google Gemini + Vertex, Amazon Bedrock, " \
                     "Ollama (local), Mistral AI, and Cloudflare Workers AI + AI Gateway. " \
                     "One gem, all the models you need."
  spec.homepage = "https://github.com/ask-rb/ask-llm-providers"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ask-core", "~> 0.1"
  spec.add_dependency "ask-auth", "~> 0.1"

  # OpenAI-compatible — uses Faraday (already in ask-core)
  # Anthropic — uses Faraday
  # Google — uses Faraday + google-apis-generator (for Vertex)
  # Bedrock — uses aws-sdk-bedrockruntime
  spec.add_dependency "faraday", ">= 2.0"
  spec.add_dependency "faraday-multipart", ">= 1.0"
  spec.add_dependency "json"

  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "mocha", "~> 3.1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "webmock", "~> 3.26"
end
