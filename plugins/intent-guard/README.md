# intent-guard

A **lean, warn-only drift + corner-cutting guard**. It anchors one declared task **X** per
session, primes you once each turn to review your diff before you call the work done, and drives a
`drift-review` at that "done" moment — one honest pass over the whole session diff against X, with
a corner-cutting checklist. Everything it emits is advisory: no hook ever holds a turn.

## Install

```
/plugin marketplace add galaykos/cc-marketplace
/plugin install intent-guard@cc-plugins-marketplace
```

## Commands

| Command | Does |
|---------|------|
| `/intent-guard:intent <task>` | Set or override the declared intent **X** (with criteria) for this session. The **only** legitimate way to redirect X; the change is recorded in `history`. |
| `/intent-guard:status` | Show X, its criteria, this-turn touched targets, the session-base commit sha, and the last done-review verdict. |

## How it works

Intent is captured once per session and lives in `.claude/intent-guard/intent.json` (X + criteria).
A session-base commit sha is recorded at the first prompt in `.claude/intent-guard/base`, and the
targets touched this turn are appended to an ephemeral `turn.log` that resets every turn. There is
no cumulative record and no state written for the review itself.

Three warn-only hooks plus one skill:

- **`capture.sh` (UserPromptSubmit)** records the declared intent for the session, captures the
  session-base sha once, and rotates state on a new session. Once per turn — **only when** an intent
  exists **and** the prior turn touched files — it injects a single line: intent X + "before you
  declare this done, review your diff for drift / corner-cutting (run the `drift-review` skill)."
  One lean reminder, not a per-prompt or per-action stream.
- **`note.sh` (PostToolUse on `Edit|Write|MultiEdit|NotebookEdit|Bash|Agent`)** appends each
  state-mutating action's touched target to `turn.log` — one plain line, no counting, no nudge.
  Read-only recon and the guard's own state writes are skipped.
- **`summary.sh` (Stop)** emits one passive, user-facing line — "this turn touched N target(s) vs
  intent X" — then truncates `turn.log` so the next turn starts clean. It is a summary, not a gate:
  it never holds the turn and emits no decision field of any kind.
- **the `drift-review` skill** is the done-review those signals point at. When you are about to call
  the work done, it diffs the **whole session** against the session base — `git diff <base>`, so
  work already committed mid-session is still seen (a non-git repo falls back to the `turn.log`
  touched list) — and reviews every hunk against X for **drift** (a strayed or cheaper Y) and
  **cut corners** (weakened/deleted tests, a skipped criterion, an off-task substitution, a left-in
  stub/`TODO`, silently narrowed scope). At the **top-level session** it dispatches a read-only
  reviewer **subagent** so the check is independent; **inside a subagent, headless, or no budget**
  it is honest self-review of the same diff and says so. Output is a short findings list — no file
  written, no per-hunk record.

## Honest limits

`intent-guard` is **cooperative — not tamper-proof and not a security boundary**. The agent it
watches has shell access and owns the state files and the diff, so a determined adversary can defeat
it, as it can defeat every in-band guard in this marketplace. What it does well is the case that
actually bites: a cooperating model that *strays* because Y was cheaper, or quietly cuts a corner.
It makes that visible and fixable *before* "done" while it is still cheap. Independence is
**best-effort, not guaranteed**: the independent reviewer subagent is available only at the
top-level session. In delegated execution — the taskmaster-worker path, where a subagent cannot
dispatch another subagent — the check is **self-review**, and the skill states that plainly rather
than overstate independence.

## Composition seams

`intent-guard` owns only the **mid-run intent↔action** layer — did the work stay true to the
declared X. It defers the neighbouring seams instead of duplicating them:

- **Entry** — correspondence of cards ↔ spec → **taskmaster** `coverage-check`.
- **Exit** — evidence ↔ claim before "done" → **code-architecture** `work-verification`.
- **File-membership** — was this file in scope → **task-runner** `scope.sh`. intent-guard judges
  *intent*, not which file: a stray can stay in-scope and still be drift.

## Pairs well with

- **task-runner** — scope-lock + file-membership tripwire (intent-guard judges *intent*, not files).
- **taskmaster** — coverage-check binds cards to the spec at entry.
- **code-architecture** — work-verification demands evidence at exit.
