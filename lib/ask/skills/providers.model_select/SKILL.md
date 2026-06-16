---
name: providers.model_select
description: How to select the right LLM model for a task — balancing cost, capability, latency, and context window
---

Use this skill when choosing an LLM model for a specific task. The ask-rb
ecosystem uses `Ask::ModelCatalog` to resolve models and check capabilities.

## Step 1: Classify the Task

Determine what kind of task you're solving:

| Task Type | Examples | Key Requirements |
|-----------|----------|-----------------|
| **Simple chat** | Q&A, summarization, translation | Speed, low cost |
| **Code generation** | Write functions, review PRs | Strong coding, large context |
| **Reasoning/analysis** | Debugging, architecture, planning | Deep reasoning, structured output |
| **Structured extraction** | Parse logs, extract data | JSON mode, function calling |
| **Vision/multimodal** | Screenshot analysis, document OCR | Image input support |
| **Long document** | Analyze 100+ page docs | Large context window (200K+) |
| **Embeddings** | Semantic search, RAG | Embedding model, dimensions |

## Step 2: Query the Model Catalog

Access available models through the catalog:

```ruby
# List all models
Ask::ModelCatalog.all

# Filter by capability
Ask::ModelCatalog.chat_models
Ask::ModelCatalog.by_provider("openai")
Ask::ModelCatalog.by_family("gpt")
Ask::ModelCatalog.embedding_models
```

Find a specific model by ID:

```ruby
model = Ask::ModelCatalog.find("gpt-4o")
model.context_window    # => 128000
model.max_output_tokens # => 16384
model.supports?(:function_calling) # => true
model.capabilities      # => ["function_calling", "structured_output", "reasoning", "vision"]
model.modalities        # => { input: ["text", "image"], output: ["text"] }
```

If the catalog doesn't have the model you need, refresh:

```ruby
Ask::ModelCatalog.refresh!
```

## Step 3: Evaluate Cost vs Capability

Use pricing data from the catalog:

```ruby
model = Ask::ModelCatalog.find("gpt-4o")
pricing = model.pricing.dig(:text_tokens, :standard)
pricing[:input_per_million]   # $ per 1M input tokens
pricing[:output_per_million]  # $ per 1M output tokens
```

**Cost comparison (approximate):**

| Tier | Models | Cost/M tokens (in) | Best For |
|------|--------|-------------------|----------|
| **Frontier** | GPT-4o, Claude 4 Sonnet, Gemini 2.5 Pro | $3-15 | Complex reasoning, code generation |
| **Fast/Cheap** | GPT-4o-mini, Claude 4 Haiku, Gemini 2.5 Flash | $0.15-1.00 | Simple chat, extraction, classification |
| **Reasoning** | o3, o4-mini, DeepSeek R1 | $2-10 | Deep analysis, math, multi-step tasks |
| **Specialized** | Embedding, image, audio models | Varies | Non-chat tasks |

## Step 4: Match Capabilities to Task Requirements

Check if a model supports the features you need:

```ruby
model.supports?(:function_calling) # For tool use
model.supports?(:structured_output) # For JSON mode
model.supports?(:vision)           # For image analysis
model.supports?(:reasoning)        # For complex reasoning
```

**Capability requirements by task:**

| Need | Check | Fallback |
|------|-------|----------|
| Tool calling | `supports?(:function_calling)` | Use text instruction instead |
| JSON output | `supports?(:structured_output)` | Prompt-engineering |
| Image processing | `modalities[:input].include?("image")` | Describe image in text |
| Audio processing | `modalities[:input].include?("audio")` | Transcribe first |
| Deep reasoning | `supports?(:reasoning)` | Chain-of-thought prompting |

## Step 5: Consider Context Window Requirements

Choose context window based on your input size:

```ruby
model.context_window  # total tokens the model can process
```

**Guidelines:**
- **8K-16K** — Simple Q&A, short conversations
- **32K-64K** — Code review, medium documents, multi-turn conversations
- **100K-200K** — Large codebases, long documents, RAG with many chunks
- **1M-2M** — Gemini 2.5 Pro, Gemini 2.0 Flash for massive documents

Be aware that large context windows increase latency and cost even if you don't
use them all.

## Step 6: Pick the Right Embedding Model

For RAG and semantic search:

```ruby
Ask::ModelCatalog.embedding_models
```

**Recommendations:**
- **General purpose**: `text-embedding-3-large` (256-3072 dims)
- **Best accuracy**: `text-embedding-3-large` with 3072 dimensions
- **Fast/Cheap**: `text-embedding-3-small` (512 dimensions)
- **Multilingual**: `text-embedding-3-small` (supports 100+ languages)

## Decision Tree

```
Task Type?
├── Simple chat / extraction
│   └── Fast model (GPT-4o-mini, Claude 4 Haiku)
│       → Cheapest adequate model
├── Code generation / review
│   └── Frontier model (GPT-4o, Claude 4 Sonnet)
│       → Needs function calling + max capability
├── Deep reasoning / debugging
│   └── Reasoning model (o4-mini, DeepSeek R1, o3)
│       → Needs chain-of-thought + analysis
├── Long document analysis
│   └── Large context (Gemini 2.5 Pro 1M, GPT-4o)
│       → Needs context window > input size
├── Multimodal (image/video)
│   └── Vision-capable (GPT-4o, Claude 4 Sonnet, Gemini 2.5)
│       → Check modalities[:input] includes image
├── Embeddings / RAG
│   └── text-embedding-3-large / small
│       → Not a chat model
└── Audio / Voice
    └── GPT-4o-audio, Gemini Audio
        → Check modalities[:output] includes audio
```

## Provider Selection

Consider provider reliability and features:

| Provider | Strengths | Weaknesses |
|----------|-----------|------------|
| **OpenAI** | Best tool calling, broad model range | Higher cost for frontier |
| **Anthropic** | Excellent code, long context | Slower for simple tasks |
| **Google Gemini** | Massive context (1M+), fast | Fewer integration tools |
| **DeepSeek** | Cheap reasoning, open weights | Limited ecosystem |
| **Ollama** | Local, free, private | Slow, no hosted offerings |
