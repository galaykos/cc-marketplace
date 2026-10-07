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
the Skill tool) and this command keeps the hunk read, the history pass, the comment
pass, the stack fan-in, the merge and the single `ReportFindings` emission; without it, the
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
agent stays) — and, besides `comment-discipline`, two review skills: `code-smells`
— the smell catalog, with when-it-is-NOT-a-smell judgment — and
`reuse-hygiene`, the pre-reuse check that a symbol you are about to build on
is not deprecated or orphaned, plus the deep pass (dead-code tool shellout,
export-aware orphan detection, deprecated-reference report) when a quick read
cannot settle it. The two split cleanly: `code-smells` catalogs dead code as a
**review finding**; `reuse-hygiene` is the check you run **before** reusing.
Both the command and the agent run a **comment pass** over the comments a diff adds,
judged against `comment-discipline`'s keep-cases and kill-cases and reported at `low`;
the agent, which loads no skill, carries the list inline. Both skip the pass on a path
with no diff, except that the command judges every comment in scope on a hand-up from
`/code-review:comment-review`. Standing: agent-graded.

Credit: the "Reinvented shelf" smell, the `shortcut: <the limit>; revisit when <trigger>` comment form and the debt lane's `shortcuts` count adapt rules from [dietrichgebert/ponytail](https://github.com/dietrichgebert/ponytail) v4.10.0 (MIT), rewritten here rather than copied.
The "Mysterious name" smell, the decision-record test and required call order in `comment-discipline`, and a repo's contributing or coding-standards doc as a convention source (the review's convention pass, `conventions.sh`'s `standards:` line) adapt rules from [mattpocock/skills](https://github.com/mattpocock/skills) v1.2.3 (MIT, © 2026 Matt Pocock), rewritten here rather than copied; their effect on what the model writes is unmeasured.
The elision deny in `scan.sh` is adapted from [leonxlnx/taste-skill](https://github.com/leonxlnx/taste-skill)'s output-skill (commit ce26fc25, MIT, © 2026 Leonxlnx), rewritten here rather than copied; its effect on what the model writes is unmeasured.

## Comment discipline (merged in on 2026-09-02) <!-- removed-ok -->

**The default is no comment.** The `comment-discipline` skill routes every fact to the
artifact that cannot lie about it — a name, a type, a test, an extracted function — and
spends a one-line comment only on what has nowhere else to live: why-not-the-obvious-way,
external constraints with a link, intentional-silence markers, and docblock facts a
signature cannot express (units, ownership, what throws, required call order). A docblock that repeats the
signature is deleted. Only a house style the project states in its `CLAUDE.md` overrides
the default; a heavily commented neighbour does not.

**The write-time hooks.** `scan.sh` inspects the text each `Edit` / `Write` /
`MultiEdit` adds, and the text a Bash heredoc writes, on two lanes. `PostToolUse` warns,
at most one line, for any of the twelve categories listed below. `PreToolUse` denies the three
strictest — a comment restating the next line, commented-out code, and a docblock tag
repeating the signature — at most twice per file per session, then stands down. Since
0.30.0 it also denies a write that removes existing code and adds a placeholder comment
(`// ... existing code ...`), on its own two-deny budget and its own switch,
`CC_ELISION_GUARD`; it reads markup comments too, misses placeholder wording outside its
grammar, does not compare a `Write` against a file over 1 MiB, and after two denies lets
the write through with only a warning, so code can still be lost — **The elision deny**
below has what it reads and the rest it misses.
`density.sh` denies a whole `Write`, or a Bash heredoc that replaces a file, over
the comment ceiling, at most twice per file, and after any edit warns when a file is over
min(2x its committed siblings' median, the ceiling); a file with no committed siblings is
judged against the ceiling alone. The ceiling is **0.3 prose comment lines per code line**
by default, compared exactly: 30 prose lines over 100 code lines pass, 31 are refused. A
file under 50 non-blank lines, or with fewer than 8 code lines, is judged by the **short rule**
instead: it is over the limit with at least 5 prose lines, a code line, and more prose
than code (or than the ceiling, once a project raises it past 1:1), and the refusal reads
"the ceiling is 1.0:1"; a file with no code line is never over. The sibling test keeps its 0.3 floor, equal to the default ceiling, so siblings
decide only where a project raised the ceiling. The counter knows each judged language's
comment syntax: a Python docstring, `<!-- -->`, Blade `{{-- --}}`, JSX `{/* */}` and the
bare lines of a `/* */` block are comments; Rust `#[derive]`, C `#include`, PHP
`#[Attribute]` and a JS `#private` field are code. A comment line is **not prose** when it
is a delimiter alone (`/**`, `*/`, `"""`) or has no letter or digit (`// -----`); a tool
directive (`eslint-disable`, `@ts-expect-error`, `# noqa`, `# shellcheck`, Go's `go:build`,
`pragma`, a region marker, `clang-format off`); an editor or encoding line in its whole
shape (`-*- coding: utf-8 -*-`, a `vim:` modeline, `$Id$`, `# encoding: utf-8` in the first
two lines of a Python or Ruby file); a doc tag whose operand is a type (`@param int $x`,
`@return Foo<Bar>`, `@param {string} id`, `@throws RuntimeException`, a shape such as
`array{id: int}` until it closes or its block ends) or a tag with no text of its own; a `:type:` / `:rtype:` line or a bare `Args:` / `Returns:` heading; a line of
the file's first comment block when that block names a copyright, an SPDX identifier or a
licence; or a `|`-led line inside a `/* */` block (a Laravel config stub). Dockerfiles and
Makefiles are judged by `scan.sh` only: a comment per instruction is idiomatic there.

A project that specifies a heavier style sets `COMMENT_DISCIPLINE_CEILING_TENTHS` in its
settings `env`: **5 for a project that documents every public API** (PEP 257 docstrings,
Javadoc — at 0.3 a third or more of the Python, Ruby and Java standard-library files of 50
lines or more are refused, and at 0.5 still 13% of Python's, 22% of Ruby's and 30% of the
JDK's), 4 for the 0.25.0 ceiling, 10 for 1:1, and 0 to switch the ceiling and the short
rule off and keep only the sibling test; a value over 10000 is read as 10000 (1000.0:1).
Setting 4 restores the
number only: the file types judged since 0.26.0 (shell, SQL, CSS, SCSS, Less, Lua, Elixir,
Perl, Julia, R, Groovy, Terraform, GraphQL), the short rule, the exact compare and the
prose-only count stay. A project whose own CLAUDE.md demands a docblock on every method
gets its first over-ceiling `Write` per file denied until it sets that variable; the hook
does not read CLAUDE.md. `CC_COMMENT_GUARD=off` (below) switches the comment denies off and
leaves the warnings on; the elision deny keeps running. `verbosity.sh` applies the same rule to terminal
prose. Markers live in the plugin's data directory,
`${CLAUDE_PLUGIN_DATA}/<project-key>/comment-discipline/`, when the host provides one, else
under `.claude/comment-discipline/` at the project root; the ledgers are
`$HOME/.claude/comment-discipline/*-ledger.jsonl`. The project root is the git toplevel,
else `CLAUDE_PROJECT_DIR` — not whatever directory the shell has
`cd`'d into, which scattered one state dir per directory until 0.23.0. Silence any
advisory with `CC_REMIND=off`; the denies are not advisories and do not honour it —
they have their own switches, `CC_COMMENT_GUARD=off` and, for the elision deny,
`CC_ELISION_GUARD=off`, set in the session's `env` and named in every refusal so the
person being blocked can read the remedy off the block.
Turning the deny off leaves the warnings on: the two lanes are switched separately.

**Writes through Bash (since 0.25.0).** Both hooks also run on `Bash` — one measured
session made 233 of its 238 main-thread writes that way. A heredoc that `cat` or `tee`
carries to a file (`cat > f <<EOF`, `cat >> f <<EOF`, `tee f <<EOF`, `cat <<EOF | tee f`,
also behind `sudo`, and for `cat` behind a `VAR=value`) is judged as a `Write` of its
body to that file: the same detectors, the same message followed by ` Written by a Bash
command: <file>.`, and the same two denies per file per budget — a `Write` and a heredoc
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
those three, `migrations/` and a `build/` at any depth were skipped in every project. Text that declares itself generated is exempt from every
deny and from the after-Bash measurement: one of the first five lines written (of the
file on disk, for that measurement) holds `@generated` or `<auto-generated`, or
begins, after the comment leader and in any letter case, with `Code generated`,
`Generated by`, `Generated from`, `Generated code`, `Auto-generated`, `Autogenerated`,
`Automatically generated`, `This file was generated` (also `is`, `code`, and the three
auto forms), `Do not edit` or `Do not modify`. A line that only mentions a generator
(`// This is not generated by a tool`) no longer exempts the file.

**The elision deny (since 0.30.0).** A `PreToolUse` `Write`, an `Edit` or `MultiEdit`, or
a Bash heredoc that replaces the file (`cat > f`, `tee f` without `-a`), over an existing
governed file with a non-blank line is refused only when both hold: a non-blank line of
the replaced text (the file on disk, or the `old_string`s) is gone from the new text, and
the new text holds more placeholder comments than the replaced text. Over such a file a
pure addition is never refused or warned. An `Edit` needs two comparisons to agree that it adds one: the
whole file after the edits against the file on disk (CRLF line ends normalised), and the
`new_string`s against the `old_string`s; when they disagree it is neither refused nor
warned, and when the file is over 1 MiB, holds no copy of an `old_string`, or `jq` is older
than 1.6 (no `--rawfile`), the second comparison decides alone. The refusal starts `elision-guard:`, names the placeholder line,
says to re-read the file and write it whole or use `Edit`, and ends by naming its switch,
`CC_ELISION_GUARD=off` (plus the Bash suffix on a heredoc).

A placeholder is a comment body, in any letter case and after any brackets enclosing the
whole body, that an ellipsis (`...` or `…`) opens, with no name glued to it, or closes,
and that holds nothing but a listed phrase and then filler once every ellipsis, bracket,
`,`, `;` and `:` is set aside. After an opening ellipsis the phrase is any of these, a
`the` allowed first; otherwise it is a code noun from the first five and starts the body:

- `existing code`, `implementation`, `jsx`, `markup`, `template` or `html`;
- `rest of (the) code`, `file`, `class`, `function`, `method`, `component`,
  `implementation`, `template`, `markup`, `jsx` or `html`;
- `remaining code`, `methods`, `functions`, `fields` or `cases`;
- `code`, `implementation` or `logic unchanged`, and `unchanged code`, `implementation`
  or `logic`;
- `other methods`, `functions`, `code` or `fields`;
- opening only: `same as above` or `before`, `omitted`, `previous code` or
  `implementation`, `keep (the) existing` with or without `code`, `implementation` or
  `logic`.

Filler is `unchanged`, `remain(s)` or `stay(s)` followed by `(the) same` or `unchanged`,
`as before`, `as above`, `as is`, `here`, `goes here`, `omitted`, `elided`, `kept`,
`for brevity`, `intact`, `if needed` and `as needed`, in any number and order, bracketed or
not — nothing else.

So `// ... existing code ...`, `// ...existing code...`, `// (... existing code ...)`,
`// rest of the code remains the same ...` and `// ... rest of the file (unchanged) ...`
count; `// omitted ...`, `// keep ... existing code`, `// ... and the rest of the file`,
`// TODO: handle the remaining cases...`, `// Other fields are omitted...`,
`// ... remaining cases return null` and `// ... rest of the file is unchanged ...` do not. Markup
comments count: `{/* ... existing JSX ... */}` in a `.tsx`, `<!-- ... rest of the template
-->` in a `.vue`. A doc comment (`/** */`, `///`, `//!`, a docstring) never counts.

- **Never judged:** an appending heredoc; doc-comment lines; text whose first five lines
  carry a generated marker; text inside a multi-line string — JS, TS, JSX, TSX, Vue and
  Svelte template literals, Go raw strings, Python triple quotes, Kotlin, Java, Swift,
  Scala, Groovy, Dart and C# `"""` strings, and shell quoted strings and heredoc bodies.
  The path exemptions above do not apply: code lost under `vendor/` or `.claude/` is still
  lost. A `Write` or heredoc over a file over 1 MiB is not compared, so it is allowed.
- **Warned once, never refused:** a placeholder in a new or empty file, a comment that is
  only an ellipsis, a write past the two-deny bound, and any write with the deny off. The
  warning arrives after the write (`PostToolUse`), driven by a marker the `PreToolUse`
  lane leaves.
- **Switches and budget:** `CC_ELISION_GUARD=off`, or `cc_elision_guard` off in
  `/config`, turns the deny into that warning; `CC_REMIND=off` silences the warning and
  leaves the deny on; `CC_COMMENT_GUARD=off` leaves it on too. Two denies per file per
  session, on a budget of its own: a write that trips this and a comment deny prints the
  elision reason alone and spends only this budget, so one file can draw up to four
  refusals across the two.
- **Missed:** placeholder wording outside the list above; a placeholder trailing code on
  its line; a markup comment spanning lines; an ellipsis glued to a name with no closing
  ellipsis (`// ...existing code`, `...$rest`); an ellipsis neither opening nor closing the
  body (`// keep ... existing code`, `// existing code ...;`) or bracketed (`// [...]
  existing code`, `// existing code (...)`); one closing it after no code noun
  (`// omitted ...`) or after a `the` (`// The rest of the code remains the same...`); a
  listed phrase not at the body start (`// ... and the rest of the file`) or followed by
  anything but filler (`// ... rest of the file is unchanged ...`); any line of a doc
  comment; a placeholder inside a multi-line string; every line after an
  unbalanced backtick (a regex such as `` /`/g ``, JSX text) or a `$(( 1 << y ))` up to
  the next one, or after a `/\/*` regex read as an opening block comment; a placeholder
  added where no line is removed; an `Edit` adding a placeholder line the file already
  holds; an `Edit` whose `new_string` opens by closing a template literal and then adds a
  placeholder; a `Write` over a file over 1 MiB. After two denies the write goes through
  with only a warning, so code can still be lost.
- **One stated refusal**, pinned by a harness case and seen 0 times in the samples and
  the replay below. A write that removes a line is refused for placeholder-shaped text
  inside a string the tracker misreads — a PHP `<<<` body, a template literal after a
  `/\/*` regex.
- **Read as comments, so their text can be refused or warned:** PHP `<<<` and Ruby `<<~`
  heredocs, Rust raw and C# verbatim strings, Elixir and Julia `"""`, Perl `<<EOT`, Lua
  `[[ ]]`, C++ `R"(`, plain multi-line strings in Rust, PHP and Ruby, and an `Edit` whose
  `new_string` starts inside a string its unchanged text opened, when the file is missing,
  over 1 MiB or holds no copy of an `old_string`, or when the host's `jq` is older than 1.6.

Measured on real code on 2026-10-05 with `scan.sh`'s own counter, on the grammar this
release ships: the plugin author's repositories (14,584 files) held 3 matches, all genuine
placeholders, and system and standard-library code (1,992 files) held 0 — 0 false positives
in either. Its one committed placeholder, a "(rest of the file remains the same until …)" comment
in a Homebrew package's C source, matched until the phrase
had to start the body and only filler could follow it; it is missed now.
Files holding an ellipsis-only comment, which only warns: 2 and 8. Replaying 4,758 pairs of
consecutive real git revisions across 80 of those repositories, each revision written as a
`Write` over its predecessor under default settings, drew 0 elision denies. An independent
review replayed 13,182 real `Edit`s and 5,326 `Write`s from session transcripts across 69
repositories with 0 allow → deny under default settings; it ran on the grammar before the
last three tightenings (an unquoted ellipsis at the start or end of the body; doc-comment lines
and closing ellipses; a listed phrase first and only filler after it), and they only removed
matches.

Added hook time against 0.29.0, measured on the build before the final rule (file cksum
3895726106; the phrase-then-filler rule was not re-timed), median of 20 runs on one macOS
machine, against a 15 s timeout: +1 ms
for a Bash call that writes nothing (19 ms); +22 ms for a `PostToolUse` `Write` with no
warning pending (64 ms); over a 1 MiB plain `.ts` at the cap, +255 ms for a short `Write`
adding a placeholder (297 ms), +349 ms for a full-file one (671 ms) and +768 ms for an
`Edit` (812 ms); over a 1 MiB backtick-dense `.ts`, +742 ms short (786 ms) and +1,381 ms
full-file (1,633 ms), the worst case measured. A write holding no ellipsis skips the
comparison; an `Edit` on a backtick-dense 1 MiB file was not timed.

Standing: the deny is a **gate** on the shapes above — the hook refuses the write. The
warning's emission is pinned by `scripts/__tests__/elision-guard.test.sh` (a CI step); its
effect on what the model does next is unmeasured, and so is the deny's on what the model
writes. The Missed and Read-as-comments lists are **recorded**: nothing judges those shapes
at write time.

**How `scan.sh` reads a comment (since 0.29.0).** A leader counts only where the file's
language has it: `//` in JS, TS, Vue, Svelte, Blade, PHP, C, C++, C#, Objective-C, Go, Rust,
Java, Kotlin, Swift, Scala, Dart, Groovy, SCSS, Less and Terraform; `/* */` in those and in
CSS and SQL; `#` in PHP, Terraform, Python, Ruby, shell, Perl, R, Julia, Elixir, GraphQL,
Dockerfiles and Makefiles; `-- ` in SQL and Lua. An SQL hint (`/*+ … */`) and a MySQL
`/*! … */` are code. A `*`-led line is a comment only inside a block opened by a line that
starts with `/*`; the block closes at its first `*/`, at the end of each `MultiEdit` edit
and at the end of each heredoc, and a `/* … */` or `*/` with code after it on the same line
is code. So a shell `*)` case arm, C's `**pp = 0;`, `* sizeof(int));` and `#  endif`, Go's
`**pp = nil`, Python's `**kwargs):` and `// count)`, and a Markdown `* item` inside a
heredoc are code — 0.28.0 refused them as commented-out code or as restatements. Example
code in a doc comment (the lines after `@example` up to the next tag, a fenced block, a Rust
`///` or `//!` line) is judged neither as commented-out code nor as a restatement, and a
Dockerfile's parser directives (`# syntax=`, `# escape=`, `# check=`) are exempt. A comment
is still compared with the line 0.28.0 compared it with: the first later non-blank line its
language-blind leaders would not read as a comment. A docblock tag whose type the signature
may not state (`@param list<User> $users`, `@param non-empty-string $name`, a class) is a
fact, not a repetition; a typed tag that only repeats its name (`@param int $id`) is refused
only when the signature below it, in the same added text, types the parameter too; and a
bare `@return` or `@param` whose description wraps onto the next docblock line is not empty.
A TODO carrying an owner (`TODO(ana):`), a ticket (`#123`, `BILL-412`) or a URL is not
judged any further, so `// TODO #1: sort todos by date` above the line it names is no longer
refused as a restatement, nor `// TODO(BILL-412): drop once v2 rollout completes (see ADR-7)`
as commented-out code.

**The twelve categories.** Denied before the write, and warned when such a write lands
anyway: `restating the next line`, `commented-out code`,
`docblock tag repeating the signature`. Warned only — a warning never blocks:

- `section banner` — `// ===== HELPERS =====`.
- `bare TODO` — `TODO`, `FIXME`, `XXX` or `HACK` anywhere in a comment, or a comment that
  starts with `todo` or `fixme`, with no owner, ticket or URL.
- `change-narration (describes the edit, not the code)` — `now handles`, `fix per review`,
  `previously,`, and a comment starting `updated:`, `new:` or `changed:`.
- `docblock tag padding (restates its name or type)` — in a docblock or a Python docstring,
  an `@param`, `:param` or Google-style `Args:` entry whose every word comes back from the
  parameter's name and native type (`@param id the id`, `:param user_id: user id`); an
  `@return` whose words come back from the function name and return type on the code line
  below (`@return User the user` above `getUser(): User`); an `@var` directly above a
  property declared with the same type. Spared: every tag in a `.js`, `.mjs`, `.cjs` or
  `.jsx` file (JSDoc types are the only types there); a non-native type (`list<User>`,
  `int|null`); a dotted, bracketed or defaulted name; a description holding a digit or a
  fact word — a unit, `null`, `default`, `optional`, `throws`, `only`, `unless`, `if`,
  `must`, `caller`, `owns`, `empty`, `min`, `max` and the like; a description continued on
  the next line; a typed `@param` above a signature that leaves the parameter untyped.
- `docstring restating the signature` — Python only: a one-line summary in the docstring
  that is the first statement after a `def` or `class`, every word of which comes back from
  the name and parameters (`"""Get the user."""` under `def get_user(user_id):`). A summary
  holding an operator is spared.
- `commented-out markup` — a one-line `<!-- … -->` in `.vue`, `.svelte`, `.php` and Blade,
  `{{-- … --}}` in Blade, or `{/* … */}` in `.jsx` and `.tsx`, whose body is a tag or code.
  Machine-read ones are exempt: WordPress block grammar (`wp:`), IE conditionals,
  `svelte-ignore`, `@vite`, Knockout `ko`, `#include`, and lint or formatter directives
  (`prettier-ignore`, `eslint-…`).
- `comment paragraph (one line is the budget)` — three or more consecutive `//` or `#`
  lines holding prose, one warning per run. Not counted: doc comments (`/** */`, `///`,
  `//!`) and `/* */` blocks; empty, delimiter-only, tag, directive, code-shaped and
  `shortcut:` lines, which neither count nor break a run; a run naming a copyright, an SPDX
  identifier or a licence; a Go comment run directly above code; Ruby comments directly
  above `def`, `class`, `module` or `attr_`.
- `section marker` — `//region`, `// #region`, `// MARK:` and `// Step 1:`-style steps.
- `authorship stamp (git blame holds this)` — `modified by <name> … <date>`, or a comment
  that is only a name and a `yyyy-mm-dd` date (`// ivan 2024-03-11`);
  `Deprecated 2024-01-01` names an event, not a person, and is spared.

**What `scan.sh` still misses or misreads.** A miss is preferred to a false refusal:

- An `Edit` that starts inside a docblock, with no `/*` in the added text: its `*` lines
  are not read, so a restating comment or a dead tag there is not judged.
- A program embedded in a heredoc or a shell string in a `.sh` file: its `/* */`, `//` and
  `-- ` comments are not read; its `#` lines are, so a `#` line inside a heredoc or a Python
  string is judged and counts toward a paragraph.
- Rust `///` and `//!` lines are judged neither for restatement nor as commented-out code.
- The `*` lines of a block opened mid-line (`x = 1; /* why`) are code.
- A comment after code on the same line is not read: `counter++; // increment the counter`
  draws nothing.
- MySQL `#` comments in `.sql`; multi-line markup comments, and a markup comment that
  restates its neighbour; Ruby `=begin` / `=end` blocks.
- A Python docstring that is not the first statement after a `def` or `class`, a module
  docstring, and any docstring prose beyond a one-line summary and its tag lines.
- `.html`, `.erb`, `.twig` and `.astro` files are judged by neither hook.
- A typed tag that only repeats its name, when its signature is not in the added text.
- A comment starting `updated:`, `new:` or `changed:` is change-narration first:
  `// new: set the total` above `total = 0` draws a warning, not a restatement refusal.
- The edits of one `MultiEdit` are adjacent for the paragraph count, so a run split across
  two edits can warn.
- Still refused as commented-out code, as in 0.28.0: example code in a Javadoc
  `<pre>{@code …}`, a Doxygen `\code` block or a Go tab-indented doc example.
- A linter that requires every parameter be documented (doclint, checkstyle,
  eslint-plugin-jsdoc, darglint) can make a padded tag compulsory; the warning names it and
  never blocks.
- `# -*- coding: utf-8 -*-` draws a `section banner` warning.

Standing: a deny is a **gate** — the hook refuses the write; a warning is advice, and
whether the comment goes is **agent-graded** (`/code-review:comment-review`). The
CHANGELOG's 0.29.0 entry has what the change was measured on.

**What the comment counter cannot tell apart.** `density.sh` reads lines, not a parse
tree, and a line it is unsure of counts as code: a missed comment is preferred to a false
refusal.

- **Every language:** a trailing comment after code, and a block opened mid-line
  (`x = 1; /* why`), count as code; a line inside a string that begins with an unclosed
  `/*` turns the code after it into comment up to the next `*/`; a directive the list does
  not know counts as prose (`sourceMappingURL`, `svelte-ignore`, `deno-lint-ignore`); a line
  over 4,000 bytes is one code line, and when it sits inside an open comment block, string
  or heredoc, or holds a token that may open or close one (a triple quote, a Go backquote,
  `<<`, a PHP tag), the rest of the file counts as code; a form-feed-only line is code; NUL
  bytes give counts that differ between awk builds; an upper-case extension (`.SQL`, `.R`) or a build file named `Dockerfile-dev`
  or `makefile` is judged by neither hook.
- **Comment-looking lines inside strings** count as comments: JS template literals and JSX
  text nodes beginning `//` or `/*`; PHP heredocs and multi-line strings; multi-line strings
  in shell, Rust, C# and Lua, and a single-quoted program passed to `awk`; Ruby regex
  literals and `%{}` bodies; a `\`-continued C or Python string; a Go cgo preamble.
- **Python:** a triple-quoted string that is not a docstring (assigned, or after the first
  statement) is code, and so is a docstring in plain, non-triple quotes (`"Doc."`) or on
  the `def` line.
- **Go, Kotlin, Java, Swift, Scala, Dart, Groovy:** a line with an odd number of backquotes
  (Go) or of `"""` toggles string mode, so a stray one (`` r := '`' ``) inverts it until the
  next such line, and a raw string's body can then count as comment.
- **PHP:** everything before the first `<?php` (in any letter case) and after a `?>` is code.
- **Ruby, Perl, Terraform, shell:** a `<<` with no space after it (`class <<self`,
  `1<<BITS`) opens a heredoc that never closes, so the rest of the file is code; only the
  first four heredocs on one shell line are tracked.
- **Doc tags:** an untyped tag with a description (Javadoc, KDoc, TSDoc
  `@param name text`) counts as prose; a description that starts with a capital
  (`@returns The sum`) reads as a type and does not; a type operand that opens a `{` and
  never closes it keeps the rest of its docblock out of prose.
- **The licence block** is the file's first run of comment lines, exempt as a whole: a
  licence header followed directly by a docstring exempts both, and a licence block that
  is not the first comment block counts as prose.
- **Three ways to dodge the counter**, each the cost of an exemption above: a `|` at the
  start of any line inside a `/* */` block, whatever it says; a first comment block that merely contains the
  word licence; a line that merely contains a directive word (`eslint-`, `coverage:`).
- **Refused by design:** a short single-purpose file (an enum, a constants file, an
  exception) under a why-docblock, by the short rule; compiled CSS that keeps its source
  partials' section headers and carries no generated marker.
- **Siblings:** a sibling over 256 kB (a tracked symlink by its target's size) is left out
  of the median and does not count toward the three needed; eight hook runs at once in one
  session can each print "Warning 1 of 3".
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
  globbed operand; `2>`, `&>` and `>&` targets; the second operand of `tee a b`;
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
  command writes again (the after-command measurement covers it).
- **Judged by neither of `density.sh`'s lanes:** truncating heredocs past the 40th to a
  judged file in one command — the after-command measurement reads only the first three
  targets. `scan.sh` still judges them.
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
- **Budget:** the denies are keyed on the path, not the file, so one file reached
  through a symlink keeps a second budget, and so does a `Write` whose path holds `..`
  (a Bash target has its `..` collapsed, a `Write` path does not); a deny that co-fires
  with another plugin's deny on the same call spends a try on a write that never
  happened; a hand-typed generated marker exempts a file from every deny.

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
Since 0.28.0 it also names a repo's prose standards doc on its own `standards:` line —
`CONTRIBUTING.md`, `.github/CONTRIBUTING.md`, `docs/CONTRIBUTING.md`, `CODING_STANDARDS.md`,
`docs/CODING_STANDARDS.md` or `STYLEGUIDE.md`, the path only — as a source for naming,
structure and idiom, never for comment volume or docblock style. A repo with only such a
doc now gets the hint, without the CI paragraph. Other names and lowercase variants
(`contributing.md`) are not detected, except on a case-insensitive filesystem (macOS's
default), where a lowercase file matches and is printed under the upper-case name.
Standing: the line is a **gate** through the plugin's harness
(`scripts/__tests__/conventions-hook.test.sh`) for `CONTRIBUTING.md` and
`docs/CODING_STANDARDS.md`; the other four paths share that code untested; whether a review applies the doc is
**agent-graded**. `CC_CONVENTIONS=off` silences just this one.

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

## Mods (Claude Code ≥ 2.1.291)

Since 0.31.0 the plugin also ships a hooks module, `hooks/suggest.ts`, listed under
`modules` in `hooks/hooks.json` beside the classic hooks, which fire with or without it.

- **What.** At the end of a turn in which the main loop (not a subagent) ran a `Write`,
  `Edit`, `MultiEdit` or `NotebookEdit` on a code file inside the repository, and the tool
  neither refused nor errored, the prompt box offers `/code-review:review` as a next-step
  suggestion: Tab accepts it, and nothing runs until you send it. Docs don't count:
  `.md`, `.mdx`, `.txt` and `.rst` files in any case, and any file under a `docs/`
  directory inside the repository.
- **How it differs from the nudge above.** The review-debt nudge is a line for the model on
  your next prompt, after 8+ changed files or an auth-surface path. This suggestion is for
  you, in the idle prompt box, after any code edit, and the model never sees it. Both can
  fire; neither replaces the other.
- **When it stays silent.** For edits made while a task-runner run is registered on the
  current branch (a run on another branch does not count), and when such a run registers
  before the turn ends. While a phase sentinel is live: a `.claude/cc-phase.json` under
  two hours old that this session holds or that names no session. Outside a git
  repository and before the first commit, since it keys on HEAD. Once the prompt box has
  shown it, not again for the same HEAD commit in this session; one the host did not show
  is offered again at the next turn end.
- **Off switch.** `CC_SUGGEST=off`, environment only with no `/config` option, silences
  this and the next-step suggestions of taskmaster, task-runner and git-workflow together.
  `CC_REVIEW_NUDGE` and `CC_REMIND` do not touch it.
- **CLI.** With mods off in the host, on a CLI below 2.1.287 (which loads no module), on
  2.1.288-2.1.290, or with `CC_SUGGEST=off`, the module offers nothing and the classic hooks
  work as before. On CLI 2.1.287 with mods on, the module still registers its `tool.call`
  hook (the version check runs inside it), and that CLI's own bug — a plugin's `tool.call`
  hook breaking Bash and file search in worktree subagents, fixed in 2.1.288 — applies even
  with `CC_SUGGEST=off`: upgrade the CLI or turn mods off.
- **Limits.** The prompt box holds one suggestion: when another plugin offers one at the
  same turn end the later replaces the earlier, one replaced after it was shown counts as
  shown, and Claude Code's own suggestion is not suppressed. What was shown is kept in
  memory, so a new session offers the same HEAD again. "Inside the repository" compares
  path text, so an edit spelled through a different symlink than the session's directory
  is read as outside it and offers nothing.
- **Standing.** The conditions above are a **gate**: `tests/suggest.test.ts` runs under
  `claude plugin test` in CI, except the outside-git and first-commit silences, which no
  test covers; the sentinel's two-hour and no-session clauses rest on the shared kit's own
  tests in the marketplace repository. The tests answer the host's "shown" reply themselves; whether the suggestion
  gets more diffs reviewed is unmeasured.

## Pairs well with

- **code-architecture** — the structural/YAGNI depth this review defers to, plus
  `drift-review`: whether the same diff stayed on the declared task intent
- **security** — deep security review beyond the correctness pass here
- **laravel** — per-stack idiom review for detail this plugin skips
