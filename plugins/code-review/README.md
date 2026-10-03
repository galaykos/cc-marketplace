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
`MultiEdit` adds, and the text a Bash heredoc writes, on two lanes. `PostToolUse` warns,
at most one line, for any of the six categories. `PreToolUse` denies the three
strictest — a comment restating the next line, commented-out code, and a docblock tag
repeating the signature — at most twice per file per session, then stands down.
`density.sh` denies a whole `Write`, or a Bash heredoc that replaces a file, over
the comment ceiling, at most twice per file, and after any edit warns when a file is over
min(2x its committed siblings' median, the ceiling); a file with no committed siblings is
judged against the ceiling alone. The ceiling is **0.3 prose comment lines per code line**
by default, compared exactly: 30 prose lines over 100 code lines pass, 31 are refused. A
file under 50 lines, or with fewer than 8 code lines, is judged by the **short rule**
instead: it is over the limit with at least 5 prose lines, a code line, and more prose
than code, and the message reads "the ceiling is 1.0:1"; a file with no code line is never
over. The sibling test keeps its 0.3 floor, equal to the default ceiling, so siblings
decide only where a project raised the ceiling. The counter knows each judged language's
comment syntax: a Python docstring, `<!-- -->`, Blade `{{-- --}}`, JSX `{/* */}` and the
bare lines of a `/* */` block are comments; Rust `#[derive]`, C `#include`, PHP
`#[Attribute]` and a JS `#private` field are code. A comment line is **not prose** when it
is a delimiter alone (`/**`, `*/`, `"""`) or has no letter or digit (`// -----`); a tool
directive (`eslint-disable`, `@ts-expect-error`, `# noqa`, `# shellcheck`, Go's `go:build`,
`pragma`, a region marker); a doc tag whose operand is a type (`@param int $x`,
`@return Foo<Bar>`, `@param {string} id`, `@throws RuntimeException`) or a tag with no text
of its own; a `:type:` / `:rtype:` line or a bare `Args:` / `Returns:` heading; a line of
the file's first comment block when that block names a copyright, an SPDX identifier or a
licence; or a `|`-led line inside a `/* */` block (a Laravel config stub). Dockerfiles and
Makefiles are judged by `scan.sh` only: a comment per instruction is idiomatic there.

A project that specifies a heavier style sets `COMMENT_DISCIPLINE_CEILING_TENTHS` in its
settings `env`: **5 for a project that documents every public API** (PEP 257 docstrings,
Javadoc — at 0.3 a third or more of the Python, Ruby and Java standard-library files of 50
lines or more are refused), 4 for the 0.25.0 ceiling, 10 for 1:1, and 0 to switch the
ceiling and the short rule off and keep only the sibling test. Setting 4 restores the
number only: the file types judged since 0.26.0 (shell, SQL, CSS, SCSS, Less, Lua, Elixir,
Perl, Julia, R, Groovy, Terraform, GraphQL), the short rule, the exact compare and the
prose-only count stay. A project whose own CLAUDE.md demands a docblock on every method
gets its first over-ceiling `Write` per file denied until it sets that variable; the hook
does not read CLAUDE.md. `CC_COMMENT_GUARD=off` (below) switches the denies off and leaves
the warnings on. `verbosity.sh` applies the same rule to terminal
prose. Markers live in the plugin's data directory,
`${CLAUDE_PLUGIN_DATA}/<project-key>/comment-discipline/`, when the host provides one, else
under `.claude/comment-discipline/` at the project root; the ledgers are
`$HOME/.claude/comment-discipline/*-ledger.jsonl`. The project root is the git toplevel,
else `CLAUDE_PROJECT_DIR` — not whatever directory the shell has
`cd`'d into, which scattered one state dir per directory until 0.23.0. Silence any
advisory with `CC_REMIND=off`; the denies are not advisories and do not honour it —
they have their own switch, `CC_COMMENT_GUARD=off`, set in the session's `env` and
named in every refusal so the person being blocked can read the remedy off the block.
Turning the deny off leaves the warnings on: the two lanes are switched separately.

**Writes through Bash (since 0.25.0).** Both hooks also run on `Bash` — one measured
session made 233 of its 238 main-thread writes that way. A heredoc that `cat` or `tee`
carries to a file (`cat > f <<EOF`, `cat >> f <<EOF`, `tee f <<EOF`, `cat <<EOF | tee f`,
also behind `sudo`, and for `cat` behind a `VAR=value`) is judged as a `Write` of its
body to that file: the same detectors, the same message followed by ` Written by a Bash
command: <file>.`, and the same two denies per file per hook — a `Write` and a heredoc
to one file share them. A relative target is resolved against the shell's working directory
and `~/x` against `$HOME`. `scan.sh` judges an append like any other added text. `density.sh`
denies only a heredoc that replaces the file (`>`, `tee` without `-a`), because an
append is a fragment with no ratio of its own; after the command it measures the first
three targets that exist on disk, whatever wrote them (`sed -i`, `echo >`, a generator),
and prints the first warning. The cap counts any existing file, whatever its extension,
so three log redirects ahead of a source file leave it unmeasured. A command with several heredocs draws one verdict, for the
first file that trips; the retry reaches the next.

**Which files are judged.** `node_modules/`, `vendor/`, `dist/`, `.git/` and `.claude/`
are exempt at any depth (a git worktree under `.claude/worktrees/<name>/` is judged as
the checkout it is). `build/` is exempt only at the project root: `build/app.js` is
skipped, `packages/build/index.ts` is judged. `migrations/` is judged everywhere.
`scripts/*.sh`, `templates/` and `plugins/*/hooks/` are exempt only inside a
plugin-marketplace repository — a project root holding `.claude-plugin/marketplace.json`
— so in every other project a deploy script, a template component and a WordPress
plugin's hook file are judged (a shell script by both hooks since 0.26.0). Until 0.25.0
those three, `migrations/` and a `build/` at any depth were skipped in every project. Text that declares itself generated is exempt from both
denies and from the after-Bash measurement: one of the first five lines written (of the
file on disk, for that measurement) holds `@generated` or `<auto-generated`, or
begins, after the comment leader and in any letter case, with `Code generated`,
`Generated by`, `Generated from`, `Generated code`, `Auto-generated`, `Autogenerated`,
`Automatically generated`, `This file was generated` (also `is`, `code`, and the three
auto forms), `Do not edit` or `Do not modify`. A line that only mentions a generator
(`// This is not generated by a tool`) no longer exempts the file.

**What the comment counter cannot tell apart.** `density.sh` reads lines, not a parse
tree, and a line it is unsure of counts as code: a missed comment is preferred to a false
refusal.

- **Every language:** a trailing comment after code, and a block opened mid-line
  (`x = 1; /* why`), count as code; an unclosed `/*` inside a string turns the code after
  it into comment up to the next `*/`; a directive the list does not know counts as prose
  (`sourceMappingURL`, `svelte-ignore`, `deno-lint-ignore`); a line over 20,000 bytes is one
  code line and a form-feed-only line is code; NUL bytes give counts that differ between
  awk builds; an upper-case extension (`.SQL`, `.R`) or a build file named `Dockerfile-dev`
  or `makefile` is judged by neither hook.
- **Comment-looking lines inside strings** count as comments: JS template literals and JSX
  text nodes beginning `//` or `*`; PHP heredocs and multi-line strings; multi-line strings
  in shell, Rust, C# and Lua, and a single-quoted program passed to `awk`; Ruby regex
  literals and `%{}` bodies; a `\`-continued C or Python string; a Go cgo preamble.
- **Python:** a triple-quoted string that is not a docstring (assigned, or after the first
  statement) is code, and so is a docstring in single quotes or on the `def` line.
- **Go, Kotlin, Java, Swift, Scala, Dart, Groovy:** an odd number of backquotes (Go) or of
  `"""` on one line toggles string mode, which can only turn comments into code.
- **PHP:** everything before the first `<?php` and after a `?>` is code.
- **Ruby, Perl, Terraform, shell:** a `<<` with no space after it (`class <<self`,
  `1<<BITS`) opens a heredoc that never closes, so the rest of the file is code; only the
  first four heredocs on one shell line are tracked.
- **Doc tags:** an untyped tag with a description (Javadoc, KDoc, TSDoc
  `@param name text`) counts as prose; a description that starts with a capital
  (`@returns The sum`) reads as a type and does not.
- **The licence block** is the file's first run of comment lines, exempt as a whole: a
  licence header followed directly by a docstring exempts both, and a licence block that
  is not the first comment block counts as prose.
- **Three ways to dodge the counter**, each the cost of an exemption above: a `|` at the
  start of any line inside a `/* */` block, whatever it says; a first comment block that merely contains the
  word licence; a line that merely contains a directive word (`eslint-`, `coverage:`).
- **Refused by design:** a short single-purpose file (an enum, a constants file, an
  exception) under a why-docblock, by the short rule; compiled CSS that keeps its source
  partials' section headers and carries no generated marker.
- **Siblings:** a sibling over 256 kB is left out of the median; eight hook runs at once in
  one session can each print "Warning 1 of 3".
- Go and Rust are proven on test fixtures only. Python, Ruby, Java, C and shell were also
  checked line by line against reference tokenizers and scanners on standard-library and
  system code; the CHANGELOG's 0.26.0 entry has the numbers.

**What a Bash write still escapes.** The hooks read the command's text; they never run
it. A miss is preferred to judging the wrong file, so an uncertain shape is skipped.

- **Never read as file content:** interpreter writes (python `open()`, php
  `file_put_contents`); a heredoc fed to anything but `cat` or `tee`
  (`python3 - <<PY > f`); `echo` and `printf` content; `sed -i` and `perl -i` content;
  `cp`, `mv`, `install`; a `{ …; } > f` group; a here-string (`<<<`); a quoted string or
  `\` continuation spanning lines; a second heredoc opened on one line. `density.sh`
  still measures the resulting file afterwards when the command names it as a redirect,
  `tee` or `sed -i` / `perl -i` target.
- **Target not resolved, so the heredoc is skipped:** a path held in a variable; a
  globbed operand; `2>` and `&>` targets; the second operand of `tee a b`;
  `VAR=value tee f <<EOF`; `cat` or `tee` behind a path, wrapper, brace or keyword
  (`/bin/cat`, `command cat`, `env X=1 cat`, `(cat`, `{ cat`, `then cat` on one line,
  `sudo -E tee`); a `cat` stage with a file operand or an option (`cat a > f <<EOF`,
  `cat -n > f <<EOF`); a heredoc piped on to a stage that is not `tee`; process
  substitution (`cat > >(filter > f)`); a quote glued onto the target (`f.js'.bak'`),
  a target holding a backslash, or one led by `~user`; a target whose `..` steps out of
  a symlinked directory; a relative target whenever the command holds a `cd`, `chdir`,
  `pushd` or `popd` word outside quoted strings and heredoc bodies (inside quotes too
  when the command holds `eval`, `sh -c` or `bash -c`; inside a heredoc body too when a
  `<<` sits inside a quoted string, after a backslash or inside `$((`) — an absolute
  target is still judged.
- **Skipped by `density.sh`'s deny only:** an append; a heredoc whose target the same
  command writes again (the after-command measurement covers it); heredocs past the 40th
  to a judged file in one command.
- **Skipped by `density.sh`'s after-command warning:** targets past the first three
  that exist on disk, whatever their extension.
- **Too large:** a command over 32 kB that holds a line over 8 kB, or whose lines over
  2,000 characters sum past 32 kB, is not judged by either hook.
- **Read wrongly — text judged that the shell would not write there:** a heredoc in a
  function never called, or behind `false &&`, is judged as if it ran; a quoted command
  word (`"cd" dist`) or a `cd` inside a multi-line string run by `zsh -c` is not seen,
  so a relative target is judged against the session directory; a quoted `"~/x"` is
  read as `$HOME/x`; a heredoc body line that is the delimiter with leading spaces ends
  the body early and the rest is read as commands; a body line beginning with an RS
  byte (0x1E) opens a false chunk; a `> f` inside a shell comment makes `density.sh`
  measure a file the command did not touch.
- **Budget:** the two denies are keyed on the path, not the file, so one file reached
  through a symlink keeps a second budget, and so does a `Write` whose path holds `..`
  (a Bash target has its `..` collapsed, a `Write` path does not); a deny that co-fires
  with another plugin's deny on the same call spends a try on a write that never
  happened; a hand-typed generated marker exempts a file from both denies.

Standing: the denies are a **gate** on the shapes named above — the hook refuses the
write. This list is **recorded**: nothing judges what is on it at write time, and
`/code-review:comment-review` is the pass that reads the files whatever wrote them
(**agent-graded**).

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
