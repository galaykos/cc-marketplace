# comment-discipline

Over-commenting is an information-routing problem, not a comment-count problem.
Every fact goes to the artifact that cannot lie about it — a name, a type, a test,
an extracted function — and comments are spent only on what has nowhere else to
live: why-not-the-obvious-way, external constraints with a link, intentional-silence
markers, and contract facts a signature cannot express.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install comment-discipline@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/comment-discipline:review [path-or-diff]` | Audit comments — restatement of the next line, section banners, commented-out code, bare TODOs, docblock tags that repeat the signature, and missing why-comments on non-obvious choices — one line per finding |

## Example

```bash
/comment-discipline:review src/billing/
/comment-discipline:review          # reviews the current diff
```

The review applies the bundled `comment-discipline` skill's routing table — which
facts belong in names, types and tests, and which genuinely earn a comment — and
reports findings sorted by severity with a concrete fix each.

## The write-time hook

A `PostToolUse` hook inspects the text each `Edit` / `Write` / `MultiEdit` adds and
prints at most one warning when it matches a high-confidence pattern: a comment
restating the next line, a section banner, commented-out code, a bare `TODO`, or a
docblock tag that repeats the signature. It is warn-only and fail-open — it never
blocks an edit, and any error exits silently. Silence is the common case.

## The output hook

The same routing rule applies to the terminal: prose that restates what a tool call
already showed is a comment on the session. A second `PostToolUse` hook measures
this session's assistant-text characters per tool call and prints **one** warning
when the ratio is an outlier.

The threshold is 600 characters per tool call, calibrated over 1,933 local session
transcripts with 8 or more tool calls. Main-thread sessions measured p50 155, p95
389, max 910 — so 600 fired on 3 of 135 (2.2%), all above p95. Subagent transcripts
are exempt: their final text *is* their return value, and they measured p95 634
against the main thread's 389.

| | |
|---|---|
| Standing | **advisory** — `additionalContext`, not a blocking key |
| Fires | at most once per session, after a tool call |
| Exempt | subagent transcripts, sessions under 8 tool calls, transcripts under 60 lines |
| Cannot tell | prose the user asked for from unrequested narration — which is why it warns rather than blocks |

Stop-event delivery was considered and rejected: a `Stop` hook reaches the model
only by blocking, and spending a turn to complain about output volume emits more
prose than it saves.

## Pairs well with

- **code-review** — the broader smell sweep; owns the one-bullet "comment as deodorant" version
- **api-docs-first** (docs-upkeep skill) — comment and doc *staleness*, where this plugin owns whether the comment should exist
- **code-architecture** — naming, extraction and file structure, the destinations a comment's content moves to
- **testing** — the artifact that should be carrying your edge-case comments
