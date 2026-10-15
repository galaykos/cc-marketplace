# Session retro 2026-10-13: how the plugins behaved in real work, and what to change

**Scope.** 13 days (2026-10-01 → 10-13) of Claude Code sessions in five other repos, four of
them Laravel + Inertia apps that also run Laravel Boost: 30 main threads and ~280 subagent
transcripts, ~400 MB. This repo's own sessions and `/tmp` probe dirs are excluded. Six Opus
miners split the corpus by project; one Opus verifier re-opened every cited window, replayed
defects against HEAD `fa529a89`, and patched temp copies of the hooks to check the cheap fixes.
~125 miner findings → 58 verified entries: 54 open, 2 fixed since, 1 host, 1 refuted.

Raw evidence (verbatim quotes, transcript line numbers, session key) stays in the gitignored
`taskmaster-docs/session-retro-2026-10-13/` (`verified.md`, `raw/*.md`). This file paraphrases;
`V-NN` ids point into `verified.md`.

**Standing of this document: `recorded`.** Nothing reads it back. Each change below names the
standing it would have once shipped.

## What the sessions say, in five sentences

1. Our skills mostly do not reach the work: post-edit "load X" nudges were followed 0–19% of
   the time in main threads, while a skill PATH injected when a subagent starts was read ~92%.
2. Where they were asked for, bare names resolved to Laravel Boost's same-named project skills
   instead of ours: in the biggest run, workers read Boost's copies 94 times and
   `laravel:laravel-best-practices` 0 times.
3. Reviews are the plugins' clearest value — per-card reviewers, spec-redteam and
   `/code-review:review` caught real blockers in every large session — but reviewers were told
   to run git with no shell, and the whole-branch pass that catches cross-card bugs was skipped
   or ran after the merge.
4. A handful of syntactic hooks misread neighbouring syntax (Tailwind `truncate` as SQL, vendor
   paths as fabricated citations, paste ids as names) and their `ask`s stalled unattended runs
   for 15–67 minutes at a time; every ask-ledger block observed was a false positive (0 of 5).
5. Two pipeline mechanisms were unearnable or silently off: the behavioral gate cannot pass a
   large Pest repo, and the taskmaster → task-runner skill handoff never registers the run, so
   three gates go dark together.

## How it should work (the principles behind the list)

- **Deliver rules before the work, not after.** A path or a quoted rule in the dispatch is
  read; an imperative after the edit is not. Spend on SubagentStart injection, card stamps and
  inline rule quotes; spend less on PostToolUse nudges.
- **Name things unambiguously.** Every skill reference a plugin prints is `plugin:skill`.
  Bare names are a lookup the host resolves in someone else's favour.
- **A gate's false-positive rate is its price.** Every pattern hook ships with a "neighbouring
  syntax must stay silent" fixture. A gate with no observed true positive re-earns its slot by
  measurement after its fix (ask-ledger, below).
- **Never `ask` where nobody is watching.** In background workers and auto mode, a narrower
  trigger or a `systemMessage` beats a permission prompt that idles a run.
- **Never instruct an agent to do what its tools cannot.** Give a read-only reviewer the diff
  as a file; give the creative director its seed; skip browser-proof text for agents without
  a browser.
- **Pipeline state is registered by a script, not by prose.** One step that a prose route can
  skip should not be able to switch off three gates.

## Tier 0 — cheap and certain (one-liners or near, repro in hand)

Each needs a version bump, a harness case, and a CHANGELOG entry where the plugin has one.
✓ = the verifier applied it to a temp copy, re-ran the session payload, and the plugin's
harness passed.

| # | Plugin | Change | Ref |
|---|---|---|---|
| 1 | database | TRUNCATE rule case-sensitive or `truncate table` only — Tailwind's `truncate` stops asking ✓ | V-09 |
| 2 | candor | citation gate: keep the leading `/`, exclude `.localhost/.test/.local` hosts, bounded `node_modules`/`vendor` lookup before "missing"; block text demands a COMPLETE re-send ✓ (87/87) | V-01 |
| 3 | ask-ledger | strip `<pasted_content>` blocks and in-word apostrophes before extraction ✓ (23/23); block text: restate the verdict first | V-06, V-07 |
| 4 | task-runner | behavioral-gate: `find … -print -quit` (SIGPIPE under pipefail) and strip ANSI before counting Pest totals ✓ (harness not run: needs `node`) | V-22 |
| 5 | task-runner | rv-consent: long `--reason` and `${H:0:12}` ids display correctly ✓ | V-28 |
| 6 | testing | test-shape: Pest `test()->` helper is not a test opener ✓ (samples only) | V-41 |
| 7 | taskmaster | handoff invokes `task-runner:run <index>`, not the task-execution skill, so the run registers | V-19 |
| 8 | taskmaster | task-cards example stamps `laravel:laravel-best-practices` | V-18 |
| 9 | task-runner | scope file schema stated in routing.md; scope.sh rejects a file with no `allow` array; ignore paths outside the root | V-26 |
| 10 | skill-router | Signals: skip hand-backs / task-notifications / system prompts before the flush; skip `.md/.css/taskmaster-docs` in content rows | V-13 |
| 11 | web-dev | web-developer carries `inertia-best-practices` | V-48 |
| 12 | security | write-scan skips `/tmp` and out-of-root targets | V-51 |
| 13 | brain | "no map" hint only on `source == startup` | V-56 |
| 14 | code-review | review.md states ReportFindings `short_summary` ≤ 60 chars | V-40 |
| 15 | design-kit | `dk.sh decision --record` strips a leading date | V-46 |

**Applied 2026-10-14**, all 15, one patch bump per plugin; every row has a harness case that
fails against the previous version except #7, #8 and #14 (prose, no harness reads them).
Where the shipped fix departs from the row:

- #1 also requires a name after `table`, so Tailwind's `truncate table-cell` stays silent.
- #3 cuts paste SPANS, not lines (the line-based cut deleted the ask written beside the tag),
  and masks in-word apostrophes only during quote extraction (a global join minted `Laravels`).
- #9 also tells task-executor not to write its own scope file; the index-dir exemption is
  left as a stated residual.
- #11 adds the skill only; web-developer's description would cost 9 always-on tokens over
  its baseline, so it is unchanged.
- #12 skips the temp dir only when the project itself does not live there (the literal rule
  silenced projects cloned into `/tmp`).

Found while applying, not fixed: `/task-runner:plan`'s "Run now" has the same unregistered
handoff as #7 (Tier 1 §3 closes both); candor's `/candor:check` scanner still carries the
old citation lookup #2 replaced; rv-consent's redirect detector misses a skip file named
with a shell expansion; task-runner's skills prose sits ~16 bytes under its size cap, so
Tier 1 text there must trim first.

## Tier 1 — the changes that move results

**Wave 1 applied 2026-10-14: §1, §2 and the first bullet of §3.** Departures from the text
below:

- §1 V-15: at SubagentStart the dispatch prompt is not on disk yet (probed on CLI 2.1.299),
  so subagent-skills also runs on PreToolUse(Agent|Task) to record what the dispatch names.
  Surface skills now also include package-hygiene, docker and CI, which otherwise took the
  first slot of every generic injection.
- §1 V-14: the cheap half only. Quoting a rule inline and measuring compliance from the
  ledger are still open.
- §2 V-25: a commit after a range review owes a review of only the commits since it,
  because re-reviewing the whole run on every fix commit costs a full pass each time.
  run.md now renames `active-run.json` to `closed-run.json` rather than deleting it. Before
  this, a run that followed run.md lost its sentinel before the closing stop, so clause 4
  never ran on a correct close.
- §2 V-39: on a branch change, review-debt moves its base to where the switch landed, not
  to HEAD, so a `switch -c` plus commits in one turn still counts.

Found while applying, not fixed:
- testing's protect-tests reads a `pending '<x>'` string as a skip marker (fixed in wave 2).
- stamp-lint's reachability probe needs `CLAUDE_PLUGIN_ROOT`, which a by-path run likely
  lacks.
- git-workflow's marketplace description does not mention the merge-checks hook, because
  adding it would cost always-on tokens.

**Wave 2 applied 2026-10-15: the rest of §3, §4, §6 (except the ask-ledger re-measure),
§7's scope question, and Tier 2 V-02, V-04, V-44 and the ship-verb half of V-20.** A
whole-range review of the wave (four readers plus the host's pass) found 47 issues, three
high: a custom runner that ran nothing graded covered, a quoted `<<WORD` hiding destructive
lines from command-guard, and the isolated test tree reaching the live `.env`. All were fixed
or stated before the commit. Departures from the text below:

- §3 V-23: `--runner-for` output must pass the language's own "tests ran" check. The isolated
  tree moved into the repo so container shims see it. It gets an empty `.env` so a loader
  walking up cannot reach the live one. Composer projects still load live classes through the
  linked `vendor`, and the gate's warning says so.
- §3 V-27: a run sentinel counts only on the branch it was registered on.
- §4 V-29: the suite lock lives in the git common dir, so worktree tracks share it. Without
  `flock` (stock macOS) a worker runs unlocked and says so. The two-worker cap is planning
  prose with no mechanism.
- §6 V-35: there is no shared heredoc block yet. command-guard has a quote-aware local scanner
  that keeps any body it cannot place. Consolidation moves to §5.
- §6 V-10: the rollback cut covers Laravel and Doctrine, Rails and Alembic, per MultiEdit edit.
  Knex, TypeORM and Sequelize rollbacks are not cut, so they still ask.
- §6 prompt-shape: adopted by skill-router, ask-ledger, code-review's review-debt and
  taskmaster's reminder; every classifier miss errs toward speaking but one stated ship-noun class
  (`rationale/derivations/templates-and-blocks.md`). candor's preamble and the
  other reminder hooks have not adopted it.
- §6 lint: `pc_agent_tool_fit` follows only the `references/` files an agent names, and reads a
  relative-clause subject ("a handler that writes") as description.
- §7: install and uninstall both ask for the scope. The SessionStart line and `*-lsp`
  surfacing are not done.
- V-04: candor counts a behavioral gate as in flight through a PID file task-runner writes,
  capped at 240 minutes. Under the sandbox's PID namespace the check can miss.
- V-02: candor's preamble skips this marketplace's read-only agents by qualified name.
- V-20: the auth-surface trivial-escape half is still open.

Found while applying, not fixed:
- `--runner-for java` can pass on a build-success line alone; a pytest wrapper run with `-qq`
  reads unverifiable.
- skill-router misses an error named with no state verb and not opening a sentence.
- A Pest `->skip()` on the line after the closure is not matched (the named helpers are, since
  the range review).
- A heredoc fed to a shell function, alias or `coproc` is not read by command-guard.
- The craft concept deck's worked example is not gated against an axis gaining an option.
- An overseer dispatch file written before the new preamble clause fails `dispatch check`
  if it is checked again; files already gated keep their recorded checksum.
- A `/loop` wakeup prompt is still read as a work prompt by the reminders.

**Wave 3 applied 2026-10-15: §5.** Two byte-locked blocks instead of one:
`templates/blocks/heredoc-bodies.md` is command-guard's quote-aware scanner, now used by the five
hooks that each had their own copy and by unicode-scan, and `templates/blocks/bash-write-effects.md` lists the files a
Bash command changed (`git status` filtered to paths newer than the hook's previous call). All
eight PostToolUse hooks that carry the write blocks adopt it. The four PreToolUse-only guards
cannot judge a write that has not happened and name the miss. A whole-range review of
6c8b00be..HEAD (wave 2 after its fixes, plus wave 3; four readers and the host's pass) found 36
issues, four high, all fixed or stated before the commit. Departures from §5's text:

- No literal `open(…,'w')` fast path: the effect read covers interpreter writes after the fact,
  and nothing parses an interpreter body before it runs, so Pre lanes stay blind.
- The pre-filter runs `git status` only for an interpreter, `cp`, `mv`, `install` or `patch`
  command. Measured on a 2,786-file repo: about +1.5 ms per hook for any other Bash call, about
  +5 ms more for a matching call that writes nothing.
- The marker belongs to one hook, one repo and one session, so a new session's first matching
  call reads nothing rather than the user's edits since the last session. A Bash call that exits
  non-zero is read through `PostToolUseFailure`.
- A file found this way is reported as changed since the previous tool call, never as this
  command's write: the scope lock never tells a worker to revert it.

Found while applying, not fixed:
- A writer the pre-filter does not name (`make`, `git apply`, a formatter), gitignored outputs,
  `mv`/`cp -p` destinations, submodules, a repo with no git and a `run_in_background` command's
  writes are not read; anything else that changed a file between two calls is read as changed.
- The cap of 8 counts files before each hook's own filters.
- The spawn cap asks instead of notifying when a tag shares the run branch's name.

### 1. Skills that actually reach the work (skill-router, taskmaster, laravel, testing, task-runner)

- Print `plugin:skill` in prime.sh, route.sh and the subagent text. At SessionStart, when the
  repo ships a same-named `.claude/skills/<name>`, print one line naming the collision and what
  ours adds (V-12). Smoke harnesses assert these strings — update them in the same change.
- skills-stamp-lint warns on a bare stamp shadowed by a project skill and maps known twins
  (`inertia-react-development` → `laravel:inertia-best-practices`, `tailwindcss-development` →
  `ui-ux:tailwind-best-practices`) (V-18).
- Extend SubagentStart injection to `general-purpose`/`claude` dispatches that name repo source
  paths; gate vite/sql injection on the dispatch's files (V-15). It is the one channel that works.
- Inline execution reads a card's `<skill>` files before its first edit (V-30).
- Cut nudge noise: skip `taskmaster-docs/`, `.claude/`, gitignored and out-of-root targets, and
  skills already loaded; at most 2 per edit; where content matches a known trap, quote the rule
  row instead of "load X" (V-14). Then measure compliance from the router ledger before adding rows.
- Standing: gate for name format and exclusions; agent-graded for whether the model loads.

### 2. Reviews that see the diff and the whole branch (task-runner, code-review, git-workflow, security)

- **Diff delivery contract** in reviewer-routing.md, code-review's dispatch and drift-review:
  the orchestrator writes `rv/diff-<card>.patch` (plus blame for modified hunks), names it in
  the prompt, and never tells a Read/Grep/Glob agent to run git (V-24). This is also the cost
  lever: reviewers without a diff re-read whole files at 1.4–16M cache-read tokens each.
- **Keep per-card review** — it found blockers on about half the cards, including upgrade cards
  no security/data tag would select. **Add one required whole-range `/code-review:review`** at
  run close over `start_sha..HEAD`, recorded for candor's completion clause; per-card passes
  never substitute, and a skip is a named `Skipped:` line in finish (V-25). Measured: ~22M
  tokens for one range pass against ~87M for 22 per-card passes. Docs-only and test-only cards
  get one reviewer at `effort: high`.
- review-debt evaluates the working tree on ship verbs (commit / PR / merge / push), before the
  merge, and resets its base on branch switch (V-39).
- git-workflow PreToolUse on `gh pr merge`: pending or failing checks → ask, fail-open (V-42).
- Security gate dispatches `security:security-engineer` in a review-only contract instead of
  asking code-reviewer to "also do security"; a read-only agent could not have run the probes
  that found the SSRF and XSS bypasses (V-31). rv-observe records reviewer type so UI cards
  without a ui-ux-reviewer record fail clause 4 (V-33).

### 3. Pipeline integrity (task-runner, taskmaster)

- `task-runner/scripts/register-run.sh`, called by both `/task-runner:run` and the skill's step 1,
  writes `active-run.json` with `start_sha` (V-19, V-34).
- behavioral-gate: `--runner-for <lang>` replaces that language's built-in runner; document and
  raise the 60 s default; create `--isolate` worktrees inside the repo so container shims see
  them (V-23).
- spawn-cap derives its threshold from the registered plan and notifies instead of asking
  inside a run (V-27).

### 4. Test resource safety (task-runner, testing, taskmaster)

A card asked to prove a 100,000-row cap; the worker seeded 100,001 rows, the query ran away to
36 GB, and the machine crashed twice while six workers ran suites in parallel. Add to the
worker discipline preamble: wall-clock timeout and memory cap on every test command, applied
where the process runs (inside the container for a shim); one full suite at a time across
workers (`flock`); at most 2 concurrent verify-running workers by default. Add to
testing-best-practices and task-cards: prove a limit by lowering it, never by exceeding a
production-sized constant (V-29). Standing: agent-graded; the lock becomes a gate if the
preamble wraps verify commands in a script.

### 5. Hooks that see Bash writes (shared hook-bash-writes block, 12 hooks)

40–85% of code writes in four sessions went through `python3 - <<EOF` heredocs, invisible to
every per-file hook — including the auth refusal that leaked account state (V-52). Add
effect-based detection: compare `git status --porcelain` plus mtimes against a per-session
snapshot and feed newly changed tracked paths to the same per-file logic, with a fast path for
literal `open(…,'w')` targets (V-53). **Measure latency on a large repo before shipping** —
it is 12 hooks × one `git status`. Use the `hook-bash-writes` project skill.

### 6. False-positive discipline as a habit, not a sweep

- Fix the remaining misreads: command-guard skips heredoc bodies (22.6 s on a 21 KB command,
  past its 15 s timeout, so it fails open) (V-35); database judges only `up()` in migrations
  (V-10); code-review's comment scan needs a code token inside docblocks (V-37) and density
  ignores typed tags and comment-free edits (V-38).
- A shared, byte-locked `templates/blocks/prompt-shape.md`: skip harness prompts, strip pastes,
  recognise ship-only and question prompts — for skill-router, taskmaster's reminder, candor's
  preamble and ask-ledger (V-16, V-20, cross-cutting 7).
- Record in the authoring-hooks project skill: every new pattern ships with a neighbour-syntax
  silent fixture; prefer `systemMessage` over `ask` where the session may be unattended.
- A cheap lint (passes the theater test — nothing else catches it): an agent body or dispatch
  template that names `git`, hashing or Write when the agent's `tools:` lacks Bash/Write
  (V-24, V-44, V-02).
- **ask-ledger re-earns its slot.** After fix #3, re-measure on fresh sessions; zero true
  positives in a second window means retire or narrow it.

### 7. Onboarding (all-plugins)

The user installed only `all-plugins`, believed the marketplace was active, and ran days of
sessions with zero leaves; `/all-plugins:install` then defaulted to local scope per project.
Ask for scope once when `--scope` is absent; optionally a SessionStart line when all-plugins
is the only plugin from this marketplace that is enabled; surface the official complements
(`*-lsp`) that plugin-scout already maps (V-49, H4).

## Tier 2 — polish (each one session, low)

candor preamble skips read-only agents (V-02), skips PR/commit bodies (V-03), honours a stated
user test plan (V-05), counts an in-flight behavioral-gate as in flight (V-04); database `/tmp`
skip (V-11); router tool-fit regex (V-16) and routing gaps (V-17); taskmaster reminder ship-verb
exemption (V-20) and pipeline polish (V-21); routing by stack for `api` cards (V-32); severity
vocabulary, env-notes, drift.sh (V-34); `.playwright-mcp` scratch (V-36); `/code-review:review`
checklist (V-40); craft-layer seed passed in by the caller (V-44) and marketing voice (V-45);
design-kit on Inertia + Tailwind v4 (V-46); ui-ux-engineer overflow checks (V-47);
secret-scanning scan script (V-54) and BOM (V-55); low-value early steps (V-57).

## Keep — what worked (do not break it while fixing the above)

Per-card reviewers; `/code-review:review` with the built-in pass and self-refute; spec-redteam
(the best single step where it ran); coverage-check, grill, the blind panel and drift-review
(cheap, changed artifacts); task-runner's worker return contract and negative controls; the
resume hook and compaction capsule after a reboot; candor's completion gate (it stopped
premature yields); SubagentStart path injection; creative-direction + design-kit boards (a
direction accepted, merged and reused); secret-scanning redaction; command-guard's
proportionate asks; coding-task's triage of an upgrade into the pipeline.

## Rejected

- **Trim per-card review to security/data cards** — refuted: the blockers came from upgrade
  cards no such tag selects.
- **A new read-only security-reviewer agent** — fails Admission; the catches needed probes.
- **Renaming our skills to dodge Boost** — qualified names fix it without breaking references.
- **External audit hypotheses** (third-party checklist, 2026-10-13): an LLM-judged `prompt`
  Stop hook for ask-ledger (the false positives are syntactic and a one-line patch removes them;
  a model call per turn is not justified); a cheaper model tier for reviewers (the catches were
  multi-file traces, no control arm, and the cost driver is the missing diff); a failed-approaches
  log (no dead end repeated across a compaction in four sessions); bundling LSP/MCP (thirteen
  official `*-lsp` plugins exist and plugin-scout already routes to them). The same audit's
  300-line skill cap, blanket Definition-of-Done sections, `set -euo pipefail` in hooks and
  one-question-at-a-time grilling are weaker than, or contradict, what this repo already gates.

## Residuals

- Recurrence counts are bounded by 13 days and five repos; single-session findings may not
  generalise.
- Compliance numbers are main-thread heuristics from four independent miners that agree; they
  are not a controlled measurement.
- The retro's own P0 classifier counted Boost loads as ours; fix it before the next retro.
- #4 and #6 were unharnessed at verification; both now pass their harnesses (#4 with `node`
  from nvm, since this shell has none on PATH).
