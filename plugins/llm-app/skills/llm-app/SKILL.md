---
name: llm-app
description: Use when building or reviewing an LLM application — RAG pipelines (chunking, embeddings, retrieval quality), eval harnesses, prompt versioning, token-cost control, prompt-injection defense, hallucination mitigation, context-window management.
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

Injection defense is one face of the app's security posture: auth around the
LLM endpoint, secret handling, and data privacy belong to the security
plugin's skills (`api-auth`, `data-privacy`, threat-modeling) — run
`/security:review` on the integration when the security plugin is installed,
not just this checklist.

## Cost and latency

- **Count tokens** — cost scales with input+output tokens; a bloated context or an
  unbounded output is a bill. Cap `max_tokens`, trim context to what retrieval justifies.
- **Cache** — prompt caching for stable prefixes, and cache identical requests; the
  cheapest LLM call is the one you did not make.
- **Right-size the model** — do not send a summarization to the frontier model when a
  smaller one passes the eval. Route by task difficulty.

## Context-window management

The window is a budget with a hard edge, and the failure is not an error — it is a
silently worse answer. Three things to get right:

- **Know the ceiling and measure against it, not against vibes.** Count tokens
  before the call (the provider's token-counting endpoint, not a character
  heuristic), and set the ceiling from the model actually configured, not the one
  the code was written for. A prompt that fit last quarter's model is not a
  guarantee.
- **Decide the eviction policy explicitly.** A growing chat history needs a named
  rule for what leaves: a sliding window over recent turns, a running summary of
  older ones, or retrieval over the transcript so old turns come back only when
  relevant. Choosing nothing means the policy is "truncate at the front", which
  silently drops the system prompt's neighbours first.
- **Protect the two ends.** Instructions and the current task belong where
  truncation cannot reach them; the middle is where a long context loses
  attention, so put what must be used at the edges rather than buried. Order
  matters for caching too: a stable prefix is what makes prompt caching pay, so
  keep the volatile part last.

More window is not the same as more useful context. Filling a large window with
marginally relevant chunks measurably degrades answers and always costs more —
retrieval quality (above) is what decides how much of the window is worth
spending.

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
- The context window has a named eviction policy and a token count measured against
  the configured model's ceiling, not assumed to fit.

## Defer rule

- Provider API specifics (model IDs, pricing, params, the Messages/tool-use API) →
  Claude Code's built-in claude-api skill (harness-provided, not a marketplace
  plugin); verify current docs, do not answer model facts from memory.
- Secret handling for API keys → `secret-scanning`.
- Serving/infra (rate limits, scaling the vector DB) → `devops`.

## Anti-patterns

- **Eyeballing changes** — shipping prompt/model edits with no eval set or regression gate.
- **RAG with no retrieval metric** — blaming the model for a fetch that missed the chunk.
- **Prompt as scattered string literals** — unversioned, undiffable, un-rollback-able.
- **User input concatenated into the system prompt** — a prompt-injection open door.
- **Uncapped output / unbounded context** — a latency and cost surprise.
- **No eviction policy** — a chat history that grows until the provider truncates
  it, so what gets dropped is decided by position rather than by importance.
- **Uncited RAG answer** — a hallucination the UI presents as sourced fact.
