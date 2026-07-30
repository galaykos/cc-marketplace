---
name: terse-commit
description: Use when writing a commit message — "write a commit", "commit this", "commit message", staging changes for a commit, or /terse:commit. Conventional Commits, imperative subject under 50 characters, body only when the why is not obvious from the diff. Full sentences, never compressed prose — the message is a repo artifact, not a chat reply.
---

## The message is not a chat reply

Everything else in this plugin compresses what the user reads. A commit message
is read by `git log` five years from now by someone who does not have this
conversation. Write it in normal English, complete sentences in the body, and
spend words where the diff cannot speak.

Terse here means **no noise**, not fewer facts.

## Subject

    <type>(<scope>): <imperative summary>

- Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, `build`, `ci`, `style`, `revert`
- Imperative mood — "add", "fix", "remove"; never "added", "adds", "adding"
- Aim for 50 characters, hard cap 72. No trailing period
- Scope optional; when present it names the area, not the filename
- Match the repo's existing capitalization after the colon — read `git log -20 --oneline` first

## Body

Skip it entirely when the subject already says everything. Add one only for:

- the non-obvious **why** — the constraint, the bug report, the measurement
- breaking changes: a `BREAKING CHANGE:` paragraph, and `!` after the type
- migration steps a reader must perform
- issue references at the end: `Closes #42`, `Refs #17`

Wrap at 72 columns. Bullets use `-`.

## Never

- "This commit does X", "I", "we", "now", "currently" — the diff states what changed
- Restating the filename when the scope already names the area
- "As requested by …" — that is a `Co-authored-by:` trailer
- AI attribution or tool advertising of any kind
- Emoji, unless the repo's own history uses them
- A body that paraphrases the subject in longer words

## Examples

Bad — subject carries body-shaped detail, no why anywhere:

    feat: add a new endpoint to get user profile information from the database

Good:

    feat(api): add GET /users/:id/profile

    The mobile client needs profile data without the full user payload
    to cut cold-launch bandwidth on LTE.

    Closes #128

Breaking change:

    feat(api)!: rename /v1/orders to /v1/checkout

    BREAKING CHANGE: clients on /v1/orders must migrate to /v1/checkout
    before 2026-06-01. The old route returns 410 after that date.

## Before writing

Read the actual diff (`git diff --cached`, or `git diff` when nothing is staged)
and the last 20 subjects. A message written from the conversation instead of the
diff describes the intent, which is often not what the patch does.

Standing: **unenforceable** — no gate in this marketplace lints commit subjects.
The repo's own hooks may; check `.git/hooks` and any `commitlint` config before
assuming this skill's format wins over a project convention.
