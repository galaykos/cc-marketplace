---
name: visual-verification
description: Use when you need to prove a web UI actually renders correctly — that a page works, its layout is not broken, and it matches an approved example — beyond what DOM or unit assertions can see. Runs two interchangeable engines that emit the same verdict.json: a deterministic Playwright suite (exit 0/1/2, CI-gateable) and a Claude agent driving claude-in-chrome with LLM judgment. Read-only by default; reuses the playwright navigator and design-preview rather than reimplementing either.
---

## Purpose

This skill runs **Full Visual QA** on a web UI: it drives a real browser,
captures what actually rendered, and answers three questions with evidence a
DOM or unit assertion cannot give. It does not reimplement browser automation
or component rendering — it orchestrates the `playwright` navigator and
`design-preview`, and records a single verdict artifact both engines share.

Reach for it after a change that could alter rendered output (styles, layout,
component swaps, data wiring) and before you trust that a page still looks and
behaves as approved.

## The three questions

Every run answers exactly these, in order, and reports `fail` on the first that
fails:

1. **Works** — the page loads, becomes interactive, and the primary flow the
   scenario names completes without a fatal error.
2. **UI not broken** — the rendered layout, styling, and content pass the four
   assertion categories below, independent of any reference image.
3. **Matches example** — the render matches an approved reference from one of
   the four sources, within the scenario's tolerance.

## Two engines, one verdict

Both engines write the **same `verdict.json` shape** (frozen in
`references/engines.md`). Downstream tooling reads the artifact, never the
engine. Only the production path differs.

### Deterministic engine

The plugin's `template/` ships a Playwright project. A run is
`npx playwright test`, which exits `0` (pass), `1` (fail — a question failed or
a diff exceeded tolerance), or `2` (error — the run could not complete). It
requires `@playwright/test` in the consumer project and is **CI-gateable**: the
exit code is the gate, and `verdict.json` is written for humans and reviewers.

### Agent engine

A Claude agent drives `claude-in-chrome` and applies LLM judgment to the same
questions, then writes the same `verdict.json` shape. It produces **no shell
exit code**, so it routes through task-execution's manual/reviewer branch rather
than a CI gate. Its judgment is **non-deterministic** — a documented risk:
re-runs can disagree at the margin, so it suits exploratory and reference-light
checks, not a merge gate.

### Engine selection

Prefer the deterministic engine when **both** hold: the check is a pixel diff,
and the reference reduces to a comparable image (a committed baseline or a
`design-preview` render) with `@playwright/test` available. Otherwise — no image
reference, Playwright absent, or a judgment call ("does this read as broken?")
— use the agent engine. A scenario may pin an engine explicitly; an unmet
deterministic prerequisite falls back to the agent and never fabricates a pass.

## Command surface

The plugin exposes one `check` command (authored in a later card) whose flags
select scope and posture, not behavior the skill does not already define:

- a URL or scenario id to check;
- `--engine deterministic|agent|auto` (default `auto` — apply the selection
  rule above);
- `--against <image|url>` to point at a reference source (see below); omitted
  falls back to the golden baseline or, for the agent engine, a taskmaster
  `## Visual contract` block;
- `--update-baseline` to bless the current render as the new approved image
  (guarded — see Safety posture);
- `--ci` to force exit-code semantics and suppress interactive prompts.

The resolved flag list lives in `references/wiring.md`.

## Reference sources — where the example comes from

The "matches example" question compares against one of four sources, declared
per scenario (format in `references/scenario-schema.md`):

1. **`--against <image>`** — a user-supplied reference image (an export or an
   attached picture) to check a first implementation against intent.
2. **Golden baseline** — a committed
   `.visual-check/baselines/<route>__<step>__<viewport>.png`; the default for
   regression gating when no `--against` is given.
3. **`--against <url>`** — a live or staging URL captured at run time, for an
   A/B comparison against a second environment.
4. **Taskmaster `## Visual contract` prose** — a textual criterion block, judged
   by the **agent engine only**; it is never pixel-diffed.

## "UI not broken" — four assertion categories

Question 2 is decided by four independent categories — the same four keys the
verdict's per-step `asserts` object carries; any one failing fails the
question, and the verdict names which:

1. **`dom`** — DOM/functional state: an element is visible, hidden, exists, or
   carries the expected text.
2. **`console`** — console output and uncaught page errors.
3. **`layout`** — layout-integrity heuristics: overflow, a blank render,
   zero-size containers, unexpected overlap.
4. **`network`** — network failures: 4xx/5xx responses, broken assets.

## Safety posture

- **Read-only by default.** A check navigates and captures; it does not submit
  forms, mutate app state, or write into the source tree unless a scenario
  explicitly opts in and the user consents.
- **Consent before writes.** Anything that touches the repo (saving a baseline,
  writing scenario files) or drives a mutating flow is asked for first, naming
  the exact artifacts.
- **Baseline-commit warning.** `--update-baseline` blesses the current render as
  truth; a wrong baseline silently launders a regression into "expected."
  Committing or overwriting a baseline is a deliberate, consented step, never an
  automatic side effect of a run.
- **URL & egress guards.** Navigation is limited to the scenario's allowed
  origins (localhost and declared dev hosts by default). Production or arbitrary
  external hosts require explicit consent; nothing is exfiltrated and no unlisted
  origin is contacted.

## References

- `references/scenario-schema.md` — the scenario file format: URL, viewports,
  reference source, tolerance, and assertions.
- `references/engines.md` — the two engines in depth and the **frozen
  `verdict.json` schema** both emit.
- `references/wiring.md` — how the `template/`, the `playwright` navigator, and
  `design-preview` compose, plus the resolved command surface and CI wiring.
