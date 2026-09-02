# Consolidation: 52 leaf plugins to 36 — 2026-09-02

**Standing: `recorded`.** Nothing reads this file back. It records why the first
consolidation merge took the shape it did, so the next merge can copy the shape
instead of re-deriving it.

## The rule this merge applies

A plugin is an **install unit**. It earns existence only if someone installs it alone.
`nextjs`, `react-native` and `vite` were each one skill and one generated review
command, shipped only inside `frontend-suite` (and `vite` inside `php-suite`), and the
agents that actually loaded their skills lived in `web-dev`. That is packaging, not
capability: three `plugin.json`s, three READMEs, three uninstall paths, three
version-bump churns, and three catalog rows for one job.

What the merge does NOT change: the skill names, their bodies, their router rows'
signals, the fan-in in `/code-review:review`. Listing cost is per skill and command
entry, not per plugin, so the always-on surface moves by the description deltas only —
measured below, not assumed.

## The four decisions

1. **One `/web-dev:review`, hand-written, chassis opt-out.** The `stack-review` chassis
   is single-skill by design. `ui-ux` already carries the multi-stack shape as an
   `optout`; web-dev copies it. The six steps mirror the template blocks verbatim so the
   fan-in output format is unchanged; step 3 is the detection table, exact-key only
   (`next-auth` is not `next`), plus the Expo divergence preamble that used to be
   react-native's chassis `divergence`.

2. **`frontend-reviewer` pins `model: opus` as a FLOOR.** The user's stated operating
   range is Opus and Fable at high/xhigh, with Sonnet sometimes. A reviewer at `inherit`
   in a Sonnet session judged with a Sonnet-class verdict. Role floors
   (`orchestration:delegation-contracts` `references/role-floors.md`) are this
   marketplace's mechanism for exactly that: dispatch at `max(session, opus)`, so Opus
   and Fable sessions see no change and a Sonnet session gets an Opus-class judge. The
   worker stays `inherit` — implementation tracks the session; judgment does not drop
   below it. Cost: a Sonnet user pays Opus for the review verdict only.

3. **Skills carry model-tier markers.** Per `claude-authoring`
   `references/model-tier-scoping.md`: the facts (version gates, footguns, boundaries)
   are **All models**; the detect → pin → verify order is **Compensation
   (worker-tier)**, followed literally by a Sonnet-class session and compressible by a
   Fable-class one; and each skill names its **Skip** condition so a trivial diff gets a
   one-line verdict instead of a rubric walk. Standing: recorded — no script reads the
   markers.

4. **The removed-reference guard learns the moved names in plugin forms only.**
   `/vite:review`, `plugins/vite`, `**vite**`, "vite plugin" are stale; `vite` and
   `react-native` as bare package names are not, and the surviving skills must keep
   saying them. A second boundary (`bm`) excludes `@inertiajs/vite plugin`, which is a
   package.

## What the three prompting guides contributed

Read 2026-09-02: Fable 5.1, Opus 5, Sonnet 5 pages under
`platform.claude.com/docs/en/build-with-claude/prompt-engineering/`. Applied here:

| Guide | Finding | Where it landed |
|---|---|---|
| Sonnet 5 · Code review harnesses | "only report high-severity" is followed literally; recall drops while precision rises. Ask for coverage, filter in a separate step. | `/web-dev:review` step 4 (report everything, tag confidence) with step 5's self-refute as the filter; `frontend-reviewer` "Report every issue you find" |
| Sonnet 5 · More literal instruction following | It does not generalize an instruction from one item to the next; state the scope. | step 3 "every loaded skill across every file in scope, not only the first match"; reviewer rubric same sentence |
| Sonnet 5 · Effort | `low`/`medium` scope to what was asked; under-thinking risk on complex work at `low`. Cross-model: Sonnet 5 `medium` ≈ Sonnet 4.6 `high`. | reviewer keeps `effort: xhigh`; the floor decision above |
| Opus 5 · Code review | Same literalism on "be conservative"; accuracy holds at lower effort, so a fast pass then a thorough pass is viable. | same step-4 wording; noted here for the fan-in template (not changed in this PR) |
| Opus 5 · Task scope and over-verification | Remove "verify your work" instructions; they compound with the model's own verification. | The chassis self-refute pass is KEPT, because with coverage-first reporting it is the filter stage, not a re-check. Recorded as the reason, so nobody strips it as over-verification |
| Opus 5 · Controlling subagent spawning | Delegates readily; cap it. | no change — `task-runner:parallel-planning` already gives the inline-vs-delegate verdict |
| Fable 5.1 · Effort | Effort names are not comparable across models; `low` searches less. | reviewer stays `xhigh`; the model-tier blocks say which prose binds per tier rather than pinning effort per tier |

Not applied, deliberately: Opus 5's verbosity and narration blocks (the host CLI ships
its own), Sonnet 5's design-defaults prompt (belongs to `ui-ux`/`craft-layer`, not
here), and the Fable 5.1 harness-design rules (belong to `llm-app`).

## What moved where

| Was | Now |
|---|---|
| `plugins/nextjs/skills/nextjs-best-practices/` | `plugins/web-dev/skills/nextjs-best-practices/` |
| `plugins/nextjs/evals/caching-inversion/` | `plugins/web-dev/evals/caching-inversion/` |
| `plugins/react-native/skills/react-native-best-practices/` | `plugins/web-dev/skills/react-native-best-practices/` |
| `plugins/vite/skills/vite-best-practices/` | `plugins/web-dev/skills/vite-best-practices/` |
| `/nextjs:review`, `/react-native:review`, `/vite:review` | `/web-dev:review` |
| react-native chassis `divergence.preamble` (Expo) | `/web-dev:review` step 3 |
| `skill-router/rules.tsv` owning_plugin on 6 rows | `web-dev` |

## What this merge did NOT verify

- No control/treatment run. The three skills were not re-measured; they moved. The
  measured-zero shapes (`rationale/measured-zero-shapes.md`) were checked against
  their bodies when they were written, not now.
- The floor's effect on Sonnet review quality is the doctrine's claim, not a
  measurement on this repo. `scripts/turn-cost.sh --skills` can show whether the
  skills fire; it cannot show whether the Opus verdict was better.
- The next merges in the queue (database ← sql + mariadb, devops ← dev-env,
  ui-ux ← a11y, …) should copy the shape here and not the wording.


## The full run, same day

The web-dev merge above was the shape; the rest of the queue was run the same way,
one commit per merge, four gates green after each, the full smoke set at the
checkpoints. Result: **36 leaf plugins (from 52), 8 bundles (from 10)**.

| Keeper | Absorbed | Commands now |
|---|---|---|
| `web-dev` | nextjs, react-native, vite | `/web-dev:review` |
| `laravel` | inertia | `/laravel:review` (loads Inertia when the manifests show it) |
| `database` | sql, mariadb (+ `db-suite` removed) | `/database:review` (dialect skill only on MariaDB) |
| `devops` | dev-env | `/devops:review`, `/devops:init` |
| `stack-scan` | packages | `/stack-scan:report`, `/stack-scan:audit` |
| `ui-ux` | a11y | `/ui-ux:audit` + `a11y-engineer` |
| `craft-layer` | threejs | `/craft-layer:review` (chassis stack-review) |
| `api-design` | api-docs-first | `/api-design:check`, `/api-design:drift` + the reminder hook |
| `resilience` | observability, performance | five audits, two workers; routing tags resolve here |
| `code-review` | comment-discipline | `/code-review:comment-review` + three write-time hooks |
| `design-lab` (new) | design-preview, shadcn-studio, registry-source (+ `product-suite` removed) | `/design-lab:preview`, `/design-lab:stage`, two MCP servers |

Every absorbed skill kept its name, so `skill-router` rows, `coding-entry`'s skill map,
and the card `Skills to apply` vocabulary changed only in the owning-plugin column.
The removed-reference guard (`pc_removed_refs`) learned every moved name in its
plugin forms only, with a boundary that keeps package names (`vite`,
`react-native`, `@inertiajs/vite plugin`) legal.

### Bundle cost, measured

Merging does not change listing cost when both plugins were already in a bundle
(entries are per skill and command). It does when a keeper sits in a bundle the
absorbed plugin did not: `stack-scan` carried `package-hygiene` into
`process-suite` and `taskmaster-suite` (+124 always-on tokens each), `api-design`
carried the docs-first check into `process-suite` (+178), and `ui-ux` carried the
WCAG audit into `taskmaster-suite` (+153). Each was accepted and hand-applied to the
baselines with the arithmetic cross-checked against the absorbed plugin's old number.

### Not merged, and the measured or recorded reason

| Proposed | Reason it stays |
|---|---|
| `plugin-scout` ← vercel-skills-scout | Measured, then reverted: plugin-scout ships in `always-on-suite`, and the merge pushed that bundle over the 6,000-char floor listing budget (6,388) and +147 always-on tokens. The baseline bundle is the one that must stay under the floor. |
| `terse` ← candor + lean | `quality-suite` carries candor and lean but not terse; any host puts terse's 848-token surface (plus its SessionStart and UserPromptSubmit hooks) into the enforcement bundle that deliberately does not carry it. Also rejected once before (`rationale/distillation-2026-08-23.md`). |
| new `guards` ← secret-scanning + command-guard | `always-on-suite`'s README records rule 3, "adds no interruption you did not ask for", as the rule that removed command-guard from the baseline: its `ask` tier converts a silent host judgement into a permission click on every prompt. A merged plugin would put that tier back. |
| `brain` ← hindsight | hindsight is in `always-on-suite`; brain is not, and its SessionStart primer would join the baseline at the listing floor. Same floor argument as vercel-skills-scout. |
| `debugging` ← fresh-take | fresh-take's README: "standalone by design — its reminder hook and stronger-model consultant are deliberate opt-ins a bundle would install silently." debugging ships in `quality-principles-suite`. |
| `orchestration` ← ultra-deep-research | Same recorded standalone reason, and craft-layer's `moves-taxonomy.md` depends on it NEVER being a declared dependency (a declared dependency would make craft-layer a bundle). |
| `code-architecture` ← approaches | code-architecture is in `quality-suite` (enforcing), approaches in `quality-principles-suite` (advisory); the merge crosses the split those two bundles exist for. |

The pattern in the table: a merge is safe when the two plugins already travel
together; it is a bundle-composition change when they do not, and this marketplace
has recorded reasons for most of those compositions. Fewer plugins is the goal;
silently widening the user-scope baseline is not the price.

### Also in this run

Five rules adopted from a review of `mattpocock/skills` (commit `98d09c6`): tagged
debug probes with a grep-away cleanup step and credentials kept out of the
transcript (`debugging`), the frontier rule for question rounds (`grill`), the
tautology tell and named seams (`tdd`), and conflict resolution from each side's
intent with no `--abort` (`git-workflow`). All recorded, none measured; the
reviewer's full inventory, overlap table and the seven contradictions with local
doctrine are not reproduced here.
