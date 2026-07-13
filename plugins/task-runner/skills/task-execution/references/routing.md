# Card agent routing (main-runner only)

Only the main `/task-runner:run` orchestrator routes: it can spawn subagents and can
see the available-agent-types list in its own context. A resolved worker is a **leaf**
that executes and never re-routes. Keep the tag keys below in sync with the vocabulary
in `taskmaster/skills/task-cards/references/agent-tags.md` — `scripts/validate.sh`
fails on drift.

## Resolution map (ordered preference — first reachable wins, else `task-executor`)

```
database      → [database:database-engineer]
frontend      → [web-dev:web-developer]
ui-ux         → [ui-ux:ui-ux-engineer]
security      → [security:security-engineer]
testing       → [testing:test-engineer]
devops        → [devops:devops-engineer]
performance   → [performance:performance-engineer]
observability → [observability:observability-engineer]
backend       → [laravel:backend-engineer, web-dev:web-developer]
api           → [web-dev:web-developer]
generic       → [task-runner:task-executor]
```

A tag's list may gain more-specific specialists over time; the runner walks it in order
and picks the first present in its available-agent-types list.

## Per-card dispatch procedure

1. **Read the tag.** Take the card's `**Agent:**` value. Missing or not in the closed
   vocabulary → treat as `generic` and log the normalization.
2. **Resolve the worker.** Walk the tag's preference list; pick the first agent present
   in the runner's available-agent-types list. If none is reachable, use
   `task-runner:task-executor`. Log any downgrade (requested tag → actual worker) in
   the run report.
3. **Arm scope.** Record the card's declared allowed-files to a per-card artifact,
   e.g. `<cwd>/.claude/task-runner/scope-<cardId>.json` (the runner's own — NOT the
   legacy fixed `scope.json`, which stays the inline path's soft tripwire).
4. **Inject discipline.** Read
   `orchestration/skills/delegation-contracts/references/discipline-preamble.md` and
   paste its text **verbatim** into the dispatch prompt, together with the card and its
   allowed-files. The preamble overrides the worker's own default procedure.
5. **Dispatch** the resolved worker with that prompt.
6. **Enforce + verify on return.** Run a **diff-vs-declared-files check** (git diff of
   the paths the worker touched vs the declared allowed-files); reclaim/reject a card
   that touched out-of-set files. Then re-run the card's exact verify command yourself
   (§ Delegating parallel groups) — this holds whether or not a PostToolUse hook fired
   inside the subagent.

## Notes

- Every mapped agent is equally privileged (Read/Write/Edit/Bash on the same repo); the
  tag selects **aptitude, not authority**. A mis-tag routes to a competent-but-suboptimal
  worker, still scope-bounded by step 6.
- Verify-side routing (matching domain reviewer) is out of scope here — deferred to
  Part C; the runner's generic re-verify remains the gate.
