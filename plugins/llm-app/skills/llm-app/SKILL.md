---
name: llm-app
description: Use when building or reviewing an LLM application — RAG pipelines (chunking, embeddings, retrieval quality), eval harnesses and regression testing, prompt versioning, token-cost control, prompt-injection defense, hallucination mitigation, and context-window management. The distinct failure surface of LLM-backed features, which ordinary app testing does not cover.
---

# LLM application engineering

An LLM feature fails in ways ordinary code does not: it is non-deterministic, it
confidently invents facts, its "API" is a prompt that silently regresses, and its cost
scales with tokens you may not be counting. The discipline that tames it is **evaluate,
don't eyeball** — you cannot ship changes to a probabilistic system on vibes.

## Evals are the test suite

A prompt or model change has no unit test unless you build one. Before iterating:

- **Build an eval set** — representative inputs with expected properties (not always an
  exact string; often a rubric: "cites a source", "refuses politely", "valid JSON").
- **Score automatically** where you can — exact match, JSON-schema validity, regex,
  embedding similarity, or an **LLM-as-judge** for open-ended quality (with its own
  rubric and a check against human labels).
- **Regression-gate** — run the eval set on every prompt/model change; a change that
  improves one case and breaks three is caught only if you measure all of them. "It
  looked better in my one test" is how LLM apps rot.

## RAG: retrieval quality is the product

Most RAG failures are retrieval failures, not generation failures — the model answers
well from bad context or refuses from missing context.

- **Chunking** — size chunks to a coherent unit of meaning (a section, not a fixed 500
  chars mid-sentence); overlap so a fact split across a boundary is still retrievable.
- **Embeddings + store** — pick an embedding model suited to your domain; store in a
  vector DB with metadata for filtering (tenant, recency, source).
- **Retrieve then re-rank** — top-k vector search is coarse; a re-ranker over the
  candidates sharply improves what actually reaches the prompt.
- **Measure retrieval** separately from generation — recall@k on a labeled set tells
  you whether the right chunk was even fetched before you blame the model.
- **Ground and cite** — instruct the model to answer only from retrieved context and
  cite it; a RAG answer with no source is a hallucination with extra steps.

## Prompts are versioned artifacts

A prompt is code: version it, review changes, and tie each version to its eval scores.
An undocumented tweak to a production prompt is an unreviewed deploy. Keep prompts out
of scattered string literals; centralize them so they can be diffed and rolled back.

## Prompt injection is the new input validation

Any text from a user or a retrieved document can carry instructions ("ignore previous
instructions and…"). Treat all non-system content as untrusted:

- **Separate instructions from data** — never concatenate user input into the system
  prompt as if it were trusted; keep the boundary explicit.
- **Least privilege on tools** — an LLM with tool access is an RCE surface; scope tools
  tightly, and never let retrieved content trigger a destructive action without a check.
- **Don't echo secrets into context** — anything in the prompt can be exfiltrated by a
  crafted injection.

## Cost and latency

- **Count tokens** — cost scales with input+output tokens; a bloated context or an
  unbounded output is a bill. Cap `max_tokens`, trim context to what retrieval justifies.
- **Cache** — prompt caching for stable prefixes, and cache identical requests; the
  cheapest LLM call is the one you did not make.
- **Right-size the model** — do not send a summarization to the frontier model when a
  smaller one passes the eval. Route by task difficulty.

## Reach for the simplest that works

Do not jump to the heavy tool:

| Need | Reach for |
|---|---|
| Answer over your private/changing docs | RAG (retrieval) |
| Shape/format/tone of output | prompt engineering + few-shot |
| A fixed narrow skill, high volume, latency-critical | fine-tune a small model |
| Multi-step task with tools | an agent loop — but bound it |

Fine-tuning to add *knowledge* is usually the wrong tool (RAG updates without retraining);
fine-tune for *behavior*, retrieve for *facts*.

## Reviewing an LLM feature

- An eval set exists and gates prompt/model changes; scoring is automated where possible.
- RAG has a retrieval metric (recall@k) separate from generation quality.
- Answers are grounded in and cite retrieved context; no source = flagged.
- Prompts are versioned artifacts, not scattered literals.
- User/retrieved text is untrusted: instruction/data boundary explicit, tools least-priv.
- `max_tokens` capped, context trimmed, caching used, model right-sized to the task.

## Defer rule

- Provider API specifics (model IDs, pricing, params, the Messages/tool-use API) →
  the claude-api skill; verify current docs, do not answer model facts from memory.
- Secret handling for API keys → `secret-scanning`.
- Serving/infra (rate limits, scaling the vector DB) → `devops`.

## Anti-patterns

- **Eyeballing changes** — shipping prompt/model edits with no eval set or regression gate.
- **RAG with no retrieval metric** — blaming the model for a fetch that missed the chunk.
- **Prompt as scattered string literals** — unversioned, undiffable, un-rollback-able.
- **User input concatenated into the system prompt** — a prompt-injection open door.
- **Uncapped output / unbounded context** — a latency and cost surprise.
- **Uncited RAG answer** — a hallucination the UI presents as sourced fact.
