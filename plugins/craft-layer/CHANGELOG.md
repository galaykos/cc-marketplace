# Changelog

All notable changes to the craft-layer plugin.

Started at 0.47.0, the release that added the first assertions able to fail a
build that previously passed. Earlier versions have no entries rather than
invented ones — a backfilled history in the file whose job is history is worse
than an honest starting point.

## 0.54.0 — 2026-09-26

- Seven app-surface references in `information-design`: product-mock (the product on the front
  door), console-patterns, crm-screens, ai-surfaces, live-surfaces, spatial-surfaces,
  scheduling-surfaces; nine selector rows in `product-packages.md`; numbers and disclosures in
  `dense-ui-patterns.md`; two contradictions with overseer resolved.
- creative-direction: the interface-specimen hero allowed as a proof convention with its generic
  executions flagged; fictional-but-specific mock data allowed; four new hero categories and
  "Interface specimen" on the concept deck; `archetype-recipes.md`; vertical registers and a
  mono-face filter; a dated sameness-fingerprint refresh. design-research: proof and disclosure
  exceptions, read-only viewing of public references, and `scripts/technique-fingerprint.py`
  (detects a reference site's stack and motion techniques).
- Motion and 3D: R3F-on-WebGPU trap and the post pipeline split by renderer (`RenderPipeline` since
  r183); new `data-3d.md`, `webgl-first-site.md`, `video.md` (single owner) and `hosted-runtimes.md`
  (Spline / Unicorn Studio / Paper Shaders — a control-arm probe found the base model already defers
  the runtime and honours reduced motion 5/5, but ships no static poster 0/5; the arm carrying this
  reference reached 1/5, so the poster rule is admitted but not yet effective — see
  `rationale/2026-09-26-design-corpus-probes.md`); the 3D arrival contract (poster-first, scene-first
  as a recorded exception); SC 2.2.2 pause controls; Lenis, CSS scroll-driven, page-transition (Astro
  native vs `<ClientRouter />`, React 19.3 `<ViewTransition>`), split-text and vector fixes.
- `/craft-layer:audit`'s reduced-motion gate now sees JS (WAAPI, scroll-sampled transforms), canvas,
  Lenis and video motion, not only CSS; fixtures prove each channel. It still skips where no
  Playwright is available (CI), and `audit.md` names what it cannot see.
- Livewire: `wire:ignore`, bundled Alpine, `livewire:navigated`; the README no longer overstates it.
- Review fixes before release: the video pause-control match uses word boundaries (a "Google Play"
  badge no longer counts as a pause button); detached or instantly cancelled WAAPI animations are
  ignored; a `scale`-property progress bar is exempt; visible canvases are chosen before the cap of
  four; open shadow roots are walked for video; `technique-fingerprint.py` reads unquoted attributes,
  skips malformed asset URLs, ignores library names in visible text, enforces a per-fetch deadline,
  holds `--max-bytes` exactly, and treats a malformed URL argument as a usage error (exit 2).
  Residual: a one-axis `translate`-driven progress bar is still reported (it looks like parallax).

## 0.53.3 — 2026-09-25

### Changed
- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

## 0.53.2 — 2026-09-23

### Changed
- **Prompt audit (Claude Code's built-in `claude-api` skill, `prompt-audit` subcommand; target Opus 5.5 / Fable 5.1):** sixteen bodies and references drop past-tense incident stories and migration-relative phrasing; every rule and its reason stay. Method: that built-in skill's `shared/prompt-audit.md`; the full report and diff are in the maintainers' working area, not shipped.

## 0.53.1

### Added
- **`sameness-fingerprint.md` gains the pill-shaped-button row.** The Opus 5.5 playbook
  (claude.dev, 2026-09-22) names five defaults the model falls back on with no design
  direction; four were already in the category-default chrome list and this was the
  fifth. Agent-graded like the rest of that list — no `divergence.mjs` assertion reads it.

## 0.53.0

### Added
- **A `Voice:` line on the build task, and a `voice-contract` assertion that reads it.**
  Brand voice was a slot name: "editorial voice" was defined only as a typographic role, and
  the marketplace's one operational rule about copy craft lived inside a per-section brief
  the audit never opens. `skills/creative-direction/references/voice-contract.md` now owns the
  four dimensions — person and address, a sentence-length band in words, what the copy does
  with fragments/questions/imperatives, and 2–3 literal `NEVER "<string>"` items — and
  `/craft-layer:craft` step 5 writes them onto `craft/build-task.md` as a sixth line beside
  `Banned vocabulary:`. Standing is split on purpose: the LINE's presence and at least one
  NEVER are a **gate** (`divergence.mjs` FAILs a resolved build task without them, SKIPs when
  no build task exists at all), the NEVER literals in shipped copy are graded by
  `copy-register`, and the voice itself — person, band, fragment rules — stays
  **agent-graded**, because nothing here counts a sentence.

### Fixed
- **`hooks/ultra-craft.sh` starts `#!/bin/bash`, not `#!/usr/bin/env bash`.** The fail-open
  promise the boost hooks make in their own headers has to survive a stripped PATH, where
  `/usr/bin/env bash` exits 127 before the hook runs a line — a guard that cannot start
  looks to the host exactly like a guard that allowed. Rendered from
  `templates/boost-hook.sh.tmpl`, not edited here; `pc_hook_shebang` reads the claim back
  and is a build failure now that every shipped hook agrees with it.
- **The sameness-fingerprint "gate" read 1,683 of the registry's 13,951 characters.**
  `copy-register`'s lexicon was six phrases frozen into `divergence.mjs`, and the only live
  read of `sameness-fingerprint.md` was its `### Type families` section. A page reproducing
  nine registry entries verbatim — magnetic CTA, glass-card grid, logo marquee,
  tilt-on-hover, ALL-CAPS eyebrows, `01 / 02 / 03` — cleared every assertion the gate could
  grade. The registry now carries a `copy-lexicon` block read LIVE (source, kind and date
  printed every run, frozen snapshot as the fallback), and it arms the three rows the
  registry's own note already named as mechanical: the tracked-out ALL-CAPS eyebrow, the
  middle-dot meta string (`A · B · C`) and the trailing `→`. Re-run of that probe: three
  FAILs, exit 1. Rows carry a `min` so a repetition tell needs repetition — one honest
  `Read more →` and one footer middle dot stay clean, and `craft-gates.test.sh` ships the
  control pair that proves it.
- **Four gates were sold where one is scripted.** `README.md` named the offer-contract,
  ambition-tier, content-depth and sameness-fingerprint "gates" without saying which has a
  script behind it; eight `(teeth)` / `gate` headings sat over prose a reviewing agent reads.
  Every one now names its standing: `gate` for what `divergence.mjs` asserts,
  `agent-graded` for the rest — in the README, `content-depth.md`, `offer-contract.md`,
  `content-source.md`, `section-ledger.md`, `asset-sourcing/SKILL.md`, `type-strategy.md`,
  `creative-direction/SKILL.md` and `sameness-fingerprint.md` itself, whose "How divergence
  is measured (teeth)" heading contradicted its own text forty lines above.

## 0.52.0

### Added
- **`template/craft-gates/playwright.config.ts` — the gate suite can now actually be run.**
  `commands/audit.md` step 4 said run from the plugin, never a copy, and then gave a bare
  `npx playwright test`. Playwright has no `--spec` flag, so that command scanned the
  PROJECT's testDir, found no craft gate and exited 0 — a gate never run, reported green.
  The config pins the spec's own directory as the testDir and the project's
  `.craft-layer/` as the output dir, so nothing is written into the installed plugin.
  Measured against a throwaway page on 2026-09-22: bare → `Error: No tests found`;
  `--config` alone → MODULE_NOT_FOUND; `--config` plus `NODE_PATH=<project>/node_modules`
  → 21 tests, 12 screenshots in `<project>/.craft-layer/shots/`.
- **A Vocabulary table in the README.** spine, archetype, draw, move, genus, concept deck,
  register gate and section ledger carried load on every page of the docs and none was
  defined where a reader meets it; `genus` was defined nowhere at all, and now is, in
  `concept-deck.md` beside the `Banned genus:` key that is the only place a run must name one.

### Fixed
- **`gates.spec.ts` told you to copy the gates into your project; `commands/audit.md` told
  you never to.** The header now carries the run-from-the-plugin invocation, including the
  `NODE_PATH` without which the spec's own imports resolve from a directory that has no
  `node_modules`.
- **Corpus freshness was the file's mtime, so the gate overstated it.** `divergence.mjs`
  printed `2026-09-16` for a register corpus whose own text says `Last verified: 2026-07-26`
  — 52 days — and would print the clone date in a fresh checkout. It now reads the corpus's
  own `verified:` line, and a corpus carrying no stamp is reported `<date> (unstamped, mtime)`
  rather than handed a date it never claimed. The anti-corpus registry is currently in that
  second state and now says so.

### Changed
- **The twelve `fixture-*.html` control pages moved to `scripts/__tests__/fixtures/`.** 64K
  shipped to every installer, inside the directory audit.md says to run from and never to
  copy, read by nothing but the harness beside which they now sit.

## 0.51.1

### Fixed
- **The boost hook keyed the inline red-team fallback on a missing `Workflow` tool.** The Agent tool is a real dispatch path, so in an ordinary interactive session the panel should spawn; only with no dispatch mechanism at all does the run fall to one inline pass. `ultra-craft.sh` (rendered from `.chassis.json`) and the `ultra-craft` skill now state the rule `task-runner:verification-panels` owns.

## 0.51.0

### Fixed
- **The README told you the wrong default mode.** It said "Default is guided" while
  `offer-contract.md` Part 6, the `creative-direction` skill and `register-corpus.md` all say
  **`one-shot` is the default**. Every brief that named no mode was documented as buying guided
  rounds and a section ledger it never asked for. The README now states `one-shot`, how to enter
  `guided`, and that `one-shot` still carves out the concept fork.
- **`creative-director` could not run the fork the flow requires.** Its procedure said "Return
  the winner" and its Output listed one `Concept`, while `concept-deck.md` § The concept fork
  requires the dispatch to return **2–3 candidates** for a human pick at every tier, `one-shot`
  included — the only exchange a `one-shot` run has. The agent now returns a ranked FORK SET
  with a divergence record per candidate; it ranks, the user picks. `/craft-layer:craft` step 0
  says the same.
- **The sprite ceiling disagreed with the gate that grades it.** `sprite.md` permitted a ~500KB
  hero sheet; `tier-budgets.md` — the declared source of truth, and the row the audit injects
  into `craft-reviewer` — capped a sheet at 150KB. A 400KB hero built to the authoring guide
  failed the audit. `tier-budgets.md` now carries the pair (≤ 150KB eager, ≤ 500KB lazy, over
  500KB switch to looping WebM/AV1) and `sprite.md` cites it instead of restating it.
- **`creative-direction`'s SKILL body taught the retired flat divergence floor** ("each must
  break ≥1 default"). `sameness-fingerprint.md` retired it by name; a concept generated from the
  skill body alone under-reached at `standard` and `maximal`. It now states K = 1/2/3.
- **`/craft-layer:audit` under-counted what a missing token source costs.** It said three
  `divergence.mjs` assertions cannot resolve without `CRAFT_TOKEN_SOURCE`; measured, the script
  exits 2 at the token resolution and **five** never run (`accent-default-band`, `hue-repeat`,
  `font-anti-corpus`, `font-repeat`, `draw-repeat`) while the seven source-only ones still print.
  Its exit-code table also carried a blanket "exit 2 is `not measured`" that contradicted its own
  `contrast.mjs` paragraph twenty lines above — exit 2 from `contrast.mjs` is a FAILURE.
- **`asset-sourcing` routed video to a contract that does not exist** ("motion-tiers tier 4 owns
  encode / poster / fallback"). Tier 4 is sprite-sheets; the only video material in motion-tiers
  is `sprite.md`'s sheet-vs-video crossover. Stated honestly now.
- Stale cross-references corrected: `craft-reviewer`'s contrast exception pointed at "step 6"
  (contrast is step 4) and cited a "done-ness mandate (step 8)" that exists in none of the four
  skills it names; `register-corpus.md` cited `craft-reviewer` "(step 11)"; `gates.spec.ts` and
  `fixture-sight.html` said `commands/craft.md` step 7 owns opening the shots, which that step
  explicitly disowns — it is `commands/audit.md` step 5. The README named an audit final line
  (`Craft audit: <ran | NOT RUN> · …`) the command never prints, listed `expressive` as an
  ambition tier when the only three tokens are `restrained`/`standard`/`maximal`, and omitted
  `shots/` from `.craft-layer/`. `red-team-contract.md` said "two rules" and "Both are binding"
  over three rules. `offer-contract.md` Part 7 said "Two rows" over three.

### Changed
- **Routing vocabulary the descriptions were missing.** `motion-tiers` owns Tier 5 but never
  said **Lottie/Rive**, so "should I use Lottie here?" did not reach it; `physics-motion` covers
  **rapier** in its reference but never named it; `threejs-best-practices` spent description
  budget on an instruction ("Resolve the locked rXXX revision before advising" — already the
  first line of its body and its first anti-pattern) instead of the words users type: **R3F**,
  **drei**, **glTF/GLB**. Net description bytes went DOWN.
- `scroll-acts.md` no longer restates the six frame-sequence caps it says live in
  `tier-budgets.md`; the over-cap remedy stays, because it is a design instruction, not a number.
- `tier-budgets.md` dropped its "Nine files refer to these tiers" count (actual: 12 citing it,
  15 naming a tier) for a recount command, and un-spliced its `Last verified` blockquote, whose
  opening sentence had a second block wedged mid-clause.

## 0.50.2

### Changed
- **`/craft-layer:audit` is now declared in `lane.tsv`**, so the review-phase territory gate can see it alongside the other review-shaped commands.

## 0.50.1

### Fixed
- **The plugin description shipped a sentence fragment.** Removing `/craft-layer:review`
  in 0.50.0 left "…behind and Three.js review through /code-review:review" in the text
  the CLI renders in its install listing. It now reads "behind `/craft-layer:craft`;
  Three.js review arrives through `/code-review:review`".

## 0.50.0

### Removed
- **`/craft-layer:review` is retired.** `/code-review:review` already loads
  `threejs-best-practices` when a diff imports `three` or `@react-three/fiber` — the
  fan-in this command handed its whole scope to. One listing entry fewer; the rubric is
  unchanged and reaches more diffs than a command nobody typed.

### Changed
- **Every `/design-studio:preview` reference is now the real-component rung of `taskmaster:visual-decisions`** (README, <!-- removed-ok -->
  `/craft-layer:craft`, `:sections`, `:research`, `design-research`,
  `section-decisions`): the design-studio plugin was retired on 2026-09-14 and its <!-- removed-ok -->
  preview skill moved into ui-ux. The install section drops it from the optional
  pairings and names ui-ux once, correctly, for both the theme/build chain and the
  accessibility delegation — the row that said `a11y` named a plugin removed on
  2026-08-26. `asset-sourcing`'s component-sourcing reference now names shadcn's and
  ReUI's own MCP servers instead of the bundled one. <!-- removed-ok -->

## 0.49.6

- `agents/craft-reviewer.md`: the performance defer line repeated
  `/resilience:review --concern performance` twice (a rename artifact from 0.49.4).
  Wording only.

## 0.49.5

### Changed
- Preview hand-offs name the real-component rung of `taskmaster:visual-decisions` and the registry MCP is
  design-studio's — theme-design and design-lab were merged into that plugin <!-- removed-ok -->
  (2026-09-14 consolidation plan). Fallback order is unchanged: a running design
  session, then the real-component preview, then taskmaster's shell mockup.

## 0.49.4

### Changed
- The performance delegation in `/craft-layer:audit`, `craft-reviewer` and the
  asset-sourcing reference now names `/resilience:review --concern performance`:
  resilience collapsed its five review commands into one on 2026-09-14. Same rubric,
  same optional-delegation rule (skipped when resilience is not installed);
  `lane.tsv` yields to `resilience:review`.

## 0.49.3

### Changed
- `hooks/ultra-craft.sh` is now rendered from `templates/boost-hook.sh.tmpl` via a
  `boost-hook` object in `.chassis.json`; its lane row moved into the manifest's
  generated block. Output is byte-identical for every invocation the guard
  harness drives; the only behavioural-line changes are the per-plugin off switch
  reading `CRAFT_BOOST` through an indirect expansion and the directive going out
  via a quoted heredoc, so the manifest text is the wire text.

## 0.49.2

### Changed
- Citations of the four-laws / has-teeth doctrine now point at
  `.claude/skills/authoring-skills/SKILL.md` in the marketplace repository — the
  authoring plugin was demoted to a tracked project skill on 2026-09-03. Prose only;
  no behaviour change.

## 0.49.1

### Changed
- `lane.tsv` rows for this plugin's chassis-generated artifacts are now rendered by
  `scripts/generate.sh` from `lane` keys on its `.chassis.json` objects (a
  `# generated:start` … `# generated:end` block) instead of being typed by hand —
  same territory, trigger and yields_to; `generate.sh --check` fails if the two drift.
  No behaviour change for a user of the plugin.

## 0.49.0

### Changed
- `sameness-fingerprint.md` gains two category-default hues (warm cream + serif +
  terracotta; near-black + acid accent) and a **Category-default chrome** subsection —
  ALL-CAPS eyebrows, middle-dot meta strings, single-word headline accents, numbered
  markers on non-sequences, trailing `→`, the identical-card kit, the broadsheet
  layout, per-section fade-slide-up — ported from the official `frontend-design`
  skill's calibration list and de-duplicated against the existing vocabulary. The
  creative-director diverges from it and the craft-reviewer reads against it;
  standing agent-graded, no divergence assertion reads the new subsection yet.

## 0.48.4

### Changed
- Every staging hand-off (`/craft-layer:craft`, `/craft-layer:sections`,
  `section-decisions`, README) names `/design-lab:preview` alone; `/design-lab:stage` <!-- removed-ok -->
  was removed from design-lab 0.2.0. Greenfield decisions degrade to
  `taskmaster:visual-decisions` as they already did without design-lab.

## 0.48.3

### Changed
- Every preview and staging hand-off names design-lab; design-preview, shadcn-studio and <!-- removed-ok -->
  registry-source merged into it on 2026-09-02.

## 0.48.2

### Changed
- The optional performance delegation names `/resilience:performance-review`; the
  performance plugin merged into resilience on 2026-09-02. <!-- removed-ok -->

## 0.48.1

### Added
- **threejs merged in.** `threejs-best-practices` is a craft-layer skill and <!-- removed-ok -->
  `/craft-layer:review` (chassis stack-review) is its review command; every in-plugin
  path that pointed at the old plugin now points here. The skill body is unchanged.

## 0.47.12

### Changed
- Every accessibility hand-off now names `/ui-ux:audit`; the a11y plugin merged into <!-- removed-ok -->
  ui-ux on 2026-09-02. The craft gates and the contrast pre-check are unchanged.

## 0.47.11

### Changed
- `asset-sourcing`'s component-sourcing reference no longer names the removed
  `everything` bundle as an install path; `craft-suite` remains. <!-- removed-ok -->

## 0.47.10

### Changed
- **Meta-prose compressed to a one-line standing tag.** Sections narrating this
  skill's relationship to its siblings — boundary tours, "what this is NOT" lists,
  and in places the repository's own drift history — are replaced by a `Standing:`
  line on the rule they qualify. No actionable rule changed, and every named
  cross-skill reference was preserved: those names are what make the skills they
  point at reachable, and a re-scan confirmed none was orphaned.

## 0.47.9

### Changed
- **`ultra-craft` names the owning copy of the dispatch-tier rule.** The rule is
  restored inline (0.47.8) because craft-layer does not depend on orchestration and the
  hook that carries it exits on slash prompts; this adds the provenance line pointing at
  `orchestration:verification-panels` `references/dispatch-tier.md`, which is where the <!-- removed-ok -->
  marketplace states it once. The original citation named § Panel width, which owns
  panel width N and states none of it.

## 0.47.8

### Fixed
- **`ultra-craft` regains the `auto` model-resolution rule** — `haiku < sonnet <
  opus < fable`, escalate never downgrade, `effort` settable only on the Workflow
  `agent()` path. Deleted at `8899d48` ("would not fit twice under the 150-line
  ceiling") and replaced by a pointer to `orchestration:verification-panels` § <!-- removed-ok -->
  Panel width. **That pointer never resolved**: the named section owns panel width
  N and contains no mention of `haiku`, `auto` or downgrading. Meanwhile the body
  at `:43` orders "substitute `<model>` with the RESOLVED tier, never the word
  `auto`" — unexecutable from this file. The hook carries the rule but exits early
  on slash prompts, and orchestration is not a declared craft-layer dependency, so
  on the documented `/craft-layer:craft ultra` path the rule reached the model from
  nowhere at all.
- **`scroll-orchestration` regains the `## Reveal with fallback` heading**, orphaned
  at `3c8e6d7`; its paragraph had been sitting under `## Choose the engine` behind a
  stray double blank, making a shipping requirement read as a caveat about CSS
  scroll-driven animation.
- **`creative-direction` no longer hard-codes a line number.** The router rule said
  "within 150 lines" and had already been edited once to track the gate; it now
  names the constraint by kind, so it stops going stale every time the cap moves.

## 0.47.7

### Changed
- **Every hook entry now declares a `timeout`.** `ultra-craft.sh` 5s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.47.6

### Added
- **`/craft-layer:audit` re-runs its script gates after an "Apply now" pick** —
  divergence, contrast, and the gate suite re-check the changed scope before the
  run reports done; a fix that cannot be gate-checked is named unverified. On
  unboosted runs fixes were previously taken on the fixer's word.

### Fixed
- **Removal fallout (i18n, react):** `rtl-bidi.md` now states its four-rule
  floor as the only shipped base rules rather than deferring to the removed <!-- removed-ok -->
  i18n plugin; the README reuse-map row points at that reference; <!-- removed-ok -->
  `product-packages.md` routes data-grid wiring to the chosen library's docs
  instead of the removed `react-data-grid` skill; a bolded react-verb line in <!-- removed-ok -->
  `vector.md` was reworded so the removed-artifact guard can hold the
  line without a marker.

## 0.47.5

### Fixed
- `motion-tiers/SKILL.md` shipped "Standing **recorded** — the mirror is manual and
  no gate checks the two agree" after this same branch added the gate that checks
  it. `pc_source_of_truth` fails CI when a KB figure in the SKILL is absent from
  `references/tier-budgets.md`. The marker now says what is true: KB figures are
  **gate**, prose agreement is **recorded** — nothing reads meaning. A skill telling
  a model the wrong enforcement tier about itself is the has-teeth defect this
  marketplace publishes a convention against.

## 0.47.4

### Changed
- WCAG SC 2.5.7 was stated in full three times — `physics-motion`,
  `interaction-fx`, and `a11y:a11y-audit`, which owns it. The two craft-layer <!-- removed-ok -->
  satellites now state the rule in one line and name the owner. Deliberately
  still STATE it rather than only pointing: craft-layer installs standalone, so a
  bare pointer would leave a legal accessibility criterion unreachable.
- `motion-tiers/references/reduced-motion.md` was titled "The reduced-motion gate
  — stated once". That was false: `ui-ux:motion-best-practices` also states it and
  owns the WHY, the CSS kill-switch and the subscription mechanism —
  `motion-tiers/SKILL.md` assigns that mechanism to it by name. Retitled and
  scoped to craft-layer. A file whose job is preventing restatement, claiming a
  uniqueness it did not have, was the sharpest form of its own problem.

## 0.47.3

### Fixed
- `motion-tiers/SKILL.md` told a React reader the Tier-1 reduced-bundle path is
  `animate()` from `motion/mini`. Its own declared SOURCE OF TRUTH,
  `references/tier-budgets.md`, reserves `motion/mini` for **vanilla** element
  tweens and names `LazyMotion` + `m.*` as the React path. Two files, opposite
  advice, one of them labelled the truth. The SKILL now matches the reference.
- `motion-tiers/references/rtl-bidi.md` pointed at `plugins/i18n` for the general <!-- removed-ok -->
  RTL rules and said "do not re-teach them here" — but `craft-suite` does not ship
  i18n, so a craft-suite reader got a pointer to nothing. The file now carries a
  four-rule floor (logical properties, `dir`, which icons mirror, LTR runs inside
  RTL) and defers to i18n when it IS installed.

### Note
- The manual SKILL↔reference mirror that produced the first defect is no longer
  unchecked: `pc_source_of_truth` in `scripts/lib/plugin-checks.sh` now fails any
  SKILL naming a reference as SOURCE OF TRUTH that carries a figure the reference
  lacks. Its honest limit: figures only — prose contradiction, which is what this
  defect actually was, stays agent-graded.

## 0.47.2

### Fixed
- **Eleven severed sentences, shipping since 2026-07-27.** Commit `3c8e6d7`
  ("prose strip — net -76 lines, no capability removed") deleted hard-wrapped
  CONTINUATION lines, which ends a sentence mid-clause. Nine of this plugin's
  files carried the damage on every load since: `scroll-orchestration` lost
  "engine drives it — then pins the contract and the budget", the clause naming
  what the skill decides; `webgl-effects` read "earns the GPU cost and" straight
  into "Three.js:"; `information-design` ended mid-sentence at "Cite the". Each
  sentence is repaired in the strip's own spirit — the author-facing "never
  restate" nagging stays deleted, the reader-facing scope claim is back. The
  commit message's "no capability removed" was false, and no gate here could
  tell a redundant line from the second half of a sentence.
- **`contrast.mjs` was invoked by nothing.** 183 lines and three test fixtures,
  with zero runnable call sites, while `template/craft-gates/gates.spec.ts`
  disables axe's `color-contrast` rule and names this script "the gate of record"
  in its place. Contrast was graded by nothing on every path. `/craft-layer:audit`
  step 4 now runs it beside `divergence.mjs`, and says why exit 2 is a failure
  rather than a skip.
- **Corrected the recorded call sites of `divergence.mjs`.** Three documents said
  it is invoked by "`/craft-layer:craft` step 7 and `/craft-layer:audit` step 4",
  which reads as two independent call sites. There is one: craft step 7 calls the
  audit COMMAND, and explicitly forbids running its gates itself.

## 0.47.1

### Fixed
- **`utility-palette` passed the exact default swatch written as an arbitrary hex
  class.** `bg-[#6366f1]` scored 238.7° in sRGB against a band calibrated in oklch
  (275–315°, where that same swatch is 277.1°), so the assertion returned PASS —
  while its PASS message affirmatively claimed "no in-band arbitrary hex". A gate
  making a false negative claim, and an inverted tier: it missed what the ui-ux
  **advisory** catches by literal list. Found by an adversarial audit on 2026-08-18.
  A `DEFAULT_SWATCHES` set now catches those nine values by name; the PASS message
  no longer asserts more than it checked; and the in-file limitation that claimed
  "the named-utility path catches an indigo hex literal's swatch" is corrected —
  names are not hexes. Any *other* in-band hex is still seen only where the two
  colour spaces agree, and that residual is now stated accurately.

## 0.47.0

### Added
- **`utility-palette` and `utility-font` assertions** in
  `template/craft-gates/divergence.mjs`. **Standing: gate** — both fail the run
  (exit 1) and both are waivable via `.craft-layer/waivers.json` with a reason,
  the same lane every other assertion here rides.

  **This can turn a build red that was green before**, and that is the point.
  `accent-default-band` decides the category-default hue from CSS custom
  properties only, and `font-anti-corpus` reads the token stylesheet plus its
  siblings. On a Tailwind/JSX build neither the palette nor the type passes
  through either input: the hue arrives as `from-indigo-500 via-purple-500
  to-violet-600` inside a `className`, and the family as
  `import { Inter } from 'next/font/google'`. A violet gradient hero set in Inter,
  over a `src/index.css` whose cleanly derived accent token no element ever
  referenced, cleared both — and the run printed "OK: the build clears the N
  divergence assertion(s) that could be graded".

  `utility-palette` reads named Tailwind colour utilities and arbitrary
  `[#rrggbb]` values out of the class strings `CLASS_RE` already extracts;
  `utility-font` reads `font-[...]`, `next/font/google` specifiers and
  `fonts.googleapis.com` family links against the anti-corpus text
  `loadAntiCorpus()` already returns.

  **If this newly fails your build**, the two honest options are to choose a hue
  and a typeface, or to record in `.craft-layer/waivers.json` why the default is
  the right answer here — a brand that genuinely is violet has been made to
  notice, which is the whole claim.

  The `indigo|violet|purple` family list is **derived from `DEFAULT_BAND`**, not
  chosen by taste: those three sit at ~277.1°/292.7°/303.9° oklch, inside the
  275–315° band, while blue-500 (~259.8°) and fuchsia-500 (~322.1°) fall outside.
  If the band ever moves, re-derive the list from the ramp rather than extending
  it by feel.

### Known limitation (unchanged behaviour, newly measured and stated)
- `toHue()` returns a hue in whichever space the value was written in, and oklch,
  hsl and hex are then all compared against one band. Tailwind's own
  indigo/violet/purple **hexes** read 238.7°/258.3°/270.7° in sRGB — below the
  275° floor — while the same swatches are 277.1°/292.7°/303.9° in oklch. So a
  token written `--accent: #6366f1` escapes `accent-default-band`, and the hex
  path of `utility-palette` fires only where the two readings agree
  (fuchsia/magenta-side values such as `#d946ef` at 292.2°). The named-utility
  path is what catches an indigo swatch in practice. Re-spacing the band or
  converting hex to oklch would change `accent-default-band`'s verdicts for every
  existing build, so this is recorded with its measurement instead of changed
  quietly.
- Neither assertion **ever runs on `/ui-ux:build`**. `divergence.mjs` is invoked
  by `/craft-layer:audit` step 4 and `/craft-layer:craft` step 7 and nowhere else,
  while ui-ux's own `build.md:75` calls itself the most reachable UI entry point
  in this marketplace. Closing this gap closes it on the craft path only.
- They count a hue and a family, not a composition: three equal cards, the ribbon
  on the middle one, and the centred hero stay uncounted.
