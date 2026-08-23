# Distillation — 2026-08-23

Eight blind cluster auditors over all 71 plugins (fable, xhigh, read-only), three
blind refuters over their synthesis, two completeness-critic rounds. 45 findings,
47 refutations, 2 findings killed by the red team, 2 headline numbers found to be
methodology artifacts, and one conclusion overturned by a result already in this
repo that nobody had opened.

Cluster records and the raw synthesis are session-local (scratchpad), not tracked.
What is durable is below.

## The correction this run owes itself

`rationale/eval-ablation-2026-08-20.md` measured `php-best-practices` at **zero
delta in every arm** — n=3 per arm, two fixture designs, including the round-2
manifest-on-disk case its defence rests on. All eight auditors, all three
refuters, and the synthesis described that claim as untested, and one record still
cited `stack-skill-baselines.md:50-53` "never exercised" as live. It was falsified
in-repo three days earlier.

The lesson is not about php. Eleven independent agents were told to measure rather
than recall, and every one of them missed the repo's own most recent experiment
because no instruction said *read the last result first*. A distillation run that
does not begin by reading the previous run's measurements will re-derive them, or
worse, contradict them.

## What was fixed (commit ea7243c)

Only what was reproduced. Each carries a test that fails without it; the
skill-router and command-guard tests were run against the reverted code to prove
they have teeth.

| # | defect | how it survived |
|---|---|---|
| 1 | `skill-router`'s writer and both readers key the state file differently — the low-confidence channel and the `surfaced.jsonl` ledger have been dead since 2026-08-16 | no smoke crossed two hooks; the existing state-file assertion was name-agnostic (`find -name 'fired-*.json'`) |
| 2 | `command-guard` denies its own `/command-guard:check` CLI for exactly the deny-tier targets that command exists to explain | the harness drove CLI mode and hook mode separately; the composition was nobody's case |
| 3 | `api-docs-first`'s trigger regex omits `api` and `library`, 2 of the 3 nouns in its own trigger sentence | a silent miss is unmetered by construction |
| 4 | `context-budget.sh` meters no bundle's own description — 10 × ~69 tok, 25% of product-suite | the bundle branch sums members; nothing measured the bundle dir |
| 5 | the same script's synthetic `Edit` sent no `transcript_path`, metering every context-keyed hook on its fallback branch | `pc_harness_payload` scans harnesses by glob; the meter is not one |
| 6 | `pc_version_stamp`'s header declared itself "recorded, NOT gate" with a promotion work-queue, 21 days after `validate.sh:559` already fed it to `err` | nothing pairs a check's wiring with its standing line |

Regenerating the README bundle table after (4) was `generate.sh --check` catching
drift, and the first draft of this document called that "the gate demonstrating
itself" against `CLAUDE.md:263-265`. **That conflated two scenarios and is
withdrawn.** What `--check` caught was *baseline-change* drift. The sentence in
CLAUDE.md is about *removal* drift, and on that scenario the 2026-08-20 record
measured `--check` staying green — the table stays consistent with an
already-condemned manifest, and the gate that actually fires is `validate.sh`'s
bundle-dependency inheritance. The sentence is still wrong (item 1 below), but
not for the reason that draft gave.

## Needs your call — two false statements in CLAUDE.md

Not applied. CLAUDE.md is project instruction, and a subagent finding is not
authority to edit it.

1. **`CLAUDE.md:263-265`** — "the bundle table at `README.md` drifts on exactly the
   removal the script is for. Nothing gates that table." False on two counts, and
   the file contradicts itself: its own `generate.sh --check` paragraph says
   "edit them by hand and `--check` fails". The bundle-table step landed 2dc38e1
   (2026-08-02); the sentence predates it (43cb641, 2026-07-27). The removal
   scenario it describes cannot even reach a stale-but-passing table —
   `remove-plugin.sh` deletes the marketplace.json entry, so a suite still listing
   the leaf hard-fails `validate.sh:474-488`. Measured: zero drift in all 10 rows.
   True residual worth keeping: `remove-plugin.sh` WARNs rather than edits, so the
   failure is a red CI run, not silent drift.

   **Not new, and that is its own finding.** `rationale/distillation-strategy-2026-08-20.md:376`
   already recorded this exact sentence with the verdict "CLAUDE.md should be
   corrected, or someone will build a redundant check", and §8e already measured
   the removal case. Three days later an eight-agent panel re-derived it as novel.
   Second run in a row this happened (see the php ablation above); the pattern is
   the finding.

   **A live defect underneath it:** `scripts/remove-plugin.sh:131-135` hand-`sed`s
   the `everything` row — which sits INSIDE the `<!-- generated:bundle-table -->`
   region whose own header (README.md:35) reads "do not edit these rows by hand".
   Two writers, one generated region; whichever runs last wins silently.

   An earlier draft of this paragraph called that defect newly found, "in eleven
   agents plus two critic rounds". **That was false, and the correction belongs
   here rather than in a quiet edit.** `rationale/distillation-strategy-2026-08-20.md:590-592`
   records it in near-identical words — same file, same line range, "two writers,
   one region" — three days earlier. It is the FOURTH re-derivation in this run
   (the php ablation, the CLAUDE.md sentence, this, and the sql ratio), and it
   happened inside the paragraph diagnosing that exact failure. A run can name its
   own failure mode and commit it in the same breath; naming it is not immunity.
2. **CLAUDE.md's has-teeth section** — "explicit `Standing:` markers ship in 7
   plugins today". Recount: **13** in shipped `.md`, **17** including hook scripts.
   The recorded-number-trusted-as-measurement trap the file names twice, live in
   its own text.

Both are the **inverse** of the over-claim the has-teeth convention was built to
catch: not a rule pretending to be enforced, but a gate documenting itself as
toothless. That direction is more expensive — it makes a maintainer budget work to
build something that exists. Two independent instances (this pair and defect 6
above) is a class, and no check looks for it.

## Ranked backlog — not applied

Ranked by cost of not knowing. Everything below changes shipped prose or needs a
measurement first, which is why it is a backlog and not a commit.

1. **`motion-tiers/SKILL.md:52` contradicts its own declared source of truth.**
   It prescribes `motion/mini` as the Tier-1 reduced-bundle path;
   `references/tier-budgets.md` — labelled SOURCE OF TRUTH by the SKILL itself —
   prescribes `LazyMotion` + `m.*`, with `motion/mini` reserved for vanilla
   tweens. Contradictory advice shipping today. The SKILL admits the mirror is
   manual and ungated. Body is 312 bytes from the gate.
2. **`craft-suite` ships `rtl-bidi.md`, which cites `plugins/i18n` and refuses to
   restate it — and the bundle does not include i18n.** Measured deps:
   a11y, craft-layer, design-preview, registry-source, shadcn-studio, threejs,
   ui-ux. `validate.sh` resolves references repo-wide, so no gate can see an
   install-set absence. Same class as `database/commands/review.md:29` (backlog
   item 3), and the same class as a mesh of cross-plugin references that no leaf
   `plugin.json` declares — **0 of 61 leaves declare any dependency**, which does
   reproduce. An earlier draft put that mesh at "204 references across 50
   plugins"; **that number does not survive recount** (explicit `plugins/<dst>`
   path references from a different plugin: 73, across 5 source plugins in `.md`).
   It came from a session-local method that was never stated. Corrected here
   rather than deleted, because `distillation-review-2026-08-17.md:210-211`
   already recorded the verdict this instantiates: every mechanism in these runs
   held up under adversarial execution, and every prose number did not.
3. **`database/commands/review.md` is 90.6% identical to `sql/commands/review.md`**,
   both chassis-generated over the same rubric skill, and db-suite ships both;
   its line 29 says "from this plugin" about a skill in `plugins/sql`. Deleting it
   closes both. Watch `README.md:176`, which references `/database:review` and is
   in no generated block.
4. **`resilience/commands/{error,concurrency}-review.md`** — byte-identical hand
   copies of the chassis review, already missing the 8-line hand-up block their
   own generated sibling carries. **Corrected by critic round 2:** "declare them
   in `.chassis.json`" is not available. Commit `93b6ca4` records the copies as a
   deliberate decision with a named blocker — "the stack-review chassis hardcodes
   `commands/review.md`, so a host can carry only one generated review command" —
   and `resilience/.chassis.json` is a single-object schema with no command list.
   The missing triage block is real; the remedy is a chassis multi-command
   extension or a fold into `review.md`, not a declaration.
5. **The 15-line TRIGGER-NARROWING block is byte-identical (md5 `a268a9da`) across
   three plugins' boost hooks.** **Downgraded by critic round 2:** the panel called
   this ungated; in fact `scripts/smoke/hook-guard-tests.sh:164-199` pins the
   BEHAVIOUR of exactly those three hooks with 28 assertions in a blocking CI
   step, and `dispatch-tier.md:63-65`'s admission is about tier STRINGS, a
   different property. What survives: `skill-router/route-prompt.sh` and
   `terse/mode.sh` carry drifted variants that sit outside that harness. Chassis
   templating is still defensible for single-sourcing, but it is not closing an
   open hole, and any `boost-hook.sh.tmpl` must reconcile with the "cite
   `dispatch-tier.md`, do not restate" decision in `8899d48`/`b971a5a`.
6. **`verify-teeth` and `visual-contract` pay always-on description cost (~59 tok
   each) for pipeline-internal bodies.** Sole-caller verified for both by an
   independent grep. Move to `references/` of their caller. Two traps found:
   `task-runner/CHANGELOG.md:131` names `verify-teeth` and needs a
   `<!-- removed-ok -->` marker (rewriting a changelog is invented history), and
   `coding-entry:123` cites `verify-teeth-lint`, which the guard's boundary class
   can never match — that repoint is unnecessary.
7. **Restatement with a named owner** — WCAG SC 2.5.7 stated in full 3×; the
   "green proves nothing" three-layer map stated twice with the copies already
   assigning *different mechanisms* to layers 2 and 3; panel mechanics in 5 files;
   `reduced-motion.md` titled "stated once" while ui-ux states it too. Each is a
   line-range cut with a named owner.
8. **`vite-best-practices:141-149`** jams 6 anti-pattern bullets onto 5 shared
   lines with mid-line ` - ` separators, which renders as one paragraph blob. The
   bullets also restate rules stated above. *Corrected by the red team:* this is
   NOT gate-gaming — `pc_skill_budget` counts body lines and vite's body is 145,
   with 5 lines of headroom. An ordinary SHRINK.
9. **5 of 6 frontend stack skills ship zero evals**, and per critic round 1 only
   **4 of 71 plugins** ship any, **none** with a control arm, with the runner
   early-access-gated. Class H's whole program assumes a harness that does not
   exist in tracked form.

## Killed by the red team — do not re-propose

- **`quality-sec F6`** (trim security-review's Secrets section): the section has 4
  bullets, not 8, so the proposal cut exactly one — `.env` never committed, check
  git history, the highest-yield of the four — and replaced it with a pointer to
  `secret-scanning`, which `quality-principles-suite` and `taskmaster-suite` both
  ship `security` without. The same cluster used bundle-closure to save its own F5.
- **`C3`** (registry-source's MCP instructions unmetered): the local server
  declares no `instructions` field; the ~230 tok comes from the remote server,
  which `context-budget.sh` already names in its closing notes every run.

## Refuted with numbers — the cuts that die, so nobody re-derives them

| proposal | dies on |
|---|---|
| consolidate the 10 bundles | only 2 non-trivial containments exist (process-suite ⊂ taskmaster-suite, quality-principles-suite ⊂ taskmaster-suite); both keep. *Corrected:* the "+5,411 tok" framing prices a migration nobody is forced to make — a bundle row ≈ the sum of its members, so installing the leaves directly costs the same. The real reason is availability: the uninstall command must exist iff its bundle is installed. |
| trim descriptions to shrink `everything` | cost is artifact-COUNT-driven: mean 205 tok/leaf, median 122; only 2 skill descriptions repo-wide ≥430 chars against the 500 gate, both trigger vocabulary. *Corrected:* the "0.8%" had no derivation; measured bounds are 2.8% at a 300-char cap, 17% at 200. Direction holds, magnitude was invented. |
| one parameterized `/review <domain>` | 26 of 33 are already chassis-generated from one template and the runtime fan-in already dedups. *Caveat from critic round 1:* the "would need a universal dependency" argument is weaker than it looks — `task-runner:task-executor` is already named from 41 plugins in prose. |
| merge the 10 uninstall commands | 9 of 10 md5-identical after name-normalizing, and it still dies: the command must exist iff its bundle is installed. |
| merge mysql + mariadb | 7 of 97 mariadb lines >70% similar to any mysql line; all 17 shared rules carry an engine delta. *Corrected:* the "4.9% char similarity" was a difflib autojunk artifact (0.283 with `autojunk=False`, vs 0.15 for unrelated pairs). Cite the line-level number. |
| merge the 7 craft-layer motion skills | each carries a distinct engine contract; shared material is already citation-form. |
| merge plugin-scout + vercel-skills-scout | 8% overlap, deliberately divergent trust models, merged bodies bust the 150-line gate. |
| merge candor + lean + fresh-take | three disjoint rule sets with three disjoint mechanisms. |
| cut `web-dev` / `registry-source` / `database` / `product-suite` | all four earn existence: a dispatch hub, a real MCP server `.mcp.json` can only reach via a plugin, a guard with 17 CI fixtures, an opt-in domain grouping in no other suite. |
| `llm-app` duplicates the host's `claude-api` | 0 measured overlap; it correctly routes those facts to the host skill. |
| extend the generic-ratio shrink to the SQL engines | 2–13% generic, not php's 64% — measured with a three-bucket method; flattening the engine-undated bucket would have manufactured it. The one that DOES match is `sql` itself at 66%, and its own auditor says eval-first, not blind cut. |
| the 9 quality/security hooks and task-runner's 5 vs the three documented failure shapes | all pass, harness payloads checked file by file. |

## Critic round 2 — what a second pass still found

Round 2 was not dry either. Beyond the three corrections folded in above:

- **`sql`'s 66% generic ratio is partly an artifact of a 3-day-old merge.** The
  2026-08-20 strategy classified `sql` at 56% version-pinned leverage on its
  pre-merge 105-line body; `c919d83` then poured `database-design`'s
  engine-generic content in (105 → 139 lines). Trimming per class H would
  partially re-delete content deliberately relocated there — by the same commit
  whose other half this document flags in backlog item 3.
- **C2 has a second instance already recorded as accepted on 2026-08-17.**
  `ui-ux/hooks/palette-default.sh` is path-gated on `*.tsx|*.jsx|*.vue`, so the
  synthetic `src/example.ts` never matches it. The honesty note added in `ea7243c`
  names only testing's matcher; ui-ux ships in 10 bundles. The note should name
  both, or name the class.
- **`rationale/host-lever-probes-2026-08-21.md:84`** says a skill written purely
  as a command's implementation "is the shape that would qualify [for
  `disable-model-invocation`], and none exists here". Backlog item 6 names two:
  `verify-teeth` and `visual-contract`. Whichever remedy lands, that line needs
  updating or the next reader inherits a false empty set.
- **The vite jamming predates the gate that was calibrated on the same file.**
  It entered in `6487412` (2026-08-02) and `d0623e7` — the commit that ADDED the
  300-char lint, message "vite reflowed" — edited this file and left all 5 jammed
  lines as diff context. The proven remedy is that commit's own technique:
  offload to `references/`.
- **terse's three agents were recorded as zero-external-referrer orphans on
  2026-08-02** and still are: the only reference outside `plugins/terse/` is a
  lane note in `code-review/CHANGELOG.md:34`. The three-cluster convergence on
  their descriptions is understated, not wrong.

Round 2 declared clean: all 13 plugin changelogs for done-and-reverted proposals
(zero reverts); the terse "third the tokens" stat (no measurement anywhere, so
that attack survives); local `registry-source/mcp/server.mjs` instructions (none
exist); craft-layer's changelog vs the craft-ui findings (disjoint).

## What this run did not do

- No behavioral measurement. Every generic-ratio verdict is a proxy; the one
  direct measurement that exists (php) came from a doc, not from this run.
- The SHRINK family was not applied. It deletes shipped prose on judgment calls.
- No plugin was removed. `remove-plugin.sh` has a documented README-table gap.
- **The completeness-critic ran its full cap of 3 rounds and never went dry.**
  Round 1: 3 gaps, one overturning a conclusion. Round 2: 9 gaps, three
  correcting this document after it was committed. Round 3: 2 gaps plus a
  security regression in the fixes this run itself landed. The stop condition —
  two consecutive dry rounds — was never met; the cap stopped the loop, not the
  evidence. Almost every gap came from reading `rationale/` and `git log` rather
  than the plugins.

- **This run shipped a vulnerability and then caught it.** `ea7243c`'s
  command-guard self-exemption matched its tokens anywhere in the segment. But
  `bash -c PAYLOAD name arg...` runs PAYLOAD and demotes the rest to positional
  arguments, so appending the magic words to a destructive `bash -c` call
  unlocked it — re-opening the wrapper hole the guard's own deny text warns
  against. Four vectors confirmed, including a `bash -lc` filesystem wipe. Fixed
  in command-guard 0.2.1 by matching on POSITION, with seven bypass vectors now
  in the harness. The lesson is narrow and worth stating plainly: the fix's
  comment reasoned carefully about the wrong threat (a different FLAG) and never
  considered that `-c` decouples what executes from what a substring sees. An
  eight-agent audit found the original defect; no agent reviewed the patch.
  **A fix written by a panel still needs a reviewer.**
