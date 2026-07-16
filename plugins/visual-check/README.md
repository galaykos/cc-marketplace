# visual-check

Visual QA verification for web UIs: drives a real browser to capture rendered
screenshots and diff them against an approved baseline to catch layout shifts,
broken styles, and render regressions that DOM assertions miss. It reuses the
`playwright` navigator to drive the browser and `design-preview` for
real-component rendering rather than reimplementing either.

Every run answers three questions with evidence a unit or DOM assertion cannot
give: **works** (the page loads and the flow completes), **UI not broken** (the
four assertion categories — `dom`, `console`, `layout`, `network` — pass), and
**matches example** (the render matches an approved reference within tolerance).

## Install

Add this marketplace, then install the plugin:

```
/plugin marketplace add <this-repo>
/plugin install visual-check
```

Installing pulls in its declared dependencies (`playwright`, `design-preview`).
The deterministic engine additionally needs `@playwright/test` resolvable in the
consumer project; without it the plugin falls back to the agent engine.

## Command surface

One command, `/visual-check:check`, driven by `$ARGUMENTS`:

| Flag | Effect |
| ---- | ------ |
| `--url <url>` | Target to render (http(s) or a local path → `file://`). **Optional** — omit it to launch/reuse a dev server. |
| `--against <base>` | Reference base name; resolves per viewport to `<base>__desktop.png` / `<base>__mobile.png`. |
| `--scenario <file>` | Drive a declarative multi-step YAML flow (see below). |
| `--baseline` | Diff against the committed golden-baseline store (`.visual-check/baselines/`). |
| `--update` | Bless the current render as the reference baseline (guarded — see Safety). |
| `--ack-commit` / `--ack-dirty` | Acknowledge the `--update` commit/PII and dirty-tree guards. |
| `--ack-egress` | Acknowledge a non-local target so the run may proceed. |
| `--init` | Scaffold `.visual-check/config.json` + an example scenario, then exit. |
| `--contract <specfile>` | A textual visual criterion — judged by the agent engine only, never pixel-diffed. |
| `--viewport <name>` | Run one configured viewport instead of all. |

The underlying harness (`template/bin/visual-check.mjs`) exits `0` (pass) / `1`
(fail) / `2` (error) and writes `verdict.json` into a per-run directory
`.visual-check/results/<pid>-<uuid>/`.

## `config.json`

`--init` writes `.visual-check/config.json` — the committed project defaults:

```json
{
  "threshold": 0.01,
  "viewports": [
    { "name": "desktop", "width": 1280, "height": 800 },
    { "name": "mobile", "width": 390, "height": 844 }
  ],
  "mask": ["[data-testid=clock]"],
  "allowLlmEngine": true
}
```

- `threshold` — max fraction of differing pixels for a `match` to pass.
- `viewports` — sizes captured on every run (name feeds the capture key).
- `mask` — selectors painted out before every capture (clocks, avatars).
- `allowLlmEngine` — set `false` to forbid the agent engine (its screenshots
  egress to a model) for sensitive UIs.

Settings resolve by precedence: **CLI flag > scenario file > `config.json` >
built-in default**.

## Scenario schema

A scenario is one page, an ordered list of steps that drive it, and the
assertions and visual checkpoints taken along the way. Step verbs are frozen —
`goto · click · type · hover · wait · expect · match`. `expect` holds the four
"UI not broken" categories; `match` holds a visual checkpoint. A state-changing
step must be author-marked `mutates: true` **and** the scenario must set
`allowMutations: true`, or the run is refused. Full format:
`skills/visual-verification/references/scenario-schema.md`.

## Two engines, one verdict

Both engines emit the **same frozen `verdict.json`**
(`skills/visual-verification/references/engines.md`); downstream tooling reads the
artifact, never the engine.

- **Deterministic engine** — the Playwright project in `template/`, run via `npx
  playwright test`. Requires `@playwright/test`. Exit code is the gate (`0/1/2`),
  repeatable and **CI-gateable**. Runs when the check is a pixel diff against a
  comparable image (a committed baseline or a `design-preview` render).
- **Agent engine** — a Claude agent (`visual-check-engineer`) drives
  `claude-in-chrome` with LLM judgment and writes the same verdict shape with **no
  shell exit code**. Runs when Playwright is absent, there is no image reference,
  or the check is a judgment call (a `--contract` prose criterion). It routes
  through task-execution's manual/reviewer branch, never a merge gate.

Selection is automatic (`--engine auto`); an unmet deterministic prerequisite
falls back to the agent and never fabricates a pass. See
`skills/visual-verification/references/wiring.md` for both integration recipes.

## Safety guards

- **Read-only by default.** A check navigates and captures; it never submits
  forms or mutates app state unless a scenario opts in (`mutates:` +
  `allowMutations:`) and the run is announced.
- **Consent before writes.** First use asks for explicit opt-in before creating
  `.visual-check/`, launching a server, or driving a browser.
- **Baseline-commit warning.** `--update` blesses a render as truth and commits a
  screenshot to git; it is refused on a dirty tree (unless `--ack-dirty`) and
  until `--ack-commit` acknowledges the captures may embed auth/PII data.
- **URL & egress guards.** Before driving, the target is classified. A localhost /
  dev-host / `file://` target runs freely; a production, internal private-network,
  or cloud-metadata host is non-local — it warns and refuses (exit `2`) until
  `--ack-egress`, so a check never silently drives a live site or lets a metadata
  endpoint exfiltrate cloud credentials. The agent engine additionally honors
  `allowLlmEngine: false`, declining rather than sending screenshots to a model.

## Determinism trade-off

The deterministic engine is repeatable — the same input yields the same verdict —
so it is the CI/merge gate. The agent engine is non-deterministic by nature:
re-runs can disagree at the margin. Use it for exploratory, reference-light, or
judgment checks, and prefer the deterministic Playwright engine for any blocking
gate.

## Dependencies

- `playwright` — resolves the current browser-automation API and drives the browser.
- `design-preview` — renders the project's own components for real-component checks.
