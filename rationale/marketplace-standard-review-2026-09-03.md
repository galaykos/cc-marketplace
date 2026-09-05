# Marketplace standard review — 2026-09-03

**Question asked:** review the marketplace, check if we can upgrade or improve the standard of the marketplace.

**Standard measured:** conformance to this repo's own conventions (CLAUDE.md: four laws, has-teeth, lanes, doc-location, budgets) as enforced by `scripts/validate.sh`'s `pc_*` battery and the three budget/drift gates — plus what the Claude Code plugin platform (2.1.259) offers that the marketplace did not use. Not measured: the 100-point scorer rubric, behavioral efficacy.

**Baseline:** `c53413c`, CI green, 44 plugins (36 leaves + 8 suites), 116 skills, 80 commands, 32 agents, 23 `hooks.json`; `claude plugin validate` passes for 44/44 and the marketplace manifest.

**Method:** context scout over eight prior reviews and the gate battery; three clarifying rounds; a four-persona blind panel on the one structural decision (commands→skills shape); a blind spec red-team (24 holes, all resolved into the spec); then cards, each reviewed by a code reviewer and negative-controlled before it closed. Spec and cards live in `taskmaster-docs/` (gitignored); this file is what survives. **The run stopped after Milestone 2 by the user's decision on 2026-09-04**: the migration and sweep milestones were judged more ceremony than standard once the gates and structural cuts had landed; their rows above say `deferred`.

## Findings

Each proposed upgrade, its standing once landed, and what it catches that nothing else catches. Standing vocabulary: **gate** (a script fails the build), **agent-graded** (a reviewer judges), **recorded** (written, nothing reads it), **unenforceable** (say why).

| upgrade | standing | what it catches that nothing else catches | card |
|---|---|---|---|
| `claude plugin validate --strict` as a CI step | gate — probe 2026-09-03: `env -i PATH="$PATH" HOME="$(mktemp -d)" claude plugin validate --strict plugins/code-review` → `✔ Validation passed`, unauthenticated; the same loop over 44/44 plugins and `marketplace.json` printed no FAIL, including the repo-specific agent frontmatter keys (`floor`, `bestpractices-skill`), so `--strict` stands and no `done-gate.sh` fallback was needed | manifest schema errors and unrecognized `plugin.json` fields. Not skill-frontmatter typos: measured 2026-08-20 accepting an invented `bogusfield:` key (`rationale/distillation-strategy-2026-08-20.md:37`). Run 2026-09-03 over 44/44 + `marketplace.json`: no FAIL, so at this tree it is a regression guard; landed as `scripts/official-validate.sh` (local twin, asserts the 2.1.259 pin) and the last fail-capable CI step | 05 |
| `rules.tsv` col-4 owner must be an existing plugin | gate | a router row pointing at a removed plugin (`rules.tsv:124` still does at `c53413c`) | 02, 03 |
| Deference claims in `plugin.json` backed by a `yields_to` edge | gate (plugin-named targets only) / unenforceable (host built-ins, plugin classes) | a description that promises "defers to X" while no lane edge exists | 04 |
| Chassis lane rows emitted by `generate.sh` | gate | drift between a generated artifact and its hand-typed lane row | 06, 07 |
| claude-authoring demoted to tracked project skills | recorded (removal) + gate (`.claude/skills/*` now under the per-file checks) | always-on tokens billed to every installer for a plugin with one user. Two meters disagree: 801 by `claude plugin details` (`scripts/context-budget-official.json`, taken 2026-08-20; a static per-component estimate over its 12 components, `scripts/context-budget.sh:764-769`, which that header calls "NOT GROUND TRUTH"), 425 by the repo's description-bytes estimate (`scripts/context-budget-baseline.json`). Neither is a measurement of a session; both say the plugin is the largest prose-only always-on cost | 08, 09 |
| code-review's hub and security's review command delegate their generic pass to the host built-ins (`/code-review`, `/security-review`) and keep only what the built-ins lack | recorded | duplicate generic reviews once the host ships `/code-review` and `/security-review`. The plan to delete the `code-reviewer` AGENT was declined mid-run: it is the only stack-agnostic dispatchable reviewer — task-runner's reviewer pass, terse-crew, orchestration's fleet table and role-floors route to it, every per-stack review command's lane row yields to it (`pc_lanes_resolve` fails the build on each if it is deleted), and a host skill cannot be spawned as a subagent | 10, 11 |
| Process leaves re-homed into suites; by-name rule stated | gate for suite membership (`pc_bundle_readme_members` checks the README names each dependency, nothing about truth) / recorded for the by-name sentence, which nothing reads back | leaves reachable only by name with no statement that this is intended | 12 |
| Shared tiered-suggest method extracted | no change needed — measured at execution: the two scout bodies share 0 distinct 12-word runs (the audit's 96 predates plugin-scout 0.15.0's rewrite) | 96 shared 12-word runs between two scouts, as of 2026-08-27 | 13 |
| Commands migrated to user-invocable skills (`disable-model-invocation: true`) | **deferred 2026-09-04** — not landed; belongs in its own scoped run opened by the spike (was: gate + local canary) | 80 descriptions the host lists but never auto-loads; the legacy `commands/` form | 14–21 |
| Lane rows for every skill; coverage promoted to gate | **deferred 2026-09-04** — ~190 hand-written territory claims at once was judged more ceremony than standard; agents and prompt/Stop hooks stay gated, skills stay WARN | an artifact shipping with no declared territory | 22, 23, 27 |
| Every model-invocable skill routed or explicitly `# unroutable:` | **deferred 2026-09-04** — the routing sweep grows the per-prompt surface the 2026-08-31 cost review names as where spend lives | a skill with no router row and no recorded reason | 24 |
| `license: MIT` on every manifest | **deferred 2026-09-04** — README § Licence's "stated once" decision stands until a run adds the field AND a `pc_license_field` gate together | a plugin installed alone carrying no licence statement. **This reverses `README.md` § Licence**, which chose "stated once, here" to avoid one drift site per manifest (63 when that paragraph was written; recount with `ls -d plugins/*/ | wc -l`); the reversal was the user's (round 2) and rests on the platform now reading the field per manifest — an installed plugin does not carry the README. Deferred before card 25 ran, so README § Licence still states the original decision and nothing contradicts it | 25 |
| `Standing:` marker in every plugin | **deferred 2026-09-04** — CLAUDE.md's "adopted incrementally, not in a sweep" stands | a rule whose tier a reader cannot tell from the sentence | 26 |
| CLAUDE.md corrected where measured stale | recorded (warn-only staleness check) | the CI-step count (32→34), the doctrine-home paragraphs, the pre-push block, a new doc-location clause for project skills; the eval and sweep sentences were re-measured and stand | 29 |
| Eval access probed once | recorded — **gated**: `claude plugin eval` prints "currently in early access", exit 1 (2026-09-04) | whether `claude plugin eval` runs on this account at all | 30 |
| Always-on budget stops billing DMI skills | **deferred 2026-09-04** with the migration it depended on | an over-count the host provably does not load | 15, 28 |

## Carried forward from prior reviews

| review | dimension | open item | this run |
|---|---|---|---|
| marketplace-review-2026-07-28 | enforcement mechanism | P2 estimate write-back; structural #4 | declined — no measured demand |
| marketplace-coverage-review-2026-08-02 | coverage breadth | four owner decisions (§519-543) | superseded by the personal-toolchain decision (D3) |
| distillation-2026-08-23 | prose redundancy | all closed | — |
| marketplace-necessity-review-2026-08-26 | admission | §6.3 demote claude-authoring, thin code-review/security | **accepted** (cards 08–11) |
| marketplace-necessity-review-2026-08-26 | admission | §6.4 Tier-2 ablation | still blocked: the probe ran 2026-09-04 and `claude plugin eval` is early-access gated on this account |
| collective-taskforce-backlog | lanes | #7 WARN→gate for commands/skills | accepted, then **deferred 2026-09-04** (see Deferred) |
| collective-taskforce-backlog | lanes | #8 chassis lane rows generated | **accepted** (cards 06, 07) |
| collective-taskforce-backlog | lanes | #9 deference claims ungated | **accepted** (card 04) |
| collective-taskforce-backlog | lanes | #1 `prime.sh` map generation, #6 compaction unverified | declined — #1 needs a fifth chassis type nothing else asks for; #6 depends on harness semantics no artifact establishes |
| 2026-08-31-token-cost-review | cost | agents' listing cost unmetered | declined — unverified whether agents draw on the listing budget |
| 2026-09-01-fable5-prompt-alignment | host contradiction | all applied | — |
| official-plugins-gap-review-2026-09-02 | parity | hookify, ralph-loop, Stop-time LLM security review, type-design-analyzer, LSP/MCP | declined — each is a new capability, not a standard; none of the four laws asks for it |
| standards-audit-2026-08-27 (gitignored) | conformance | F5 lanes, F8 licence, F11 scout dedupe, F14 bundles | F14 **landed** (12); F11 already satisfied on measurement (13); F5 and F8 accepted then **deferred 2026-09-04** |
| standards-audit-2026-08-27 | conformance | F2 line-cap crowding | closed by the cap move 150→200; one skill at ≥195 lines |
| standards-audit-2026-08-27 | conformance | F10 eval pick-a-side | resolved by the probe (card 30); no CI job either way |

## Declined, with one reason each

- **Scorer rubric run** — the user chose conventions conformance as the measure; a score with no control arm is a number, not a standard.
- **Eval `workflow_dispatch` CI job** — a manual job nobody must trigger is the same theater the unrun suites already were.
- **`prompt` signal type for the router** — regex-over-prompt duplicates the host's description-based auto-invocation; prompt-shaped skills get an explicit `# unroutable:` line instead.
- **Byte-cap exemption for migrated skills** — weakening a gate that exists because of measured bloat lowers the standard this run raises; the two oversize bodies split into `references/`.
- **CHANGELOG backfill** — invented history in the file whose job is history (CLAUDE.md already says so).
- **New suites (backend-suite)** — five stack leaves are correctly install-by-name.
- **New hook events, `lspServers`, `mcpServers`, `channels`** — capability, not conformance.
- **Deleting the `code-reviewer` agent** — found mid-run: it is the stack-agnostic dispatchable reviewer that every reviewer pass and every per-stack review command's lane row routes to; the host's `/code-review` is a skill, not an agent type. The hub delegates to the built-in instead.
- **Deleting `/security:review`** — found mid-run: the command carries audit folding, secret-scan folding and a threat-model disposition audit the host `/security-review` lacks, and shipped handoffs across nine plugins route the security-deep lane to it (recount: `grep -rn 'security:review' plugins/ | grep -v '^plugins/security/'`, minus catalogue, comparison and comment mentions). It delegates the generic pass to the built-in instead.
- **Collapsing commands into their backing skills** (blind-panel Purist/Quality take) — multi-skill commands are not 1:1; mixes orchestration into knowledge skills.
- **Pilot-only migration** (Pragmatist take) — the user chose full scope; the spike card keeps the pilot's safety.

## Deferred 2026-09-04, with the reason

- **Commands → user-invocable skills (cards 14–21)** — touches every gate, five harnesses, the prompt catalog and both chassis templates for a payoff of platform alignment plus ~80 descriptions leaving the listing; the riskiest block with the smallest measured benefit. Reopen as its own run, spike first (four verifications in the spec).
- **Lane rows for every skill and the WARN→gate promotion (22, 23, 27)** — ~190 hand-written territory claims in one sweep; the honest tier for skill lanes today is WARN.
- **Routing every skill (24)** — grows the per-prompt UserPromptSubmit surface, the channel the 2026-08-31 cost review measured as where spend lives.
- **Licence field (25), Standing markers (26), DMI baseline (28)** — fell with the sweeps; the README's "stated once" licence decision and CLAUDE.md's incremental-adoption sentences stand.

## Measurements

Recount commands, not copied numbers. "Before" is `c53413c`; "after" is filled by the closing card.

| gap | recount | before | after |
|---|---|---|---|
| plugins (the denominator below) | `ls -d plugins/*/ \| wc -l` | 44 |  43 |
| skills with no router row or exemption | `python3 -c "import glob,os;s={os.path.basename(os.path.dirname(p)) for p in glob.glob('plugins/*/skills/*/SKILL.md')};r=open('plugins/skill-router/rules.tsv').read();print(sum(1 for x in s if f'\t{x}\t' not in r),'of',len(s))"` | 88 of 116 |  81 of 109 |
| plugins with `lane.tsv` | `ls plugins/*/lane.tsv \| wc -l` | 26 of 44 |  36 of 43 |
| plugins with `CHANGELOG.md` | `ls plugins/*/CHANGELOG.md \| wc -l` | 15 of 44 |  14 of 43 |
| plugins with `evals/` | `ls -d plugins/*/evals \| wc -l` | 2 of 44 |  2 of 43 |
| manifests with `license` | `grep -l '"license"' plugins/*/.claude-plugin/plugin.json \| wc -l` | 0 of 44 |  0 of 43 |
| plugins with a `Standing:` marker | `grep -rl "Standing:" --include='*.md' plugins/ \| cut -d/ -f2 \| sort -u \| wc -l` | 29 of 44 |  29 of 43 |
| `commands/*.md` files | `ls plugins/*/commands/*.md \| wc -l` | 80 |  75 |

## Spike record

Not run. The migration milestone (cards 14–21) was deferred on 2026-09-04 before its spike; the four verifications the spike was to record are in the spec (`taskmaster-docs/`, gitignored) and belong to the run that reopens it.

## Eval probe

```
$ claude plugin eval plugins/resilience --runs 1 --max-cost-usd 1 --no-publish --json /tmp/eval.json
`plugin eval` is currently in early access
exit=1
```

Run 2026-09-04 on Claude Code 2.1.259. Gated on this account; no arm ran, nothing was spent. The `--ablation with-without` control arm the runner advertises stays unmeasured here. No CI job was added (declined above). The two shipped suites (resilience, web-dev) remain `recorded`, as CLAUDE.md says.

---

**Standing: recorded** — no script reads this file. The findings table names the standing each upgrade has once its card lands; until then every row is a proposal.
