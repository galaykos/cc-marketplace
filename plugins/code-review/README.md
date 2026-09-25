# code-review

Stack-agnostic code review: correctness bugs, code smells, and convention
drift on any diff, branch, or PR — severity-sorted one-line findings
(`path:line — severity — problem — fix`). Structure/YAGNI concerns are
deferred to code-architecture, security depth to security, and stack idioms
to the per-framework review plugins.

## Boundary with Claude Code's built-in `/code-review`

Claude Code ships its own `code-review` skill, and the names collide: `/code-review`
is the built-in, `/code-review:review` is this plugin. They are not substitutes —
since 0.17.0 this command **wraps** the built-in: when the session has it, the
generic correctness/smell/convention pass is delegated to it (report-only, through
the Skill tool) and this command keeps the hunk read, the history pass, the stack
fan-in, the merge and the single `ReportFindings` emission; without it, the
generic pass runs inline as before.

The built-in is deeper on one diff — it carries effort levels from low to max, an
`ultra` multi-agent cloud pass, `--comment` to post inline PR comments, and `--fix`
to apply what it found. This plugin is wider across one repo: it is the **fan-in**
for every stack review installed beside it, loading the matching best-practice skill
per changed file type and reporting once in a severity scale eight other plugins
already speak, with a named owner for each overlapping concern so no finding is
raised twice. It also carries the `--debt` lane, which the built-in has no
equivalent for.

Reach for the built-in directly when you want `--fix`, `--comment`, or the `ultra`
cloud pass. Reach for this one when the repo has stack plugins installed and you
want their review surfaces, plus the built-in's generic pass, to arrive as one
list rather than one per plugin.

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
one-line verdict — merge-ready, merge-after-criticals, or rework — with an
option to apply the fixes. Since 0.17.0 the generic pass is delegated to Claude
Code's built-in `/code-review` skill when the session has it; this command is
the stack fan-in over it, and runs the generic pass itself only when the
built-in is absent. The plugin also ships a `code-reviewer` agent — the
dispatchable reviewer task-runner and the per-stack review commands
route to (a built-in skill cannot be dispatched as a subagent, which is why the
agent stays) — and two skills: `code-smells`
— the smell catalog, with when-it-is-NOT-a-smell judgment — and
`reuse-hygiene`, the pre-reuse check that a symbol you are about to build on
is not deprecated or orphaned, plus the deep pass (dead-code tool shellout,
export-aware orphan detection, deprecated-reference report) when a quick read
cannot settle it. The two split cleanly: `code-smells` catalogs dead code as a
**review finding**; `reuse-hygiene` is the check you run **before** reusing.

## Comment discipline (merged in on 2026-09-02) <!-- removed-ok -->

**The default is no comment.** The `comment-discipline` skill routes every fact to the
artifact that cannot lie about it — a name, a type, a test, an extracted function — and
spends a one-line comment only on what has nowhere else to live: why-not-the-obvious-way,
external constraints with a link, intentional-silence markers, and docblock facts a
signature cannot express (units, ownership, what throws). A docblock that repeats the
signature is deleted. Only a house style the project states in its `CLAUDE.md` overrides
the default; a heavily commented neighbour does not.

**The write-time hooks.** `scan.sh` inspects the text each `Edit` / `Write` /
`MultiEdit` adds, on two lanes. `PostToolUse` warns, at most one line, for any of the
seven categories. `PreToolUse` denies the three strictest — a comment restating the
next line, commented-out code, and a docblock tag repeating the signature — at most
twice per file per session, then stands down. `density.sh` denies a whole `Write` over
the comment ceiling (0.4:1 comment-to-code by default), at most twice per file, and after any edit
warns when a file is over min(2x its committed siblings' median, the ceiling); a file
with no committed siblings is judged against the ceiling alone. A project that specifies
a heavier style sets `COMMENT_DISCIPLINE_CEILING_TENTHS` in its settings `env` (10 for
1:1, 0 for the sibling test only) — a project whose own CLAUDE.md demands a docblock on
every method gets its first over-ceiling `Write` per file denied until it sets that
variable; the hook does not read CLAUDE.md. `verbosity.sh` applies the same rule to terminal
prose. Ledgers and markers live under `.claude/comment-discipline/` at the project root
(the git toplevel, else `CLAUDE_PROJECT_DIR`) — not in whatever directory the shell has
`cd`'d into, which scattered one state dir per directory until 0.23.0. Silence any
advisory with `CC_REMIND=off`; the denies are not advisories and do not honour it —
they have their own switch, `CC_COMMENT_GUARD=off`, set in the session's `env` and
named in every refusal so the person being blocked can read the remedy off the block.
Turning the deny off leaves the warnings on: the two lanes are switched separately.
Neither comment guard sees a file written through a Bash command (`cat > f <<EOF`,
`tee`, `sed -i`): the deny judges a write's text before it lands, and Bash carries that
text inside shell syntax. On a host that writes mostly through Bash, these two hooks are
largely absent — one measured session made 233 of its 238 main-thread writes that way.

A fourth hook ships outside the comment lane, and this README omitted it until 0.20.0:
`conventions.sh` fires `PostToolUse` on the first code write of a session and emits the
PATHS of the files that define this project's conventions (`.editorconfig`, formatter and
linter configs) plus the CI command that actually invokes them — locations, so the model
opens them, and deliberately never a digest of their contents. Once per context — keyed
on the transcript, so a subagent writing code gets its own copy rather than being deduped
against a nudge only its parent saw. Since 0.23.0 it also fires when a Bash command
writes an existing code file under the project root (a redirect, a heredoc, `tee`,
`sed -i`/`perl -i`; interpreter writes, `cp`/`mv` and a path held in a variable are not
parsed), and it reads the configs at the project root rather than the shell's cwd.
`CC_CONVENTIONS=off` silences just this one.

## Review-debt nudge

`review-debt.sh` speaks up when a session has written a lot of code, or security-relevant
code, and nobody has reviewed it. It was added after one measured session shipped about 40
items — a second auth guard, impersonation, API tokens — with zero reviews while its tests
stayed green, and a sibling session's reviewers caught bugs those tests had passed.

- **What.** One line of context for the model on your next prompt: how many files changed
  since the last review, up to three auth-surface paths, and the exact command,
  `/code-review:review <base>..HEAD`, "or say in one line why not". It never blocks and
  never runs a review itself.
- **When.** In a git repo, when the diff since this session's last review (or since its
  first prompt) has 8 or more changed files, or at least one path matching an auth-surface
  pattern (auth, login, password, token, secret, credential, policy, permission, role,
  guard, middleware, impersonation, session, oauth, webhook, payment, crypt, `migrations/`).
  Markdown, lockfiles, `.claude/`, `taskmaster-docs/` and vendor/build dirs don't count.
  Once per commit: it speaks again only after HEAD moves and the count has grown. A reviewer
  agent, a `code-review:review` / `security:review` call, or typing one of those commands
  resets the count. It stays silent during a task-runner run, which has its own reviewers,
  and the run's changes are not counted afterwards.
- **Limits.** It checks the diff once per new commit, so uncommitted work alone doesn't
  trigger it until the next commit. It recognises a review by its name, not by what the
  review covered.
- **Off switch.** `CC_REVIEW_NUDGE=off` silences this nudge; `CC_REMIND=off` silences it
  along with every other advisory.
- **Standing: advisory.** Nothing enforces the review. Whether a suggested review was worth
  running is agent-graded.

## Pairs well with

- **code-architecture** — the structural/YAGNI depth this review defers to, plus
  `drift-review`: whether the same diff stayed on the declared task intent
- **security** — deep security review beyond the correctness pass here
- **laravel** — per-stack idiom review for detail this plugin skips
