# code-review

Stack-agnostic code review: correctness bugs, code smells, and convention
drift on any diff, branch, or PR — severity-sorted one-line findings
(`path:line — severity — problem — fix`). Structure/YAGNI concerns are
deferred to code-architecture, security depth to security, and stack idioms
to the per-framework review plugins.

## Boundary with Claude Code's built-in `/code-review`

Claude Code ships its own `code-review` skill, and the names collide: `/code-review`
is the built-in, `/code-review:review` is this plugin. They are not substitutes.

The built-in is deeper on one diff — it carries effort levels from low to max, an
`ultra` multi-agent cloud pass, `--comment` to post inline PR comments, and `--fix`
to apply what it found. This plugin is wider across one repo: it is the **fan-in**
for every stack review installed beside it, loading the matching best-practice skill
per changed file type and reporting once in a severity scale eight other plugins
already speak, with a named owner for each overlapping concern so no finding is
raised twice. It also carries the `--debt` lane, which the built-in has no
equivalent for.

Reach for the built-in when the question is "how good is this one diff, and post
it to the PR". Reach for this one when the repo has stack plugins installed and you
want their review surfaces to arrive as one list rather than six.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install code-review@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/code-review:review [path, PR, or branch]` | Review a diff, branch, or path for correctness bugs, code smells, and convention drift — severity-sorted one-line findings |
| `/code-review:comment-review [path-or-diff]` | Audit comments — restatement of the next line, section banners, commented-out code, bare TODOs, docblock tags that repeat the signature, change-narration, missing why-comments on non-obvious choices — one line per finding |

## Example

```bash
/code-review:review src/Billing/
/code-review:review        # staged changes, else working tree vs default branch
```

Reviews state their coverage (`Checked:` / `Not checked:`) and close with a
one-line verdict — merge-ready, merge-after-blockers, or rework — with an
option to apply the fixes. The plugin also ships a `code-reviewer` agent
that reviews proactively after code is written, and two skills: `code-smells`
— the smell catalog, with when-it-is-NOT-a-smell judgment — and
`reuse-hygiene`, the pre-reuse check that a symbol you are about to build on
is not deprecated or orphaned, plus the deep pass (dead-code tool shellout,
export-aware orphan detection, deprecated-reference report) when a quick read
cannot settle it. The two split cleanly: `code-smells` catalogs dead code as a
**review finding**; `reuse-hygiene` is the check you run **before** reusing.

## Comment discipline (merged in on 2026-09-02) <!-- removed-ok -->

Over-commenting is an information-routing problem, not a comment-count problem. The
`comment-discipline` skill routes every fact to the artifact that cannot lie about it —
a name, a type, a test, an extracted function — and spends comments only on what has
nowhere else to live: why-not-the-obvious-way, external constraints with a link,
intentional-silence markers, and contract facts a signature cannot express.

**The write-time hook.** One detector inspects the text each `Edit` / `Write` /
`MultiEdit` adds, on two lanes. `PostToolUse` warns, at most one line, for any of the
six categories. `PreToolUse` denies just the two strictest — commented-out code and a
change-narration comment — once per file per session, then stands down. A second
warn-only hook (`density.sh`) flags a file whose comment-to-code ratio jumps, and a
third (`verbosity.sh`) applies the same rule to terminal prose. Ledgers and markers
live under `.claude/comment-discipline/`, unchanged from before the merge, so an
existing session's state carries over. Silence any advisory with `CC_REMIND=off`.

## Pairs well with

- **code-architecture** — the structural/YAGNI depth this review defers to, plus
  `drift-review`: whether the same diff stayed on the declared task intent
- **security** — deep security review beyond the correctness pass here
- **laravel** — per-stack idiom review for detail this plugin skips
