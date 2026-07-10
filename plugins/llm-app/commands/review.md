---
description: Review an LLM/RAG feature for eval coverage, retrieval quality, prompt-injection, grounding, and cost against llm-app
argument-hint: [path-or-diff]
---

Review the target LLM application code — its failure surface is distinct from ordinary
app logic.

1. Determine scope from $ARGUMENTS — prompt templates, RAG pipeline (chunking,
   embedding, retrieval), agent/tool loops, or a diff. If empty, locate the LLM
   integration in the repo (prompt strings, vector-store calls, model SDK usage) and
   review it.

2. Invoke the `llm-app` skill from this plugin and apply its checklist: an eval set gates
   prompt/model changes with automated scoring; RAG has a retrieval metric separate from
   generation; answers are grounded in and cite retrieved context; prompts are versioned
   artifacts not scattered literals; user/retrieved text is treated as untrusted (explicit
   instruction/data boundary, least-privilege tools, no secrets in context); and cost is
   controlled (`max_tokens` capped, context trimmed, caching, right-sized model).

3. Output findings one line each:
   path:line — severity — problem — fix
   Order by severity. No eval/regression gate, user input concatenated into the system
   prompt, and an uncited RAG answer are the critical classes.

4. Defer, do not duplicate: provider API specifics (model IDs, params, pricing) → the
   claude-api skill (verify live docs); API-key handling → `/secret-scanning:scan`;
   serving/scaling infra → `/devops:review`.

5. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Apply the fixes now (Recommended)" / "Report only". On apply, hand the finding list
   to the shared `task-executor`. In headless or non-interactive runs, report only.
