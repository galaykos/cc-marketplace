# Engines and the frozen verdict schema

Two engines answer the same three questions and emit the **same
`verdict.json`**. Downstream tooling (CI gates, reviewers, the command's
reporter) reads the artifact and must never branch on which engine produced it.

## Deterministic engine

- Runs the Playwright project shipped in the plugin's `template/` via
  `npx playwright test`. The verdict's `engine` field reads `"playwright"`.
- Requires `@playwright/test` in the consumer project.
- Exit code is the gate: `0` pass, `1` fail, `2` error (could not run).
- Writes `verdict.json` alongside the exit code for humans and reviewers.
- CI-gateable and repeatable — the same input yields the same verdict.

## Agent engine

- A Claude agent drives `claude-in-chrome` and applies LLM judgment. The
  verdict's `engine` field reads `"agent"`.
- Emits the same `verdict.json` shape but **no shell exit code**
  (`exitCode` is `null`/omitted); the verdict routes through task-execution's
  manual/reviewer branch.
- Non-deterministic by nature (documented risk): re-runs can disagree at the
  margin. Use for reference-light or judgment checks, not a merge gate.

## Selection

Deterministic when the check is a pixel diff AND the reference reduces to a
comparable image (committed baseline or `design-preview` render) AND
`@playwright/test` is present; otherwise the agent engine. An unmet
deterministic prerequisite falls back to the agent, never fabricates a pass.

## Frozen `verdict.json` schema

This shape is **frozen**: card 03's harness implements it literally, and both
engines write exactly this object. Do not rename, reshape, or wrap it.

```json
{
  "status": "pass",
  "engine": "playwright",
  "exitCode": 0,
  "scenario": "home-hero",
  "steps": [
    {
      "id": "home-hero__0",
      "action": "click #toggle",
      "asserts": { "dom": [], "console": [], "layout": [], "network": [] },
      "match": {
        "viewport": "desktop",
        "ratio": 0.004,
        "diffPath": ".visual-check/results/<pid>-<uuid>/home-hero__0__desktop.diff.png",
        "reasons": []
      },
      "pass": true
    }
  ],
  "reasons": [],
  "runDir": ".visual-check/results/<pid>-<uuid>/"
}
```

### Field rules

- `status` ∈ `pass | fail | error` — the top-level verdict; `fail` if any
  step's `pass` is `false`, `error` if the run could not complete.
- `engine` ∈ `playwright | agent` — which engine produced this object.
- `exitCode` ∈ `0 | 1 | 2` for the **playwright** engine only (`0` pass, `1`
  fail, `2` error) — the shell exit code IS the CI gate. The **agent** engine
  has no shell exit code: `exitCode` is `null`/omitted, and `status` alone
  carries the verdict.
- `scenario` — the scenario id this run checked.
- `steps[]` — one entry per scenario step: a stable `id`
  (`<route>__<stepIndex>`), the `action` taken, an `asserts` object whose four
  keys are the "UI not broken" categories (`dom`, `console`, `layout`,
  `network` — each an array of findings, empty when clean), a `match` object
  for the "matches example" comparison (per-`viewport` `ratio`, `diffPath`, and
  `reasons` on failure), and a `pass` boolean for that step.
- `reasons[]` — top-level rollup of every failing reason across all steps.
- `runDir` — the per-run artifact directory
  (`.visual-check/results/<pid>-<uuid>/`) holding diffs, screenshots, and the
  verdict itself.

Payload examples per engine are added in card 12.
