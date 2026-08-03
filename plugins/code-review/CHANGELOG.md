# Changelog — code-review

Consumer-facing changes only. A version bump with nothing here is a number; this
file is what makes an upgrade readable. Newest first.

## 0.10.7 — 2026-08-03

### Fixed
- **`/code-review:review` now hands `task-executor` the stack skills the review was
  judged against.** The executor has no `Skill` tool *and* declares no
  `bestpractices-skill:` frontmatter, and a fix list is not a task card — so unlike a
  stack worker it had nothing to resolve from any source, and applied findings from
  recalled convention. The apply lane now injects one `Read <abs-path>` per skill this
  review actually loaded, so the applier and the reviewer work to the same rubric.
- **`code-reviewer` declares its own rubric** (`code-smells`, `reuse-hygiene`), so the
  task-runner reviewer pass can prime it. Previously it carried no `bestpractices-skill:`
  line at all, which left nothing for any dispatch site to resolve.

## 0.10.0 — 2026-08-02

### Added
- **`hooks/conventions.sh`** — a PostToolUse hook that fires once per session, on
  the first code write, naming the PATHS of the files defining this project's
  conventions (`.editorconfig`, formatter, linter, pre-commit) plus the CI command
  that enforces them. It emits locations, never a summary of their contents: a
  distilled checklist injected before the model reads the source measurably
  narrows the review. Silence it with `CC_CONVENTIONS=off`, or `CC_REMIND=off` for
  every advisory nudge in this marketplace.
- **`scripts/debt-scan.sh`** and a `--debt` lane on `/code-review:review` — five
  language-agnostic debt categories (suppressions, skipped tests, bare markers,
  deprecated-symbol references, feature flags) counted against a committed
  `.claude/debt-baseline.json`. `--check` exits 2 when any category GREW;
  `--update-baseline` accepts growth deliberately. `--age` resolves first-seen
  dates by git pickaxe, which turns "340 TODOs" into "11 older than two years".

### Changed
- `/code-review:review`'s apply pick now names a dispatch target
  (`task-runner:task-executor if installed → inline`). It was the flagship
  fan-in command and the only one whose apply pick named nothing, so findings
  died in chat while 31 chassis siblings routed theirs.
- `code-smells` now states its boundary with Claude Code's built-in `simplify`
  skill, which covers overlapping ground and applies fixes. Use the host skill for
  a quick cleanup pass; use this one when the question is which smell, and whether
  it is a smell at all.

### Notes
- The debt scanner counts OCCURRENCES, not severity. It answers "is this getting
  worse", never "is this bad".
