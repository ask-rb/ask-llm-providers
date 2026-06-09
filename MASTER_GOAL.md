# MASTER_GOAL.md — ask-llm-providers

## Purpose

This is the **master goal** for building ask-llm-providers. It does not implement the gem
directly. It loads and follows the detailed build plan at:

> **GOAL.md:** `/Users/kaka/Code/ask-rb/ask-llm-providers/GOAL.md`

## How To Use This Goal

1. Open the GOAL.md at the path above
2. Follow every section in order: Purpose, Dependencies, Implementation Steps, Testing, Release
3. Do NOT deviate from the plan — every step is documented for a reason
4. When done, verify against the Release Checklist at the bottom of GOAL.md
5. Report completion status back to this master goal

## Context

All ask-rb gem repos are available locally at `/Users/kaka/Code/ask-rb/`.
Key reference projects for this gem to study:

- **Source:** `/Users/kaka/Code/ask-rb/ask-llm-providers/lib/`
- **Tests:** `/Users/kaka/Code/ask-rb/ask-llm-providers/test/`
- **Goal:** `/Users/kaka/Code/ask-rb/ask-llm-providers/GOAL.md`
- **Remote:** `git@github.com:ask-rb/ask-llm-providers.git`
- **RubyLLM providers (source to study):** /Users/kaka/Code/ask-rb/ruby_llm/lib/ruby_llm/providers/
- **llm-proxy protocols:** /Users/kaka/Code/ask-rb/llm-proxy/lib/llm_proxy/protocols/
- **Pi providers:** /Users/kaka/Code/ask-rb/pi/packages/ai/src/providers/

## Dependencies
This gem depends on:
- [ ] ask-core v0.1.0 (provides Ask::Provider interface)
- [ ] ask-auth v0.1.0 (provides credential resolution)
- [ ] ask-schema v0.1.0 (provides JSON Schema DSL)

## Build Steps (Outline)

The GOAL.md at `/Users/kaka/Code/ask-rb/ask-llm-providers/GOAL.md` contains the full
implementation steps. Follow it in order. Key milestones:

1. Define gem scaffold (gemspec, entry point, version)
2. Implement core classes per GOAL.md
3. Write tests for every public method
4. Run full test suite — fix all failures
5. Verify Release Checklist
6. Build and release as private gem

## Release Checklist (from GOAL.md)

See the bottom of `/Users/kaka/Code/ask-rb/ask-llm-providers/GOAL.md` for the full checklist.

## Completion

When done, this gem reaches v0.1.0:
- All tests pass (>90% coverage)
- Gem builds without errors
- Released as private gem on GitHub Packages
- README is complete
- CHANGELOG.md exists with v0.1.0 entry
- ask-docs is updated (if applicable)
