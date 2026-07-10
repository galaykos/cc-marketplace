# llm-app

Building LLM-backed features — the failure surface ordinary app testing does not cover.

- **`llm-app` skill** — evals as the test suite (regression-gate prompt/model changes),
  RAG where retrieval quality is the product (chunking, embeddings, re-ranking, grounded
  citation, recall@k), prompts as versioned artifacts, prompt-injection as the new input
  validation, and token-cost/latency control. Includes a RAG-vs-fine-tune-vs-prompt aid.
- **`/llm-app:review`** — flag the critical classes: no eval/regression gate, user input
  concatenated into the system prompt, uncited RAG answers, uncapped cost.

Defers provider API specifics (model IDs, params, pricing) to the claude-api skill —
verify live docs, never answer model facts from memory.
