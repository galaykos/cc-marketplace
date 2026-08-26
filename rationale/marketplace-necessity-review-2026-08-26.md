# Is this marketplace necessary? — 2026-08-26

An outside-in review answering two questions the prior `rationale/` documents
circle but never put plainly:

1. Does this marketplace need to exist, given what the host and the ecosystem now ship?
2. Which plugins inside it earn their place?

Method: external research (ecosystem, host budget semantics, adoption), plus
fresh measurement in this working tree. Where a prior in-repo document already
measured something, this review **cites and defers** rather than re-deriving —
`measured-zero-shapes.md`, `stack-skill-baselines.md`,
`eval-ablation-2026-08-20.md` and `distillation-strategy-2026-08-20.md` are the
strongest evidence here and none of it is superseded.

---

## 1. The verdict, in one paragraph

**As a public marketplace: no, it is not necessary, and it has no distribution.**
1 star, 0 forks, 0 watchers, absent from every community plugin directory
indexed today, against an official marketplace past 200 plugins and 9,000+
third-party entries. **As a personal toolchain: the mechanism half is worth
keeping and the prose half is not** — but the cut everyone reaches for is the
wrong one. The 29 prose-only leaves that the repo's own ablations measured at
zero cost only **6,425 of 19,667 always-on tokens (33%)**. The 32 mechanism
leaves cost **13,242 (67%)**, and seven of them cost 40% of the entire
catalogue. Value and cost are misaligned in *opposite* directions: what has been
measured to not work is cheap, and what plausibly works is expensive and
unmeasured. The single highest-leverage change is not a deletion — it is
**retiring the `everything` bundle**, which no one should install and which is
the only artifact that forces the whole 19,667 onto one session.

---

## 2. The host budget makes the catalogue self-defeating at its current size

Independently confirmed this session, not taken from the prior docs:

- Claude Code allocates a **1% of context window** budget for the skill listing,
  configurable in `settings.json`.
- On overflow it **drops descriptions starting with the least-invoked skills** —
  names survive, trigger keywords do not.
- One source documents the default as **~15,000 chars ≈ 4,000 tokens**.
  Anthropic carries an open truncation bug, `anthropics/claude-code#56710`.
- `/doctor` reports the listing's cost and its biggest contributors.

Measured against that: `everything` = **19,667 always-on tokens** across 61
leaves (`scripts/context-budget-official.json`, 2026-08-20). That is **5–10x the
budget** depending on which figure applies.

**The consequence has not been stated anywhere in `rationale/` and it is the
core finding of this review:** at this size the catalogue is *already* being
silently evicted, least-invoked first. On a fresh install nothing has been
invoked, so eviction order is close to arbitrary. Every argument in this
repository about a skill's trigger vocabulary — every `rules.tsv` row, every
carefully-worded `description:` — assumes the description is *in context*. For
the tail of a 61-leaf install, it is not. The repo has been optimising the
wording of text the host is throwing away.

This also reframes `distillation-strategy` §W3. Its measured win was
**−269 tokens** from four merges. Against a 17,667-token overshoot, that is
1.5% of the gap. Artifact-level merging cannot close this; only **not installing
most of the catalogue** can, which the bundles already permit and `everything`
exists to defeat.

---

## 3. What the ecosystem now covers, and what that does to the catalogue

### 3a. Host built-ins that now overlap shipped plugins

Claude Code ships these as first-party skills today (the repo's own
`pc_host_overlap` guard already names five; this is the operative list):
`code-review` (including a multi-agent cloud review), `security-review`,
`simplify`, `skill-creator`, `plugin-structure`, `artifact-design`, `dataviz`,
`claude-api`, `claude-in-chrome`, `init`, `run`, `loop`, `schedule`.

| Plugin | Cost | Host artifact that overlaps | Reading |
| --- | --- | --- | --- |
| `code-review` (344) | 344 | `/code-review` + `ultra` cloud review | Host is **stronger**. What survives is the `conventions.sh` hook emitting project config paths — installation-specific, the not-zero shape. Keep the hook, retire the prose. |
| `security` (448) | 448 | `/security-review` | Overlaps on the review command. The PreToolUse `write-scan.sh` (correctly using `additionalContext`) does not overlap. |
| `claude-authoring` (801) | 801 | `skill-creator`, `plugin-structure` | **Largest prose-only plugin in the catalogue.** Its doctrine is genuinely better than the host's, but it is authoring guidance for *this repo's* conventions — a `.claude/skills/` project skill, not a shipped plugin. |
| `lean` (102) | 102 | `/simplify` | Near-duplicate intent. |
| `brain` (138) | 138 | `/init` + the host's file-based memory | Memory is now a host feature. |
| `ultra-deep-research` (358) | 358 | native WebSearch/WebFetch + Agent fan-out | The harness is thin over capability the host has. |
| `design-preview` (170) | 170 | `claude-in-chrome`, `/run` | Largely subsumed. |

### 3b. Mature ecosystem plugins that overlap the biggest investments

| This repo | Cost | Ecosystem equivalent | Installs |
| --- | --- | --- | --- |
| `taskmaster` + `task-runner` + `approaches` + `code-architecture` | **3,910** | **Superpowers** — clarify → design → plan → code → verify, 14 skills, TDD, two-stage review | ~752,000 |
| `api-docs-first`, `registry-source` | 240 | **Context7** — live version-pinned docs via MCP | ~349,000 |
| `brain`, `hindsight` | 387 | **Claude Mem** | — |
| `terse` (1,233) | 1,233 | **Caveman** (token-saving terse mode) | — |
| `ui-ux` + `craft-layer` (2,713) | **2,713** | **frontend-design** (Anthropic, first-party) | ~300,000 |

Four of the five most expensive plugins here have a widely-adopted equivalent.
That is not proof they are worse — `craft-layer`'s ordered motion-tier decision
procedures are a real shape frontend-design does not carry, and §8d killed the
merge on evidence. It *is* proof that the marketplace is not filling a gap the
ecosystem left open, which was the premise of building 71 of them.

---

## 4. Which plugins earn their place

Classified by the repo's own measured criterion, which is the right one and
should not be relitigated: **mechanism / ordered decision procedure /
installation-specific knowledge / inverted advice** have never measured zero;
**idiom maps / doctrine checklists / style catalogues / framework restatement**
measured zero repeatedly, once *negative*.

### Tier 1 — Keep. A mechanism, and nothing else does it (≈1,300 tok)

`secret-scanning` (137) · `command-guard` (200) · `database` (183, destructive-SQL
PreToolUse guard) · `skill-router` (0 metered — and §host-lever-probes proved
`paths:` **cannot** replace it: no listing saving for plugin skills, and it loses
`stack_marker` suppression and rank arbitration) · `stack-scan` (134) ·
`plugin-scout` (194) · `candor` (158) · `registry-source` (0, live MCP).

These are the cleanest artifacts in the repository. A PreToolUse deny that
returns `permissionDecision` JSON is not something a model can be argued into
doing reliably, which is exactly why it works.

### Tier 2 — Keep, but the case is unmeasured and expensive (≈7,900 tok)

`craft-layer` (1,655) · `taskmaster` (1,464) · `terse` (1,233) · `ui-ux` (1,058) ·
`approaches` (937) · `code-architecture` (888) · `task-runner` (621).

**40% of the catalogue's always-on cost sits in these seven.** Each carries
ordered decision procedures — the not-zero shape — and §8d specifically killed
the craft-layer merge on evidence. But *none of them has been ablated*, and the
one cluster that was ablated (stacks) collapsed. `eval-ablation-2026-08-20.md`
§1 records that `claude plugin eval --ablation with-without` is gated at the
account level; when it opens, **these seven are where the runs belong**, not the
stack plugins whose answer is already known.

Two live defects here from §8a/§8d, still shipping: `orchestration/ultra-assess`
claims to quote its hook "verbatim" and diverges after 90 chars; **11 prose
corruption sites in 9 craft-layer files** from commit `3c8e6d7`, one of which
(`information-design/SKILL.md`) ends mid-sentence.

### Tier 3 — Cut. The evidence is already in-repo and was never acted on

The 29 prose-only leaves, **6,425 tokens**. `stack-skill-baselines.md:39-44`
kept every stack plugin on the theory that they encode "version leverage maps
**and lockfile-pinning behavior**". Both halves have since been measured:

- Version/idiom maps → **0 delta, twice**, with the blind control finding defects
  the treatment missed (`measured-zero-shapes.md`).
- Lockfile-reading, the surviving defence → **0 delta**, round 2 of the
  2026-08-20 ablation. Every control run opened `composer.json` unprompted and
  found both `^8.1` and the stricter `config.platform` pin.

`distillation-strategy` §8c states the conclusion outright — *"the half that
saved them is the half that scored zero"* — and then does not cut them. That is
the largest open gap in the repository: **an unexecuted conclusion.**

Cut first, on measured evidence: **`php`** (137 — directly ablated to zero,
including its own defence; 100 of 141 body lines are language idiom) ·
`sql` (142) · `postgresql` (192) · `vue3` (107) · `nuxt` (173) ·
`node-backend` (168) · `threejs` (142) · `livewire` (105) · `mysql` (167) ·
`packages` (191) · `i18n` (146) · `react` (286).

Keep from this tier, on the narrow-survivor rule — **inverted advice**, where the
answer a model confidently gives is now *wrong*, not merely incomplete:
**`nextjs`** (130; §8c hand-classified it at 69% version-pinned, and its rules
are inversions — "since 15, `fetch` defaults to `no-store`"), **`react-native`**
(90; the Expo SDK 55 `newArchEnabled: false` silent no-op is named in
`measured-zero-shapes.md` as *the* narrow survivor), **`mariadb`** (165; §6
killed the mysql merge because mariadb is *inverted* advice against the MySQL
answer — but this argues for keeping mariadb, not both).

*Measurement note:* a line-level regex for version tokens run this session
ranks these far lower (nextjs 5%, php 10%) than §8c's rule-level hand
classification (nextjs 69%, php 27%). The regex is the weaker instrument — it
counts lines containing a version string, not rules that are version-pinned — so
§8c stands. The one signal that survived my proxy is **inversion density**, and
it independently picks out the same three survivors: nextjs (6), vite (3),
react-native (2).

### Tier 4 — Retire `everything`; keep the other nine bundles

§8e measured a bundle's own marginal cost at **−10 to 0 tokens** and showed that
merging `quality-principles-suite` into its container would cost a target user
**+5,396 tokens**. That analysis is correct and the nine curated bundles should
stay.

It does not extend to `everything`. `everything` is the only artifact that puts
all 19,667 tokens in one listing — 5–10x the host budget, guaranteeing silent
eviction of the tail. It is a demo of catalogue size, not an install anyone
should perform. Retiring it costs no user anything (every member remains
installable) and removes the repository's single worst-configured entry point.

---

## 5. Two instrument problems that outlive any cut

1. **`scripts/context-budget.sh` under-reads by 1.54x** and separately meters the
   **OFF state** of state-gated hooks (§2, §8a): `terse/hooks/activate.sh` emits
   ~1,043 tokens with a level set and 0 in the sandbox. The `--reconcile` mode
   that would catch this is **local and WARN-only, not a CI step**, because
   `claude plugin details` resolves by installed name and a fresh checkout
   cannot run it. The gate is blind to its own subject in exactly the
   configuration a user runs.
2. **No usage evidence exists.** `retirement-queue.sh` reads two ledgers,
   `~/.claude/skill-router/` and `~/.claude/hindsight/`, and **neither directory
   exists on this machine**. This environment is fresh (2 projects, 3
   transcripts, all dated today), so that is *not* evidence of disuse — but it
   means the only mechanism designed to tell which of 127 skills ever helped
   anyone has never produced a data point, and 91 of 129 skills have no
   `rules.tsv` row to be surfaced by in the first place.

---

## 6. Recommendation

**Do not delete 71 plugins.** Do this instead, in order:

1. **Retire `everything`.** Highest leverage, zero user cost, removes the only
   configuration that is definitionally over budget.
2. **Cut the 12 named Tier-3 stack leaves** (−~2,000 tok). The ablation evidence
   has been sitting unexecuted since 2026-08-20.
3. **Demote `claude-authoring` to a project skill** (−801 tok, the largest
   prose-only artifact) and **thin `code-review`/`security` to their hooks**,
   now that the host ships both reviews.
4. **Spend the eval budget on Tier 2, not Tier 3.** The seven expensive workflow
   plugins are 40% of the cost and 0% of the measurement.
5. **Fix the 11 craft-layer corruption sites** before any further prose
   distillation — a prose-stripping pass already severed sentences once and the
   commit message said "no capability removed".

On the framing question: **stop maintaining this as a public marketplace.** The
28-step CI, four blocking scripts, 21 smoke harnesses and 34 plugin test suites
— 412 KB of enforcement machinery against 2.35 MB of shipped prose — are the
ceremony of a product with users. There is one user. `Proportionality` is the
first of this repo's own four laws, and the marketplace is currently its largest
counter-example.

---

## Standing

**Recorded.** No script reads this file. Its Tier-3 list is actionable against
`scripts/remove-plugin.sh`; its Tier-2 claim is a proposal for `claude plugin
eval` and is explicitly **not** a measurement. Nothing in `plugins/` was changed
by this review.

---

## Addendum — same-day re-scan on Fable 5

The scan above ran on Opus 5. This addendum is the same review re-run on
Fable 5 in the same session, with the honest caveat that it is a
**re-examination, not a blind replication** — this pass carries the first
pass's context. What it adds is one piece of live evidence the first pass
could only cite from web sources, and three corrections found by
hand-verifying claims the first pass took on trust.

### A. The eviction is no longer a prediction — it happened in this session

Between the two passes the maintainer's own dogfood set was reloaded into the
live session: 38 plugins, 144 skills, 43 hooks. The resulting skill listing
arrived with **~31 marketplace skills name-only — descriptions stripped by the
host** — plus two of the host's own built-ins (`init`, `security-review`).
All ten spot-checked victims carry a `description:` in their SKILL.md; the
host dropped them. §2's claim is now observed, not sourced.

Three details sharpen it:

1. **A 1M-context session did not save the listing.** Descriptions alone
   across the 86 loaded skills total ~19,949 chars, and the tail was stripped
   anyway — consistent with the ~15k-char absolute default binding before the
   1% fraction does. Buying a bigger window does not buy back the catalogue.
2. **The stripped set includes Tier-1 and Tier-2 trigger vocabulary:**
   `secret-scanning`, `approach-deliberation`, `lean:cost-model`,
   `candor:straight-talk`, every `resilience`/`system-design`/`observability`
   body skill. On a fresh machine "least-invoked first" collapses to listing
   order, exactly as §2 predicted.
3. **Hooks are eviction-proof; descriptions are not.** All 43 hooks loaded
   regardless. The mechanism/prose split in §4 is therefore not just a value
   argument but a *survival* argument: a plugin whose worth is a PreToolUse
   deny loses nothing to the budget; a plugin whose worth is trigger wording
   loses precisely that, silently. `secret-scanning` demonstrated both halves
   at once — its skill description was evicted, its hook was not.

### B. Corrections to the first pass

1. **`packages` does not belong on the Tier-3 cut list.** Its
   `licence-scan.sh` is a genuine mechanism with an argued transitivity case
   (12 transitive MPL-2.0 entries invisible in `package.json`, the
   lockfileVersion-1 silent-false-PASS trap reported via exit 3). The first
   pass's own §4 classification even filed it under mechanism leaves, then
   contradicted itself in the cut list. Move to Tier 1.
2. **`sql` cannot be cut as listed.** `database` — a Tier-1 keep — binds to
   `sql-best-practices` in its `.chassis.json`, its agent, and its review
   command, and W3 merged `database-design` *into* it, making it the
   engine-agnostic floor of the whole DB family. Cutting it orphans a
   mechanism plugin and fails `validate.sh` on dangling references. Either
   keep it or re-point the chassis first; the revised cut list is ten leaves
   (php, postgresql, vue3, nuxt, node-backend, threejs, livewire, mysql,
   i18n, react), ~1,700 tokens.
3. **Recommendation 5 was already satisfied when written.** The 11
   craft-layer corruption sites were repaired by `f38ad65a` ("close the ten
   defects the 2026-08-20 audit measured"), inside the same PR that merged
   the audit. All three named sites verified intact on HEAD by hand this
   pass — `information-design` ends with a complete sentence. The first pass
   repeated the audit's "still shipping" without checking HEAD; strike
   recommendation 5.

### C. What survives unchanged

The verdict. Retire `everything`; cut the measured-zero stack prose (as
revised above); demote `claude-authoring`; spend the eval budget on the seven
expensive Tier-2 workflow plugins; stop maintaining this as a public
marketplace. One model-transfer note the ablations already flag: they ran on
Sonnet, and this pass runs on a stronger model — the direction of that
asymmetry (a stronger model needs restated idiom *less*) leans further toward
the Tier-3 cut, though that is reasoning, not a measurement.

**Standing of this addendum: recorded**, same as the document it extends —
except §A, which is a live observation of the installed host (Claude Code,
this machine, 2026-08-26) and should be re-checked against any later build
before being cited as current behavior.

### D. Third pass, second reload — the evicted set is not even stable

A second `/reload-plugins` of the **identical tree** (verified: no plugin file
changed between passes) produced a different listing:

| Skill | Reload 2 | Reload 3 | On disk |
| --- | --- | --- | --- |
| `ui-ux:design-tokens` | name-only | description restored | 223-ch description |
| `ui-ux:reui-best-practices` | name-only | description restored | 182-ch description |
| `ui-ux:shadcn-best-practices` | description present | name-only | 153-ch description |
| `taskmaster:visual-contract` | loaded | **absent from the load entirely** (banner: 144 → 143 skills) | 237-ch description |

The reload banners themselves disagreed across the sequence — 39/144/43 →
38/144/36 → 38/143/36 (plugins/skills/hooks), with "1 error during load" on the
first. The deep tail (approaches, resilience, orchestration, observability,
secret-scanning, lean, candor, …) stayed stripped in every reload; the flicker
sits at the **margin**, consistent with a budget cutoff whose exact position
shifts run to run.

What this adds to §A: near the budget edge, a skill's trigger vocabulary is not
merely evicted — it is **nondeterministically present**, and in at least one
reload a skill vanished from the load with its name. Any behavior that depends
on a listing entry near the edge is a coin flip per session. The
`visual-contract` disappearance is attributed by diffing the two listings and
corroborated by the banner count; a load error, not eviction, may explain that
one case — either way it is availability the plugin author cannot rely on.

Separately observed live this pass: `skill-router`'s UserPromptSubmit tool-fit
directive fired and reached the model in full — the dynamic channel working as
designed, unaffected by listing eviction, consistent with the README's
"~2.5k tokens on the first work-shaped prompt" figure. The same asymmetry as
§A.3: what the marketplace injects itself arrives intact; what it asks the host
to list does not.

Verdict impact: none on the tiers; it further weakens any plan that trims
descriptions to "fit" the budget — at 38 plugins the margin flickers, so fitting
is not a stable state. The only stable states are well under the budget or
hook/command-routed.

---

## Execution record — 2026-08-26, same branch

Recommendations 1–2 were executed with one scope change and one further
correction; 3–4 remain open.

**Scope change (user decision): `everything` stays installable.** The bundle
was retained at the user's request; its dependency list shrank 61 → 52 and the
`validate.sh` completeness gate continues to hold over it. The §6 argument
against it (a single install that guarantees listing eviction) still stands and
now reads as advice about *using* it, not a removal.

**Fourth cut-list correction, same class as `sql`: `threejs` kept.** It is a
`craft-suite` dependency and referenced from `craft-layer`'s manifest,
description and skills — cutting it orphans a Tier-2 keep. The executed cut is
therefore **nine** leaves: php, postgresql, vue3, nuxt, node-backend, livewire,
mysql, i18n, react.

**What the removal actually touched**, as a record of what "cut a leaf" costs
here: 9 plugin trees deleted; marketplace.json −9 entries (0.92.0 → 0.93.0 with
a root CHANGELOG entry); 5 bundle manifests shrunk and bumped; `database`'s
worker chassis re-pointed to `sql`+`mariadb`; `laravel`'s worker and both
`web-dev` agents re-pointed to surviving skills; `performance`'s bespoke review
command re-pointed; `skill-router` lost 32 rules/blessing lines and three
manifest-priming branches, its README example rows swapped to surviving skills;
four suite READMEs and the root README pruned; all three context-budget
baselines re-measured; the bundle table and plugin-scout catalog regenerated;
and `scripts/smoke/prime-map-tests.sh` re-pointed — its cases asserted the
hook DOES prime the removed skills, so the cut turned the harness red exactly
as CLAUDE.md's "exact gate message strings" warning predicts, and the
expectations now assert omission.

**Measured result:** always-on 12,510 → **11,203 tokens** (−1,307 by the
repo's meter; ≈ −2,000 at the host's 1.54×). Gates at completion: validate.sh,
context-budget.sh, generate.sh --check all exit 0; check-version-bumps runs
against committed state in CI.

**Open:** §6.3 (demote `claude-authoring`, thin `code-review`/`security`) is
deliberately not executed — `claude-authoring` is where CLAUDE.md's four-laws
and has-teeth conventions canonically live "because that one SHIPS", so
demoting it is entangled with the stop-shipping-publicly posture decision that
is the user's alone. §6.4 (ablate Tier 2) stays blocked on `claude plugin
eval` account access.
