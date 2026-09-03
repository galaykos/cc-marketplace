# Marketplace standard review — 2026-09-03

**Question asked:** review the marketplace, check if we can upgrade or improve the standard of the marketplace.

**Standard measured:** conformance to this repo's own conventions (CLAUDE.md: four laws, has-teeth, lanes, doc-location, budgets) as enforced by `scripts/validate.sh`'s `pc_*` battery and the three budget/drift gates — plus what the Claude Code plugin platform (2.1.259) offers that the marketplace did not use. Not measured: the 100-point scorer rubric, behavioral efficacy.

**Baseline:** `c53413c`, CI green, 44 plugins (36 leaves + 8 suites), 116 skills, 80 commands, 32 agents, 23 `hooks.json`; `claude plugin validate` passes for 44/44 and the marketplace manifest.

**Method:** context scout over eight prior reviews and the gate battery; three clarifying rounds; a four-persona blind panel on the one structural decision (commands→skills shape); a blind spec red-team (24 holes, all resolved into the spec); then cards. Spec and cards live in `taskmaster-docs/` (gitignored); this file is what survives.

## Findings

Each proposed upgrade, its standing once landed, and what it catches that nothing else catches. Standing vocabulary: **gate** (a script fails the build), **agent-graded** (a reviewer judges), **recorded** (written, nothing reads it), **unenforceable** (say why).

| upgrade | standing | what it catches that nothing else catches | card |
|---|---|---|---|
| `claude plugin validate --strict` as a CI step | gate if the CLI runs unauthenticated on a runner, else turn-blocking via `done-gate.sh` — settled by card 05's probe | manifest schema errors and unrecognized `plugin.json` fields. Not skill-frontmatter typos: measured 2026-08-20 accepting an invented `bogusfield:` key (`rationale/distillation-strategy-2026-08-20.md:37`). Plain `validate` passes 44/44 at `c53413c`; `--strict` was last run 2026-08-20 over a 71-plugin tree (all passed) and is unrun at `c53413c` — whether it finds anything now is card 05's probe | 05 |
| `rules.tsv` col-4 owner must be an existing plugin | gate | a router row pointing at a removed plugin (`rules.tsv:124` still does at `c53413c`) | 02, 03 |
| Deference claims in `plugin.json` backed by a `yields_to` edge | gate (plugin-named targets only) / unenforceable (host built-ins, plugin classes) | a description that promises "defers to X" while no lane edge exists | 04 |
| Chassis lane rows emitted by `generate.sh` | gate | drift between a generated artifact and its hand-typed lane row | 06, 07 |
| claude-authoring demoted to tracked project skills | recorded (removal) + gate (`.claude/skills/*` now under the per-file checks) | always-on tokens billed to every installer for a plugin with one user. Two meters disagree: 801 by `claude plugin details` (`scripts/context-budget-official.json`, taken 2026-08-20; a static per-component estimate over its 12 components, `scripts/context-budget.sh:764-769`, which that header calls "NOT GROUND TRUTH"), 425 by the repo's description-bytes estimate (`scripts/context-budget-baseline.json`). Neither is a measurement of a session; both say the plugin is the largest prose-only always-on cost | 08, 09 |
| code-review thinned to a fan-in hub; security's review command removed | recorded | duplicate generic reviews once the host ships `/code-review` and `/security-review` | 10, 11 |
| Process leaves re-homed into suites; by-name rule stated | gate for suite membership (`pc_bundle_readme_members` checks the README names each dependency, nothing about truth) / recorded for the by-name sentence, which nothing reads back | leaves reachable only by name with no statement that this is intended | 12 |
| Shared tiered-suggest method extracted | recorded | 96 shared 12-word runs between two scouts | 13 |
| Commands migrated to user-invocable skills (`disable-model-invocation: true`) | gate (validator + static harness) / recorded (live-resolution canary) | 80 descriptions the host lists but never auto-loads; the legacy `commands/` form | 14–21 |
| Lane rows for every skill; coverage promoted to gate | gate | an artifact shipping with no declared territory | 22, 23, 27 |
| Every model-invocable skill routed or explicitly `# unroutable:` | gate | a skill with no router row and no recorded reason | 24 |
| `license: MIT` on every manifest | gate once card 25 lands `pc_license_field` (nothing today requires the field; `--strict` only accepts it) | a plugin installed alone carrying no licence statement. **This reverses `README.md` § Licence**, which chose "stated once, here" to avoid one drift site per manifest (63 when that paragraph was written, 44 today); the reversal is the user's (round 2) and rests on the platform now reading the field per manifest — an installed plugin does not carry the README. Card 25 rewrites that README paragraph so the two do not contradict | 25 |
| `Standing:` marker in every plugin | recorded | a rule whose tier a reader cannot tell from the sentence | 26 |
| CLAUDE.md corrected where measured stale | recorded (warn-only staleness check) | five sentences contradicted by a recount | 29 |
| Eval access probed once | recorded | whether `claude plugin eval` runs on this account at all | 30 |
| Always-on budget stops billing DMI skills | gate (baseline) | an over-count the host provably does not load | 15, 28 |

## Carried forward from prior reviews

| review | dimension | open item | this run |
|---|---|---|---|
| marketplace-review-2026-07-28 | enforcement mechanism | P2 estimate write-back; structural #4 | declined — no measured demand |
| marketplace-coverage-review-2026-08-02 | coverage breadth | four owner decisions (§519-543) | superseded by the personal-toolchain decision (D3) |
| distillation-2026-08-23 | prose redundancy | all closed | — |
| marketplace-necessity-review-2026-08-26 | admission | §6.3 demote claude-authoring, thin code-review/security | **accepted** (cards 08–11) |
| marketplace-necessity-review-2026-08-26 | admission | §6.4 Tier-2 ablation | blocked on eval access; probe in card 30 |
| collective-taskforce-backlog | lanes | #7 WARN→gate for commands/skills | **accepted** (cards 22, 23, 27) |
| collective-taskforce-backlog | lanes | #8 chassis lane rows generated | **accepted** (cards 06, 07) |
| collective-taskforce-backlog | lanes | #9 deference claims ungated | **accepted** (card 04) |
| collective-taskforce-backlog | lanes | #1 `prime.sh` map generation, #6 compaction unverified | declined — #1 needs a fifth chassis type nothing else asks for; #6 depends on harness semantics no artifact establishes |
| 2026-08-31-token-cost-review | cost | agents' listing cost unmetered | declined — unverified whether agents draw on the listing budget |
| 2026-09-01-fable5-prompt-alignment | host contradiction | all applied | — |
| official-plugins-gap-review-2026-09-02 | parity | hookify, ralph-loop, Stop-time LLM security review, type-design-analyzer, LSP/MCP | declined — each is a new capability, not a standard; none of the four laws asks for it |
| standards-audit-2026-08-27 (gitignored) | conformance | F5 lanes, F8 licence, F11 scout dedupe, F14 bundles | **accepted** (22/23, 25, 13, 12) |
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
- **Collapsing commands into their backing skills** (blind-panel Purist/Quality take) — multi-skill commands are not 1:1; mixes orchestration into knowledge skills.
- **Pilot-only migration** (Pragmatist take) — the user chose full scope; the spike card keeps the pilot's safety.

## Measurements

Recount commands, not copied numbers. "Before" is `c53413c`; "after" is filled by the closing card.

| gap | recount | before | after |
|---|---|---|---|
| plugins (the denominator below) | `ls -d plugins/*/ \| wc -l` | 44 | |
| skills with no router row or exemption | `python3 -c "import glob,os;s={os.path.basename(os.path.dirname(p)) for p in glob.glob('plugins/*/skills/*/SKILL.md')};r=open('plugins/skill-router/rules.tsv').read();print(sum(1 for x in s if f'\t{x}\t' not in r),'of',len(s))"` | 88 of 116 | |
| plugins with `lane.tsv` | `ls plugins/*/lane.tsv \| wc -l` | 26 of 44 | |
| plugins with `CHANGELOG.md` | `ls plugins/*/CHANGELOG.md \| wc -l` | 15 of 44 | |
| plugins with `evals/` | `ls -d plugins/*/evals \| wc -l` | 2 of 44 | |
| manifests with `license` | `grep -l '"license"' plugins/*/.claude-plugin/plugin.json \| wc -l` | 0 of 44 | |
| plugins with a `Standing:` marker | `grep -rl "Standing:" --include='*.md' plugins/ \| cut -d/ -f2 \| sort -u \| wc -l` | 29 of 44 | |
| `commands/*.md` files | `ls plugins/*/commands/*.md \| wc -l` | 80 | |

## Spike record

(filled by card 14)

## Eval probe

(filled by card 30)

---

**Standing: recorded** — no script reads this file. The findings table names the standing each upgrade has once its card lands; until then every row is a proposal.
