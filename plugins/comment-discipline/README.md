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

## Pairs well with

- **code-review** — the broader smell sweep; owns the one-bullet "comment as deodorant" version
- **api-docs-first** (docs-upkeep skill) — comment and doc *staleness*, where this plugin owns whether the comment should exist
- **code-architecture** — naming, extraction and file structure, the destinations a comment's content moves to
- **testing** — the artifact that should be carrying your edge-case comments
