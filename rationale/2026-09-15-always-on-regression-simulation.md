# Does installing all 31 plugins always-on degrade an ordinary task?

**Date:** 2026-09-15 · **CLI:** 2.1.272 · **Model:** claude-sonnet-5 · **Arms:** 3 × 3 sessions

The all-31-global audit argued from arithmetic and from static inspection. Neither can answer the
question a user actually has: *if I turn everything on, does my normal work get worse?* This is the
run that asked. It found one real defect — in the branch that was meant to fix such defects.

## Method

Three arms, one prompt, one fixture, hooks **enabled**:

| arm | plugins loaded |
|---|---|
| `none` | none — control |
| `master` | all 31, from marketplace `master` (`14e0448e`) |
| `branch` | all 31, from `Ivan-WG/alwayson` (`cfdbab61`) |

Every plugin is loaded with `--plugin-dir` from a frozen `git archive` snapshot. No marketplace is
registered, no global install is touched, user and project memory are disabled, MCP is empty and
strict. Hooks are deliberately *not* disabled — hook co-existence under a full install is the thing
under test, and the prior `skill-quality-simulation` run turned them off, so it could not have seen
any of this.

The task is a tic-tac-toe engine with a stated function contract (`new_board`, `apply_move`,
`winner`, `is_draw`, `available_moves`) plus a `unittest` suite. It is graded by an independent
20-check script that imports the submission in a fresh subprocess and knows nothing about which arm
produced it. The grader self-tests: a known-good implementation scores 1.00, a known-bad one with the
index validation removed scores 0.90 and names exactly the two checks it should fail, an empty
directory scores 0.00.

Harness: `../alwayson-regression/` (`run.py`, `grade.py`, `difffuzz.py`). **Not in this repo and not
a CI step** — it needs a live model and nine billed sessions, the same reason `scripts/smoke/canary.sh`
stays a local harness. Standing: `recorded`.

## Result: no functional degradation, a measurable tax

| arm | accepted | score | turns | tool calls | wall s | cost | skills listed | commands |
|---|---|---|---|---|---|---|---|---|
| none | 3/3 | 1.00 | 4.0 | 3.0 | 23.5 | $0.083 | 16 | 45 |
| master | 3/3 | 1.00 | 4.7 | 3.7 | 32.4 | $0.137 | 119 | 202 |
| branch | 3/3 | 1.00 | 4.7 | 3.7 | 31.5 | $0.140 | 119 | 202 |

Every session in every arm produced a fully correct engine, wrote tests, and was observed running
`python3 -m unittest` successfully *after* its last edit. Zero tool errors, zero timeouts, zero
blocking hook responses, zero denied commands in 9 sessions.

The tax is real and it is not in correctness. All 31 installed roughly **doubles cache reads**
(60k → 120k tokens/session) and costs about **+65% per session** ($0.083 → $0.138) on a task that
uses none of it. Four `SessionStart` hooks fire per session, identically in both plugin arms.

One asymmetry worth naming rather than burying: the model opened
`code-architecture/skills/low-cognitive-load/SKILL.md` in 2 of 3 `branch` runs and 0 of 3 `master`
runs, on a task with no architectural content. Three runs cannot separate that from a flake — this
repo withdrew a NEGATIVE delta that three runs agreed on — so it is recorded as an observation and
not as a finding. It is the shape the listing-eviction probe already flagged: what costs you is
adjacent skills competing, not bytes.

## What the simulation actually caught

The nine model sessions found nothing, because a tic-tac-toe build never touches a git verb. The
defect came from the deterministic companion: `difffuzz.py` runs one corpus of 73 PreToolUse payloads
through **both** versions of `plugins/git-workflow/hooks/no-ai-trailer.sh` and diffs the verdicts.

It found a **new ALLOW** — attribution that `master` blocked and the branch let through: a commit
whose message carries the `{T} …` trailer, invoked as
`git --git-dir=/repo/.git commit -m …`. Verdict on master: DENY. On the branch: allow.

Root cause, and it is worse than the one case. Between `git` and the write verb the guard only ever
allowed `-c` / `-C`. Every other git global option bypassed it on **both** versions:

| form | master | branch (pre-fix) |
|---|---|---|
| `git --git-dir=/repo/.git commit` | DENY | allow |
| `git --git-dir /repo/bare commit` | allow | allow |
| `git --work-tree=/tmp/wt commit` | allow | allow |
| `git --no-pager commit` | allow | allow |
| `git -P commit` | allow | allow |
| `git --namespace=ns commit` | allow | allow |
| `git --exec-path=… commit` | allow | allow |
| `git -c a=b --no-pager commit` | allow | allow |

`master`'s single DENY was **right for the wrong reason**: its loose `[^a-z0-9_-]` prefix matched the
literal `.git` inside the *path* `--git-dir=/repo/.git commit`, not the git command. That accident is
why the gap survived — the one form anybody tested passed. Tightening the prefix to a real command
position removed the accident and exposed the hole underneath it.

Fixed by widening the option run between `git` and the verb to accept a dash token, a path-like token
(the separated value of `--git-dir` / `--work-tree` / `-C`) and an assignment token (the value of
`-c`) — and deliberately **not** a bare word, so a piped read like
`git --no-pager log | grep <trailer>` stays allowed.

Standing: **gate**. The new fixtures live in
`plugins/git-workflow/scripts/__tests__/no-ai-trailer.test.sh`, which CI globs, and are verified
in both directions: **65 pass** against the fixed hook, **12 fail** against master, and **19 fail**
against the branch as it stood before either fix.

Then scaled up, because 73 hand-written cases is a weak instrument for a regex. A combinatorial
must-DENY corpus of **1,820** commands — 20 command-position prefixes × 13 option runs × 7 write
verbs, every one carrying the trailer — was run through both versions:

| | bypasses | rate |
|---|---|---|
| `master` | 1,260 | **69.2%** |
| this branch, fixed | 0 | **0.0%** |

`master`'s 1,260 are exactly the nine unhandled option runs × every prefix × every verb.

## The blind spot the fuzz had, and what found it

A corpus is only as good as its axes, and this one had three: wrapper prefix, option run, write verb.
It never varied **the command's own path** — so it could not see that `/usr/bin/git commit`,
`./bin/git commit`, `~/bin/git commit` and `/opt/homebrew/bin/gh pr create` were all denied on master
and **allowed** on the branch. An eight-dimension adversarial review found it by reading the anchor
rather than by fuzzing it: the command-position class `(^|[;&|`()]|\$\()` lists no `/`, and the old
loose prefix had been catching every path-qualified invocation by accident. Tightening the anchor
turned the guard off for the most obvious wrapper there is.

That is the useful lesson from this exercise, and it is not about git. **A generated corpus proves
only that the axes you thought of are covered.** Two instruments disagreeing is worth more than
either at ten times the sample size.

Fixed by allowing an optional path prefix inside both the `git` and `gh` atoms, required to end in
`/` so `/usr/share/digit commit` still does not match. The corpus then grew a paths axis and was
re-run: **7,938 must-deny commands** (14 prefixes × 7 paths × 11 option runs × 7 verbs, plus a `gh`
arm) — master bypasses **4,802 (60.5%)**, the fixed branch **0**.

The false-positive side was swept too: 44 must-ALLOW commands that carry the trailer text but write
no history (reads piped to `grep`, comments, redirects, `awk`/`jq` braces, `/usr/share/digit`,
`echo "run /usr/bin/git commit later"`). The fixed branch falsely denies **none**; master falsely
denies one, an echo its loose prefix could not tell from a command.

One residual is kept on purpose and pinned in both directions by fixture: `(` is a command delimiter,
so a `(` inside a quoted string restarts command position and
`echo "see (git commit -m '<trailer>')"` is denied. The tempting fix — dropping `"`/`'` from the
prefix tokens — was tested and is wrong twice over: it opens `bash -c "git commit …"`, `sh -c` and
`eval "…"` as bypasses, and it does not even clear the false positive, because the `(` matches with
or without a quote token. A commit whose prose quotes a full trailer verbatim is likewise denied on
both versions. Both are stated in the hook's header with the escape (`CLAUDE_AI_TRAILER=allow`)
rather than silently carried.

## Not established

- **One task, one model, three runs per arm.** This measures that a full install does not break a
  small self-contained build. It does not rank the arms and cannot: every arm scored 1.00, so there
  is no headroom — exactly the control-arm-passes problem `CLAUDE.md` names for the eval suites.
- **The task exercises almost none of the installed surface.** No git verb, no markup, no migration,
  no CI file — so 20 plugins' hooks had nothing to match. The hook-interference count of zero is a
  statement about *this* task, not about the install.
- **The hook ledger is incomplete.** The event stream emits `hook_started` / `hook_response` for
  `SessionStart` only; a canary plugin confirmed `UserPromptSubmit` output reaches the model with no
  corresponding stream event. "Zero interference" is therefore measured on tool-result content and on
  blocking responses, not on a complete record of every hook that ran.
- **The option-run fix is a regex, not a parser.** A separated value that is a bare word — for
  instance `--namespace ns` before the verb — is still allowed, because accepting bare words would
  deny `git status && echo commit`. That residual is stated here and in the hook's own header;
  closing it needs argument parsing, not a wider pattern.
- **The cost figures are the CLI's estimate** for one trivially small task, not a billing measurement
  and not a projection to real work.
