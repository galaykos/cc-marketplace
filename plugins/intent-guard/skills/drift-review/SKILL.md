---
name: drift-review
description: Use when work under a declared task is about to be called done — review the whole session diff against the declared intent for drift and cut corners before you finish. Triggers on done, finished, wrap-up, drift, stray, scope creep, or cut corners during active execution.
---

# Drift review

You are working under `intent-guard`. A declared task **X** exists for this session
(`intent.json`), a UserPromptSubmit reminder primes this review each turn, and a passive Stop
summary reports what the turn touched. This skill is the done-review those signals point at:
before you call the work done, review the whole session diff against X for **drift** (a strayed
or cheaper Y instead of the asked X) and **cut corners**.

This is **cooperative integrity, not a wall**. You own the state files and the diff — you *can*
skip this. Do not. The value is that drift and corner-cutting get seen and fixed *before* "done",
while it is still cheap. Keep it honest.

## When this fires

Run this review whenever you are about to declare work done under a declared intent — a "done",
"finished", "that completes it", or a hand-back to the user or the dispatching agent. It is a
review-at-done, not a per-edit check: one pass over the accumulated diff, not a row per Edit.

## 0 — Establish a usable X first

State dir: `$cwd/.claude/intent-guard/` holds `intent.json` (session X + criteria), `base`
(session-base commit sha), and `turn.log` (plain lines of targets this turn touched).

Read `intent.json`. If it is **absent, stale, or vacuous** (broad wording, empty `criteria`),
establish a concrete intent before reviewing — a criteria-less X makes every change trivially
"serve" it:

1. If a taskmaster card is in play, read the active `00-INDEX.md` (the
   `taskmaster-docs/tasks/*/00-INDEX.md` referenced this session, else the most recent) and derive
   `criteria` from the current card's acceptance criteria.
2. Else ask the user for the one-line task and its success criteria.
3. Else state the working criteria explicitly in your reply, then record them.

Write the established intent with the **Write** tool:
`{"session_id":"<sid>","intent":"<X>","source":"card|prompt|cmd","criteria":["…"]}`.
Do **not** invent a criterion to fit a stray, and do **not** rewrite X to make a stray fit —
redirecting X is the user's call via `/intent-guard:intent`.

## 1 — Determine the diff

Review the **whole session's** change, not just the working tree:

- **Git repo:** `git diff <base>` where `<base>` is the sha in `.claude/intent-guard/base`
  (HEAD captured at session start). Diffing against the session base still sees work already
  committed mid-session — a plain working-tree `git diff` would miss it. If `base` is empty use
  the merge-base against the upstream branch.
- **Non-git repo (or no `base`):** fall back to the touched-target list in `turn.log` and your
  session notes, and re-read those files to reconstruct what changed.

## 2 — Choose the review path

Independence breaks the self-grading loop, but it is **best-effort, not guaranteed**:

- **Independent path — top-level session only.** Dispatch a read-only reviewer **subagent** given
  `(intent X + its criteria, the diff)`. It maps each hunk to a criterion it serves, or flags the
  hunk `DRIFT` / `CORNER-CUT`. The reviewer authored none of the change, so it grades without the
  bias of the author.
- **Self-review fallback — inside a subagent, headless, or no budget.** A subagent **cannot
  dispatch another subagent**, and delegated execution (the taskmaster-worker path) is the common
  case here. When you are already running as a subagent, or headless, or without budget for a
  second agent, you review the same diff against the same checklist **yourself**. State this
  plainly in your findings: *"self-review — no independent reviewer available in this context."*
  Never present a self-review as independent; overstating independence is its own corner cut.

## 3 — The corner-cutting checklist

Whichever path, apply this checklist to every hunk. Flag it when the change:

- **(a)** weakened or **deleted an assertion / test** to make something pass — that is gaming, not
  progress;
- **(b)** silently **skipped a success criterion** of X (declared work left undone);
- **(c)** substituted a **cheaper, off-task approach** not cleared with the user;
- **(d)** left a **stub / `TODO` / `pass` / `NotImplemented` / placeholder** where real work was
  asked;
- **(e)** **silently narrowed scope** — quietly did less than X and called it done.

And flag drift when a hunk touches a file or concern **no criterion mentions** ("while I'm here"),
or would surprise the user reading the diff against X.

## 4 — On a finding, fix it — don't paper over

For each `DRIFT` / `CORNER-CUT` the review surfaces:

- **Fix it** — revert the stray change, restore the weakened test, finish the skipped criterion,
  replace the stub with real work; **or**
- **Ask** — if it is a genuine judgment call, surface it to the user and let them decide. Do not
  quietly accept it and do not rationalize it into a "serves".

Never redirect X on your own initiative to make a stray retroactively fit — that is the exact
cheat this guards against. **`/intent-guard:intent` is the only way to redirect X**, and it is the
user's call; a model-authored intent change *is* drift. If you believe X should change, say so and
let them decide.

## 5 — Output: a findings list, nothing more

Report a **short findings list** — for each finding: the hunk, the flag (`DRIFT` / `CORNER-CUT`),
and its resolution (fixed / reverted / asked). If the diff is clean against X, say so in one line.

There is **no state file written for the review, no per-hunk record on disk, and no cumulative
ledger** — this review is a reasoning pass whose output is the findings you surface, not a JSON
artifact. The only file you ever write is `intent.json` (X + criteria), and only to establish it
or, via the command, to redirect it.

## 6 — Compose, don't duplicate

intent-guard owns only the **mid-run intent↔action** layer — did the work stay true to the
declared X. Defer the neighbouring seams:

- **Entry** — correspondence of cards ↔ spec → `taskmaster:coverage-check`.
- **Exit** — evidence ↔ claim before "done" → `code-architecture:work-verification`.
- **File-membership** — was this file in scope → `task-runner` `scope.sh`. intent-guard judges
  *intent*, not which file: a stray can stay in-scope and still be drift.

Keep it lean: one honest pass over the diff against X, caught while you can still fix it — not
ceremony.
