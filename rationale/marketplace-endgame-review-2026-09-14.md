# Marketplace endgame review — 2026-09-14

**Question asked (as improved before execution):** what would make this marketplace
complete for a Claude Code developer — every mechanism a plugin *should* carry is
carried here, and everything it should not (a language server, a browser MCP) is
named as a route rather than left to discovery — and can every leaf be switched on at
once? Walk all 27 leaves and 4 bundles against one rubric (the mechanism that earns
each, the standing of every rule, overlaps, stale claims, what a user still needs from
elsewhere); compare against the official directory, the community collections and what
the host CLI now ships built-in; measure "all on". The first draft of the question
said "never install another plugin"; the user withdrew that mid-review — nobody is
rebuilding playwright — so §2 reads as a route list, not a residual.

**Standing of this document: `recorded`.** Nothing reads it back. Every number
carries a recount command. Where a claim came from an agent, it was checked against
the tree or re-run before being kept; where it could not be, it says so.

**Method.** Seven read-only agents, same day, on CLI 2.1.270: three tree walkers by
domain (guards/session/workflow; review/stack; design + bundles), an
official-directory researcher, a community-collections researcher, an always-on
analyst who ran every hook with synthetic payloads, and a contradiction auditor.
Raw reports and the probe scripts are in `taskmaster-docs/endgame-2026-09-14/`
(gitignored — working material, per `CLAUDE.md`). The two most recent reviews,
`marketplace-consolidation-plan-2026-09-14.md` (waves 0–3 executed today) and
`plugin-landscape-review-2026-09-10.md`, are cited, not restated.

---

## 1. Snapshot

| measure | value | recount |
|---|---|---|
| plugin dirs | 31 = 27 leaves + 4 bundles | `ls -d plugins/*/ \| wc -l` |
| skills / commands / agents | 104 / 60 / 28 | `ls plugins/*/skills/*/SKILL.md \| wc -l` etc. |
| listing entries, all 27 leaves | 160 (104 skills + 56 commands) = 38,547 chars | `python3 taskmaster-docs/endgame-2026-09-14/listing27.py` or the listing block of `bash scripts/context-budget.sh` |
| vs listing budget | 6.42× at 200k (6,000), 1.28× at 1M (30,000) | same |
| always-on tokens, all 27 leaves | 10,474 | `bash scripts/context-budget.sh \| grep ^TOTAL` |
| hook rows / plugins with hooks | 48 / 21 | `for f in plugins/*/hooks/hooks.json; do jq '[.hooks[][]] \| length' $f; done` |
| Stop-gate registrants | 1 (candor) | `grep -l '"Stop"' plugins/*/hooks/hooks.json` |
| skills unrouted by skill-router | 76 of 104 | CLAUDE.md's one-liner |
| leaves in no bundle | 9 | §4 |
| plugins with `Standing:` lines | 27 (all) — but two guard plugins carry none in their README | `grep -rl "Standing:" --include='*.md' plugins/ \| cut -d/ -f2 \| sort -u \| wc -l` |
| CHANGELOGs / eval suites | 19 / 3 | `ls plugins/*/CHANGELOG.md \| wc -l`; `ls -d plugins/*/evals \| wc -l` |

---

## 2. What this marketplace routes to on purpose

The admission law says a plugin earns existence by carrying a rule the model gets
wrong or a mechanism prose cannot replace. Applied to everything the ecosystem ships
that this marketplace does not, the list of things a developer installs *alongside*
it — and that `/stack-scan:suggest`'s "beyond this marketplace" tier must keep naming
by install command — is:

| install alongside | from | why it is a route, not a build |
|---|---|---|
| a language server | official `*-lsp` (13) | 8 lines of JSON each, zero rule; the host's own LSP doc routes to the official ones by name |
| a browser MCP | official `playwright` | re-declaring `npx @playwright/mcp@latest` makes this repo the version owner of a third-party process that starts with no trust prompt |
| versioned docs | `context7` (hosted) | relabels a vendor endpoint |
| a semantic-code MCP | `serena` | unpinned code from a git URL |
| Python / Go / Rust / Ruby / Django / Rails / Terraform / Swift / Kotlin packs | skills.sh via `/stack-scan:suggest --skills` | checklist shape; `measured-zero-shapes.md` shape 1; rejected three reviews running |

That is the whole list, and it is the job of `stack-scan`'s scout to print it with
install commands whenever the manifests show the stack (a `.php` repo → `php-lsp`; a
Playwright dep → `playwright`). Everything else on the official side is either covered
here (`/commit`-shaped work, ralph-loop, dangerous-command guard — ours is the only one
that covers MCP SQL), superseded by the host (`/goal`, `/simplify`, `/init`), or
absorbable (§3). **No new vendor-agnostic official plugin has appeared since the 09-02 gap
review** — five entries were added, all vendor-locked (recount:
`gh api repos/anthropics/claude-plugins-official/compare/c3cbf811...HEAD`).

On the community side the picture inverts: the most-starred collections are almost
entirely prose (superpowers 286K★ ships one SessionStart hook; mattpocock/skills 262K★
ships zero hooks; every top-15 skills.sh entry is prose), while the collection with the
most teeth — `karanb192/claude-code-hooks`, 22 single-hook plugins, 1,922 tests — has
511 stars. Stars measure distribution. From that scan, the mechanisms nothing here
carries and that pass the admission law (the model demonstrably does the wrong thing
from memory; a script catches it; prose does not) are the **build list in §8, wave C.**

---

## 3. What the host now does that a plugin here also does

The larger finding is not on the official marketplace but in the CLI. Between 2.1.237
(the version the 09-02 review read) and 2.1.270:

- **33 hook events** are documented; this tree uses 7. Two hook *types* are new —
  `prompt` and `agent` — a Stop/PostToolUse hook that spawns a verifier with tool access
  and returns `{ok:false, reason}` to block. Fields `if`, `async`, `asyncRewake`, `once`.
- **`/goal`** is documented as "a built-in shortcut for a session-scoped prompt-based
  Stop hook" — ralph-loop is in the host.
- **Built-in commands** now sit on the same listing as ours: `/code-review` (levels,
  `--fix`, cloud `ultra`), `/simplify`, `/security-review`, `/verify`, `/run`, `/batch`
  (one background subagent per worktree, PR each), `/deep-research` (a bundled
  *workflow*), `/skill-doctor` (per-skill context cost and use).
- **`claude plugin eval` shipped in 2.1.269** with `--ablation with-without` as the
  default — the early-access gate in `eval-ablation-2026-08-20.md` is gone.

Direct overlaps, and what to do with each:

| host | plugin here | verdict |
|---|---|---|
| `type: agent` Stop hook | `candor` gate.sh (647-line shell; four string-check clauses) | keep — candor's clauses are deterministic and cheap; an agent hook is the shape for the *judgment* clauses this tree does not have yet (§8 C) |
| `/deep-research` workflow | `ultra-deep-research` | **measure** with `plugin eval --ablation`; a zero delta retires the leaf |
| `/batch` | `task-runner:run --tracks`, `track-orchestration` | measure; tracks carries the merge-by-sole-writer rule `/batch` does not |
| `/code-review`, `/simplify`, `/security-review` | `code-review:review`, `low-cognitive-load`, `security:review` | keep — ours fan in the stack rubrics and carry the comment-discipline denies; name the built-in in each README so a user sees two entries and knows why |
| `/skill-doctor` | `scripts/turn-cost.sh --skills` | maintainer path; adopt the host's number when it stabilises |
| `security-guidance`'s Stop-time LLM diff review | none | **absorb** into `security` as an opt-in `type: agent` Stop hook (~20 lines of hooks.json, no Python) — the 09-02 reason for routing ("needs an out-of-band model call") no longer holds |

---

## 4. "Always on" — one settings key, no hook changes

**Enabling all 27 leaves is mechanically possible today (no bundle exists; 27 installs
or one `enabledPlugins` block) and at the default listing fraction it is a broken
install at both window sizes.** 160 entries at 38,547 chars means 141–157 of them
arrive name-only at 200k and 24–67 at 1M; which ones is decided by a priority order the
CLI does not expose.

The fix is one key (`settings.json`):

```jsonc
{ "skillListingBudgetFraction": 0.07 }    // 200k window: cap 42,000 ≥ 38,547
{ "skillListingBudgetFraction": 0.014 }   // 1M window:   cap 42,000
```

Cost: ≈12.8k system-prompt tokens per turn instead of ≈2k (5.4% of a 200k window, 1.1%
of 1M). The always-on surface stays at 10,474 tokens and, per
`2026-08-31-token-cost-review.md`, that whole channel is ~1% of session spend — the key
moves reachability, not the bill. `skillListingMaxDescChars` never binds (longest
description is 475 of 1,536).

The hook plane needs nothing changed first. Measured with every hook executed against
synthetic payloads (`taskmaster-docs/endgame-2026-09-14/*-probe.sh`):

| channel | processes | bytes injected |
|---|---|---|
| per prompt | 11 | chat-shaped prompt: 0 from all 11; work-shaped: ≈6,975 B ≈ 1.7k tok, 96% of it `skill-router/route-prompt.sh` (once per session) |
| per Edit/Write | 9 pre + 11 post | 1.1–2.1 KB when detectors trip; `conventions`, `palette-default`, `test-shape` are once per session |
| per Bash | 3 | command-guard deny/ask, git-workflow trailer deny, task-runner consent (only inside a run) |
| per Stop | 1 | candor, four clauses, exit 2 |
| per compaction | 6 | ~2 KB + the catalog |

What remains regardless of the key — three residuals, none a blocker:

1. **An ask-vs-deny split is constructible on one Bash command** (`git commit -m
   '<AI trailer>' && git push --force-with-lease`: command-guard asks, git-workflow
   denies) and cross-hook precedence is documented nowhere in the repo.
2. **`code-review/hooks/scan.sh` is the one guard that refuses ordinary work** — a
   PreToolUse deny on the first comment-heavy write per file per session.
3. **`.claude/cc-phase.json` has four prose writers and no owning hook**; five
   reminder hooks and the compact capsule read it.

Bundles: all four are OVER the 200k floor (core 1.1×, frontend 1.1×, craft 1.7×,
workflow 4.0×) and the root README names the fraction for two of them. Nine leaves are
in no bundle (api-design, brain, command-guard, database, devops, laravel, overseer,
resilience, ultra-deep-research). An `everything-suite` would be a real object here
(plugin.json + 27 dependencies + chassis uninstall + lane.tsv) and was retired on
2026-08-31 at 1.6× over the 1M budget; it is 1.28× now and would be ≈1.0× after wave
A and the wave-4 folds. **Recommendation: ship it when it crosses under, not before** —
a bundle that needs a settings key to be reachable is a bundle whose README is the
product.

---

## 5. What the walk found, by class

Each item names its plugin and is a one-PR fix unless marked. Line numbers were
verified today; recount with the grep given.

**Claims that drift from the tree (the has-teeth convention's own failure mode)**

1. `taskmaster/README.md:61-65` says the clarifying directive is exempt from the
   one-reminder-per-prompt lottery. Commit `bd1ee6d3` removed the exemption and gave it
   `arcRank: 90`; the lottery picks the lowest rank (`hooks/remind.sh:205-207`). On a
   bare prompt approaches (30), debugging (20), api-design (40) and consult-remind (10)
   all win. `skill-router/lane.tsv:6-8` still yields on the old premise. **The
   grill-first doctrine — the marketplace's headline — does not fire in workflow-suite
   unless the phase file already exists.** Decide: restore an exemption, or rewrite the
   README and the router's yield.
2. The §4.1 fan-in hazard recurred one wave later. `code-review/commands/review.md`
   loads five resilience rubrics; `event-driven` (moved in wave 1) is absent while
   `resilience/README.md:39-40` claims "all six". Same shape for
   `laravel:inertia-best-practices`: `laravel/README.md:8-10` says the fan-in loads it;
   `grep inertia plugins/code-review/` → 0. One-line fixes at `review.md:39` and `:121`.
3. `code-review/README.md:91` "silence any advisory with `CC_REMIND=off`" — only
   `conventions.sh` reads it; `scan.sh`, `density.sh`, `verbosity.sh` and
   `security/hooks/write-scan.sh` have no switch. Wire it or delete the sentence.
4. README inventories drift in five plugins: taskmaster (5/10 skills, 1/2 agents, 2/5
   hooks, 3/5 commands listed), code-architecture (4/5 commands, 8/9 skills), hindsight
   (a skill listed as a command; 1/2 hooks), approaches (two skills in the Commands
   table), craft-layer (4/5 commands). Plus stale numbers: skill-router "~50 skills"
   (104), command-guard "187 assertions" (217), hindsight "126 skills" (104),
   craft-suite "~8,796 chars" (10,135).
5. Removed-plugin names living in **always-on listing bytes**, ungated because they are
   not in `pc_removed_refs`' `plug=` list: `devops/skills/devops-practices/SKILL.md:3`
   and `agents/devops-engineer.md:3` route to `dev-env` and `observability`;
   `security/hooks/write-scan.sh:45` cites `lean/hooks/budget.sh`; `security/README.md:81`
   cites `php`; `stack-scan/.../flags.md:74` counts `lean` among four routes;
   `ui-ux/README.md:97` `vue3`; `craft-layer/README.md:238` `a11y`. Extend the list
   with `dev-env|observability` in the same commit.
6. Tier over-claims: `code-architecture/README.md:52` calls `drift-review` a "done-time
   gate" (nothing runs it); `ultra-deep-research/README.md:48-58` "one mechanical gate"
   for `verdict-lint.sh`, which only prose invokes; every bundle README and root
   `README.md:112` say "manually installed plugins are never touched" — the uninstall
   procedure cannot tell manual from auto. Under-claims: `secret-scanning` has zero
   `Standing:` lines; `devops` never says what its guard denies.

**Mechanisms with a hole**

7. **MCP write/exec tools bypass four guards at once.** `secret-scanning` matches
   `Write|Edit|MultiEdit` only; candor clause 3 arms only on those (`gate.sh:573`);
   `skill-router/route.sh` keys on `tool_input.file_path`; `overseer/track-read.sh`
   ledgers `Read` only. `command-guard` misses `mcp__phpstorm__execute_run_configuration`,
   `execute_tool`, `build_project` and playwright's `browser_run_code_unsafe`. A
   PhpStorm-MCP session is unguarded on every one of these while every README reads as
   universal. Fix: widen the matchers (`.*apply_patch|.*create_new_file` on the write
   guards; the three execute tools on command-guard) and state the residual.
8. Seven craft-layer references stamp `> **Last verified:**` in bold, invisible to
   `check-doc-staleness.sh:92`; they age past 90 days on 2026-10-23 with no warning.
9. `stack-scan/scripts/licence-scan.sh:126,139` reads only `package-lock.json` and
   `composer.lock`; a pnpm/yarn/bun repo exits 3 while `README.md:5` advertises those
   lockfiles.
10. `database/hooks/guard.sh` recognises only Laravel `Schema::` spelling — Prisma,
    Drizzle, TypeORM, Doctrine and Alembic migrations pass unasked.
11. `ui-ux/lane.tsv:8` declares `a11y-audit` triggers on `.blade.php`; `rules.tsv:95`
    routes Blade to laravel only. Blade, Svelte and Astro edits never get the WCAG
    checklist. Seven of twelve ui-ux skills have no router row at all (shadcn among
    them) — a shadcn repo reaches its skill only if the description wins the listing.

**Rank vs lane**

12. `approaches:consult-remind` (rank 10) outranks `debugging:remind` (rank 20) on
    "third time" phrases while `approaches/lane.tsv` has consult *yield* to debugging.
    Both are phase `any` with distinct `owns`, so `pc_lanes_territory` cannot see it.
    Swap the ranks.
13. `/testing:review` and `/devops:review` hand up to the fan-in and are the two
    `/…:review` entries wave 1 left standing without a §5 reason; `/api-design:review`
    is chassis-opted-out with no hand-up at all; `/craft-layer:review` duplicates the
    fan-in's threejs load. Four listing entries ≈ 1,000 chars.

---

## 6. design-studio — decided during the review

The user asked, mid-review, what the plugin solves that an HTML snippet plus a
question does not. Evidence on this machine: **one** real invocation of
`/design-studio:init|preview|export` (or its theme-design/design-lab predecessors)
across the ten projects it was installed in; **zero** transcripts with a `registry_*`
tool call. Cost: 793 always-on tokens (third-highest leaf), 5 listing entries, 140 KB
of Python/JS/CSS, one local MCP process per session. The README concedes the skins are
"lookalikes, never the library" and that real components are the preview's job;
`taskmaster:visual-decisions` already serves shell mockups on a preview URL and asks.
The registry MCP duplicates shadcn's official one (`npx shadcn@latest mcp init`) and
ReUI's hosted one. **Decision: retire the plugin** — wave A below. Walk-C's verdict was
"keep" and predates the usage evidence; it is recorded here so the disagreement is
visible.

---

## 7. Contradictions

The auditor read the seven merged plugins in full, probed every hook tier against its
script, ran command-guard's `--check` over the 17 commands other artifacts instruct,
and reports what it did NOT read (about a hundred `references/*.md` grep-only; hooks
other than command-guard verified by reading, not driving). Eight of its hits were
already in §5 and are not repeated. New, ranked by how likely a session meets them:

| # | the two claims | who wins, and the fix |
|---|---|---|
| C1 | `code-architecture/commands/coding-task.md:19` "Load the six always-relevant skills" vs `skills/coding-entry/SKILL.md:19` "Five:" — wave 1 dropped `lean:cost-model` and left the count | the skill; six → five |
| C2 | `ui-ux/README.md:75-79` "Both advisory … never blocks" vs `hooks/preview-guard.sh:116` `permissionDecision: "ask"` on every STRONG artifact — an ask stops the tool call, which this repo's own vocabulary calls a gate with a human in it (`command-guard/README.md:137`) | the script; re-tier the README row |
| S1 | `skill-router/.claude-plugin/plugin.json:4` promises "engine-aware MySQL/MariaDB/PostgreSQL rows"; `rules.tsv:57` says "mariadb is the ONLY dialect skill left" — always-on bytes promising rows that do not fire | the rules; fix the description |
| C3 | `approaches/README.md:55` disowns the stuck-loop phrases while its own `consult-remind` regex claims `tried everything\|third time` at rank 10 and wins them from debugging | judgment: drop the phrases from consult's regex (pairs with §5.12) |
| C6 | `candor/skills/terse-output/SKILL.md:68` "No emoji" vs `taskmaster/commands/task.md:15-16` mandated ⚡ banner, parity-gated by `validate.sh` | taskmaster; terse-output gets a protocol-banner carve-out like its existing verdict-language one |
| C4 | terse-output's finding form `path:line — problem → impact` vs candor's own clause 1, which blocks a citation into a file the turn just deleted or shortened | the gate; skeleton allows `path — problem` when the location is gone at Stop |
| C5 | `git-workflow/skills/branch-completion/SKILL.md:84` "never `--abort` to dodge a hunk" vs `task-runner/skills/track-orchestration/SKILL.md:86` "textual conflict → `--abort`, park" | both, in context — neither names the other; one clause in branch-completion |
| C7 | root `README.md:484-486` enumerates four turn-blocking gates; git-workflow's trailer deny and devops' workflow deny are two more — the counted-list shape CLAUDE.md forbids | replace with a recount: `grep -l 'permissionDecision:"deny"\|exit 2' plugins/*/hooks/*.sh` |
| C8 | `.claude/skills/authoring-hooks/SKILL.md:115-116` "no clock-dependent branches" vs every chassis reminder hook's `-mmin +120` TTL, argued in the hook header | practice; the doctrine carries the exception (TTL on leaked state yes, network no) |
| C9 | root `README.md:105` sells frontend-suite for Inertia; `frontend-suite/README.md:8` "Inertia lives in the laravel plugin" | the bundle; drop the word |

Four suspicions it could not quote both sides of, left open on purpose: what the host
does with an unanswered `ask` under `--hands-off` (database's guard asks on every
`Schema::drop*`, which laravel's skill mandates in `down()` — the same question
`taskmaster-flow-council-2026-08-28.md:123-124` left open for command-guard); whether
approaches' fixed four-persona panel is a "consumer" of verification-panels' sizing
table; whether a consult brief is a "seat" under overseer's opus cap; and candor
clause 1 resolving basenames under `cwd` only.

What it found consistent, so the next audit can skip it: command-guard against every
command another artifact instructs (no deny; two asks on typed-confirm paths);
merge/PR authority across git-workflow, overseer, taskmaster; hands-off vs ask across
taskmaster, grill, overseer, approach-deliberation; comment discipline across the seven
worker agents and api-design; every `rules.tsv` and `lane.tsv` edge resolves; bundle
descriptions name only declared members; hook numeric constants match their docs.

---

## 8. Action list

Ranked by what a user hits first. Each names the plugin it improves and the gate that
protects the change. Waves are one PR each unless noted.

### Execution record — waves A and B, 2026-09-14

Both executed on branch `Ivan-WG/skipjack`. Where execution deviated from the plan
above, the deviation and its cause are recorded here rather than silently rewriting
the row.

- **A1 landed differently: `real-preview` went to `taskmaster`, not `ui-ux`.** The plan
  said ui-ux. On execution, `pc_plugin_corpus` failed: ui-ux's on-invoke prose measured
  159,517 B against a 160,000 B ratchet, so absorbing a 17 KB skill meant cutting 17 KB
  of skills people use to fund one measured at a single invocation — and the ui-ux fold
  that would free the room is wave D's, measure-first. It is now the real-component rung
  of `taskmaster:visual-decisions` (`references/real-components.md`, 9.7 KB after
  folding `variant-depth.md` into it and dropping `dataviz-cheatsheet.md`, which the
  host's bundled `dataviz` skill supersedes). `preview-cleanup.sh` and its harness moved
  with it. taskmaster now sits at 157,596 B — 2.4 KB of headroom — which is itself a
  finding: the next skill added to taskmaster forces a cut.
- **B8 narrowed from four review entries to two.** `/devops:review` and
  `/api-design:review` are the only two subjects of the router's stack-relevance harness
  (`scripts/smoke/prompt-route-tests.sh:345-353`); retiring them deletes the only test
  of that filter. §5 of the consolidation plan did not record that, which is why the
  endgame draft listed them for removal. `/testing:review` and `/craft-layer:review`
  were retired; `/api-design:review` gained the hand-up clause it lacked.
- **B3 shrank on measurement.** The plan named `execute_run_configuration`,
  `execute_tool` and `run_code_unsafe` for command-guard. Their shipped schemas (read
  2026-09-14) carry no command string — `execute_run_configuration` takes a
  configuration NAME — so adding them buys silent no-op coverage. Only the tools that
  carry content were wired: `create_new_file` (`pathInProject` + `text`) and
  `apply_patch` (`input`/`patch`) into secret-scanning, command-guard's allow-file
  guard, skill-router's routing and candor's clause-3 arming; `read_file` into
  overseer's evidence ledger. Each was driven with a real payload shape and verified.
- **B2 was a rank bug, not a documentation bug.** The README claimed an exemption;
  the fix was not to delete the claim but to correct the rank that made it false.
  `arcRank` encodes arc position, and taskmaster's `shape`-phase directive held 90 —
  last — behind `decide` (30) and `build` (40). Measured before: `build auth for the
  app` and `implement the payment endpoint` printed build-vs-buy and no clarify line.
  New order: debugging 10, consult-remind 20 (the two `any`-phase guards),
  taskmaster 25, approaches 30, api-design 40. `scripts/smoke/hook-guard-tests.sh`
  asserted the old order and was itself corrected — its comment claimed ranks meant
  "trigger specificity", which is how the inversion survived a month.
- **Two gates caught real defects the moment they were widened.** Adding `dev-env` and
  `design-studio` to `pc_removed_refs` failed the build on four unmarked changelog
  references; the staleness stamp grammar, widened to accept the bold form, made seven
  craft-layer digests visible for the first time (inventory 27 → 33 rows).

**Wave A — agreed, execute first.**

| # | action | plugin(s) | gate |
|---|---|---|---|
| A1 | Retire `design-studio`: move `real-preview` (skill, references, `preview-cleanup.sh` + harness) into `ui-ux`; route registries to shadcn's official MCP + ReUI hosted in the shadcn skill and stack-scan's "beyond" tier; `remove-plugin.sh design-studio --apply`; craft-suite 3 → 2; the `design-studio` mention in `stack-scan/.../official-complements.md:47` → ui-ux | ui-ux ↑minor, craft-suite ↑minor, stack-scan ↑patch, taskmaster ↑patch | validate, version-bumps, context-budget `--update-baseline` per touched key, generate `--check`, official-validate, ui-ux harness |

**Wave B — fixes with teeth, one PR, doc-only where marked.**

| # | action | plugin(s) |
|---|---|---|
| B1 | Fan-in: add `event-driven` and `inertia-best-practices` to the load list (§5.2) | code-review ↑patch |
| B2 | Lottery: decide exemption vs README rewrite (§5.1); update `skill-router/lane.tsv` yield either way | taskmaster, skill-router |
| B3 | Widen MCP matchers: `.*apply_patch\|.*create_new_file` on secret-scanning, candor clause-3 arming, skill-router route; the three PhpStorm execute tools + playwright `run_code_unsafe` on command-guard; state the residual in each README (§5.7) | secret-scanning, candor, skill-router, command-guard ↑patch each |
| B4 | `CC_REMIND` honoured by scan/density/verbosity/write-scan, or the README sentence deleted (§5.3) | code-review, security |
| B5 | Removed names out of listing bytes; `pc_removed_refs` gains `dev-env\|observability` (§5.5) | devops, security, stack-scan, ui-ux, craft-layer; `scripts/lib/plugin-checks.sh` |
| B6 | README inventories and stale counts (§5.4, doc-only); standing tables for secret-scanning and devops; "never touched" → "candidates listed; confirm step protects" in the suite uninstall template (§5.6) | five plugins, `templates/suite-uninstall.md.tmpl` |
| B7 | `check-doc-staleness.sh:92` accepts the bold stamp form; or un-bold the seven (§5.8) | craft-layer or the script |
| B8 | Swap debugging/consult-remind ranks (§5.12); retire `/testing:review`, `/devops:review`, `/craft-layer:review`; hand-up clause on `/api-design:review` (§5.13) | debugging, approaches, testing, devops, craft-layer, api-design |
| B9 | Router rows for the seven unrouted ui-ux skills and a11y on `*.blade.php\|*.svelte\|*.astro` (§5.11); licence-scan lockfile scope (§5.9); ORM DSLs in the database guard (§5.10) | skill-router, ui-ux, stack-scan, database |
| B10 | The §7 contradictions: C1 count, C2 re-tier, S1 description (always-on bytes), C3 regex, C6/C4 terse carve-outs, C5 clause, C7 recount, C8 doctrine exception, C9 word | code-architecture, ui-ux, skill-router, approaches, candor, git-workflow, root README, `.claude/skills/authoring-hooks` |

**Wave C — build. Each is a small deny/scan hook nothing in this tree or the top
collections carries; each names what the model gets wrong from memory. Opt-in where it
can refuse work. Every one lands with a harness under `scripts/__tests__/` and a
`Standing:` line.**

| # | mechanism | home | what the model does from memory |
|---|---|---|---|
| C1 | protect-tests: PreToolUse deny on deleting a test file or adding `.skip`/`@skip`/`markTestSkipped` to get green | testing | skips the flaky test and reports green |
| C2 | config-guard: PreToolUse deny on the agent editing `.claude/settings*.json`, any `hooks.json`, `plugin.json`, or a linter config to relax a rule | command-guard | loosens the gate it just hit |
| C3 | lockfile-drift: manifest edited and lockfile absent from `git diff --name-only` at Stop → candor clause 5 | candor + stack-scan | hand-edits `package.json` and forgets `npm install` |
| C4 | Stop-time diff review as an opt-in `type: agent` hook, the security-guidance pattern (§3) | security | ships the injection it wrote three edits ago |
| C5 | red-before-green ledger: PostToolUse on the test runner records `{file, pass\|fail}`; PreToolUse on `src/X` denies when a sibling test exists, its last run was green and no test changed since | testing | writes the implementation first when the change "is obvious" |
| C6 | subagent spawn cap: PreToolUse counter on `Agent\|Task`, ask at N | task-runner | fans out past what the plan sized |
| C7 | hidden-Unicode / zero-width scan of loaded instructions (`InstructionsLoaded`) | secret-scanning | cannot see the bytes |
| C8 | `Notification` hook on `permission_prompt\|idle_prompt` → desktop notify | candor | — (no model error; pure mechanism, and the event is unused here) |

### Execution record — wave C, 2026-09-14

**Five of eight shipped, each with a harness that drives it. Three declined on
measurement, and the reasons are the point.**

| # | outcome | evidence |
|---|---|---|
| C1 protect-tests | **shipped** — `testing` 0.10.0, PreToolUse deny on a skip/exclusive marker added with no same-line reason, and on a rewrite that empties a test file. 18 asserts | the reason requirement is what makes it survivable: an intentional skip has one, a fake-green skip does not |
| C2 config-guard | **shipped** — `command-guard` 0.6.1, PreToolUse `ask` on a write to settings, any `hooks.json`, a hook script, a plugin manifest, or a lint/type/test config. 21 asserts | `ask` not `deny`: editing these is often the task. Self-exempts inside a marketplace repo, which edits them as its product |
| C3 lockfile drift | **shipped** — `candor` 0.3.3 clause 5, Stop-tier block when a manifest's dependency map changed and its lockfile did not. 5 asserts inside the existing gate harness | the harness caught a real defect a hand test missed: package.json is often ONE line, so a line diff makes every `version` bump look like a dependency change. It now compares parsed dependency maps |
| C6 spawn cap | **shipped** — `task-runner` 0.35.0, PreToolUse `ask` at 20 dispatches then each doubling. 11 asserts | `turn-cost.sh` already states the fact — subagent turns are invisible and billed — and nothing counted them |
| C7 unicode scan | **shipped** — `secret-scanning` 0.6.0, PostToolUse warn naming codepoint and line; bidi overrides get their own Trojan Source message. 16 asserts | the one rule here whose subject is invisible by definition; a leading BOM is exempt, emoji ZWJ and Indic text are named as legitimate |
| C4 Stop-time diff review | **declined** | it needs a `type: "agent"` hook. The live hooks reference (read 2026-09-14) marks agent hooks **experimental and may change**, and documents neither the output schema that blocks nor which events accept them. A gate whose verdict format is unverified is a gate that may be a silent no-op — and unlike C1-C3 and C6-C7, no synthetic payload can drive it, so it would ship untested and tiered `gate` on faith. Queued behind the schema being documented |
| C5 red-before-green | **declined** | the deny condition cannot distinguish new behaviour from a refactor, a rename, or a typo fix. With a sibling test green, it fires on nearly every ordinary edit — a guard users turn off in a week, which is worse than no guard. `tdd-guard` solves this with an LLM judge, i.e. the same agent-hook mechanism C4 is blocked on. The ledger half (recording each runner invocation's result) is cheap and useful on its own; it is worth building only once something reads it |
| C8 desktop notification | **declined** | it carries no rule. The marketplace's bar is a mechanism that carries a rule the model gets wrong, and a notification is a preference the host's own settings already express. Shipping it would put a personal toggle in a marketplace that refuses checklists on the same grounds |

Two of the three declines share one cause: the mechanism that would make them honest
is `type: "agent"`, which the host ships as experimental and underdocumented. That is
worth recording as the single largest thing blocking new work here.

### Execution record — wave D, 2026-09-14

**The infrastructure was broken, and fixing it produced the first control-armed
numbers this repo has beyond the 2026-08-20 hand measurement.**

`claude plugin eval` shipped in 2.1.269 and defaults to `--ablation with-without`
whenever a plugin resolves. Running it exposed the thing that matters most here:

> **Two of the three shipped eval suites had never run.** `resilience` and `web-dev`
> used the `prompt.md` + `graders/*.md` shape that `CLAUDE.md` documented as
> functional. On CLI 2.1.270 the runner rejects it — `invalid case.yaml: graders:
> Required`, 0 cases loaded. Only `overseer`, which uses `case.yaml`, ever executed.
> Nothing runs any suite in CI, so nothing said so. Both were converted to `case.yaml`
> and `CLAUDE.md` corrected.

Then the measurements, all with a no-plugin control arm, haiku judge, 3 judge votes
per arm:

| suite | with | without | Δ | runs |
|---|---|---|---|---|
| `resilience` / timeout-and-retry | **0** (FAIL, 3 judges: F/F/F) | 1 (PASS, P/P/P) | **−1.00** | 3 independent runs, same direction every time |
| `web-dev` / caching-inversion | 1 (PASS, P/P/P) | 1 (PASS, P/P/P) | **0** | 1 |

**The resilience result is the finding.** Loading the plugin made the review
measurably WORSE on its own case: the base model names the double-charge hazard in a
retried payment POST; the plugin arm does not. The turn counts say where it goes — the
with-plugin arm spends 14-15 turns against the baseline's 3, and arrives somewhere
worse. The first run was against `max_turns: 8`, so the obvious explanation was a
ceiling the plugin's procedure could not fit in; raising it to 25 changed nothing (14
turns used, 3-0 FAIL), which rules that out.

What this does NOT license: deleting `resilience`. It is one case, one rubric, one
judge model. The honest reading is that on this prompt the skill's process displaces
the single argument the grader wants, and that is a hypothesis with a clean next
experiment (more cases; and a look at whether the fan-in's structure crowds out the
finding). It is recorded here rather than acted on because acting on n=1 case is the
reflex this repo's own `measured-zero-shapes.md` was written against. The `web-dev`
zero is the ordinary result and the expected one — the Next 15 caching inversion is
something the base model already knows.

**Wave D's remaining queue is blocked on cases that do not exist.** Its two headline
questions — `ultra-deep-research` against the host's `/deep-research`, and
`task-runner --tracks` against `/batch` — have no eval suites at all, and neither do
the seven plugins whose bodies the consolidation plan queued for ablation. Writing a
case for a body you intend to delete is backwards; the cheaper order is to write cases
where the answer would change what ships, starting with the resilience result above.

**Wave D — measure, then decide.** `claude plugin eval --ablation with-without`,
n ≥ 3, is unblocked as of 2.1.269. Queue, in order of the leaf it could retire:
`ultra-deep-research` vs `/deep-research`; `task-runner` tracks vs `/batch`; then the
consolidation plan's wave 4 (resilience, security, ui-ux per-library, approaches,
code-architecture, taskmaster, craft-layer motion bodies). A zero result folds the body
to a reference. **`overseer/kinds.tsv` pins `ui-ux:tailwind-best-practices` and
`craft-layer:interaction-fx`** — both wave-4 fold targets — so add it to the plan's
"what goes red" list before the first cut.

**Not doing, and why:** language/framework packs (shape 1, three reviews running);
re-declaring LSP/MCP plugins here (§2 — the scout's `official-complements.md` already prints their install commands by manifest signal; keep that table current instead); an `everything-suite` before it fits the 1M budget
(§4); converting skills to agents (a checklist read by a subagent is the same
checklist — the missing shape is agent-type *hooks*, wave C4).

---

## 9. Honest limitation

The usage evidence in §6 is one machine's transcripts. The hook measurements in §4 are
synthetic payloads: six hooks that wait for run state (task-runner drift/scope/consent,
taskmaster card-lint, candor clause 4, overseer) were not exercised and are not
counted. Cross-plugin hook order is undocumented and was not measured; the chassis
reminder hooks assume the host runs them concurrently. Wave C's "what the model does
from memory" column is the community scan's observation and this repo's own README
admissions, not a control-armed run — wave D is where any of it becomes a measurement,
and the runner is now shipped.

## 10. Recount before quoting

```bash
ls -d plugins/*/ | wc -l                                          # 31
ls plugins/*/skills/*/SKILL.md | wc -l                            # 104
ls plugins/*/commands/*.md | wc -l                                # 60
ls plugins/*/agents/*.md | wc -l                                  # 28
grep -l '"Stop"' plugins/*/hooks/hooks.json                       # candor only
bash scripts/context-budget.sh | grep -iE '^TOTAL|OVER|NEAR'      # 10474; four bundles OVER at 200k
python3 taskmaster-docs/endgame-2026-09-14/listing27.py | head -3 # 160 entries, 38,547 chars
grep -c inertia plugins/code-review/commands/review.md            # 0 until B1
grep -rn 'arcRank' plugins/taskmaster/.chassis.json               # 90 until B2
claude --version                                                  # 2.1.270 when this was written
```
