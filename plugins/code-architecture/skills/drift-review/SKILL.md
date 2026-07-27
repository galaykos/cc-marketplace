---
name: drift-review
description: Use when work under a declared task is about to be called done — done, finished, wrap-up, scope creep, cut corners, drift: reviews the whole diff against what was asked, hunting strayed substitutes, weakened tests, skipped criteria, left-in stubs while cheap to fix.
---

# Drift review

Before you call work done, review the whole diff for this unit of work against **X** — what
was actually asked — for **drift** (a strayed or cheaper Y shipped instead of the asked X)
and for **cut corners**.

This is **cooperative integrity, not a wall**. You own the diff and you own this review —
you *can* skip it. Do not. The value is that drift and corner-cutting get seen and fixed
*before* "done", while fixing them still costs one edit instead of a re-litigation. It is
not tamper-proof and it is not a security boundary; it raises the visibility of casual
drift, not an adversary's.

## When this fires

Run this whenever you are about to declare work done — a "done", "finished", "that
completes it", or a hand-back to the user or the dispatching agent. It is a
review-at-done, not a per-edit check: **one pass over the accumulated diff**, not a row
per Edit.

## 0 — Establish a usable X first

X is read from the invoking context, in this order. Nothing is persisted; this skill
writes no state file.

1. **An active task card** — the card currently in progress, or the
   `taskmaster-docs/tasks/*/00-INDEX.md` referenced this session. Its acceptance criteria
   ARE the criteria; use them verbatim.
2. **The user's stated task** — the request this work descends from, plus whatever success
   criteria they named.
3. **Neither available** — ask for the one-line task and its criteria, or state the working
   criteria explicitly in your reply before reviewing against them.

A criteria-less X is unusable: every change trivially "serves" a broad enough goal, so a
review against one proves nothing. If X is vacuous, sharpen it before reviewing, and say
you did.

**Do not invent a criterion to fit a stray, and do not restate X to make a stray fit.**
Redirecting X is the user's call, not yours — a model-authored change to what the task
was *is* the drift this review exists to catch.

## 1 — Determine the diff

Review the **whole unit of work**, not just the uncommitted working tree — otherwise
anything already committed mid-session escapes the review entirely.

- **Git repo:** diff against the point this work branched from.
  `git merge-base HEAD <default-branch>` gives the base; `git diff <base>` gives the
  change, including commits made along the way. When the work sits on the default branch
  itself, or the merge-base resolves to HEAD, fall back to `git diff HEAD` plus
  `git diff --cached` for the working state.
- **Non-git target:** reconstruct from the files this unit of work touched — the card's
  declared file list, your session notes — and re-read them.

## 2 — Choose the review path

Independence breaks the self-grading loop, but it is **best-effort, not guaranteed**:

- **Independent path — top-level session only.** Dispatch a read-only reviewer subagent
  given `(X + its criteria, the diff)`. It maps each hunk to a criterion it serves, or
  flags the hunk `DRIFT` / `CORNER-CUT`. It authored none of the change, so it grades
  without the author's bias.
- **Self-review fallback — inside a subagent, headless, no budget, or where subagent
  dispatch is unavailable.** A subagent cannot dispatch another subagent, and delegated
  execution is the common case here. Then you review the same diff against the same
  checklist yourself, and **say so plainly**: *"self-review — no independent reviewer
  available in this context."* Never present a self-review as independent; overstating
  independence is itself a corner cut.

## 3 — The corner-cutting checklist

Whichever path, apply this to every hunk. Flag it when the change:

- **(a)** weakened or **deleted an assertion / test** to make something pass — gaming, not
  progress;
- **(b)** silently **skipped a success criterion** of X — declared work left undone;
- **(c)** substituted a **cheaper, off-task approach** not cleared with the user;
- **(d)** left a **stub / `TODO` / `pass` / `NotImplemented` / placeholder** where real
  work was asked;
- **(e)** **silently narrowed scope** — quietly did less than X and called it done.

And flag **drift** when a hunk touches a file or concern **no criterion mentions**
("while I'm here"), or would surprise the user reading the diff against X. A stray can sit
entirely inside the declared file set and still be drift: this judges *intent*, not file
membership.

## 4 — On a finding, fix it — don't paper over

For each `DRIFT` / `CORNER-CUT`:

- **Fix it** — revert the stray, restore the weakened test, finish the skipped criterion,
  replace the stub with real work; **or**
- **Ask** — when it is a genuine judgment call, surface it and let the user decide.

Do not quietly accept a finding, and do not rationalize it into a "serves". If you believe
X itself should change, say so and let them decide.

## 5 — Output: a findings list, nothing more

Report a **short findings list** — per finding: the hunk, the flag
(`DRIFT` / `CORNER-CUT`), and its resolution (fixed / reverted / asked). A clean diff
against X is one line saying so.

No state file, no per-hunk record on disk, no cumulative ledger. This is a reasoning pass
whose output is the findings you surface.

## 6 — Compose, don't duplicate

This skill owns only the **mid-run intent↔action** layer — did the work stay true to X.
Defer the neighbouring seams:

- **Entry** — cards ↔ spec correspondence → `taskmaster:coverage-check`.
- **Exit** — evidence ↔ claim before "done" → `work-verification`, in this plugin.
- **File-membership** — was this file in scope → `task-runner`'s scope lock.

Keep it lean: one honest pass over the diff against X, caught while you can still fix
it — not ceremony.
