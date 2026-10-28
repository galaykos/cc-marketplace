# code-review hooks: the comment text moved out of the code (2026-10-26, 2026-10-28)

The text below was moved verbatim on 2026-10-26 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-code-review.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

The second move, on 2026-10-28, cut every hand-written shell hook of the plugin to a header of at most three lines (what it catches, what it misses, the pointer) and one line per trap the code cannot show. Its blocks are every `###` below except review-debt.sh's "Header, THE RULE": each is a comment block, or a contiguous part of a header, as it stood, with the `# ` leader and the indentation before it removed, titled by what it sat above; the file kept a one-line summary in its place, or nothing where the code already says it. Text inside a pasted `templates/blocks/` block did not move.

## plugins/code-review/hooks/conventions.sh

### Header

```text
Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even
under a stripped/broken PATH, where `env bash` itself exits 127.

PostToolUse on the first code write of a session. Emits additionalContext naming
the PATHS of the config files that define this project's conventions, and the CI
command that actually enforces them. One-shot per session, fail-silent.

A WRITE IS A WRITE, WHATEVER THE TOOL (0.23.0). This matched Write|Edit|MultiEdit only,
and the host steers file writes through Bash: measured 2026-09-25
(rationale/2026-09-25-session-plugin-usage-review.md, finding 1), 233 of 238 main-thread
writes in one session were `cat > file <<EOF`, so the first code write of that session —
and of every session like it — never reached this hook. It now also matches Bash and
fires when cc_bash_write_targets (the shared block below) names at least one existing
code file under the project root. Same one-shot, same context key. What the block does
NOT parse — interpreter writes (python open(), php file_put_contents), cp/mv
destinations, a path held in a variable — still goes unseen; its own header lists them.
Since 0.33.0 a python, node, php, ruby, perl, deno, bun, cp, mv, install or patch run
counts too when git reports a code file changed since this hook's previous call (the
bash-write-effects block, at most MAX_BASH_EFFECTS files). That misses a writer it does
not name (npx prettier, make), gitignored files, a repo with no git, a mv or cp -p
destination and each session's first such run; a file an IDE or a parallel agent changed
in that window reads as the run's write. Every call dates the marker, the one-shot spent
or not; a spent one-shot reads no effects. A Bash call that exits non-zero fires
PostToolUseFailure, registered for Bash too. Costs: the CHANGELOG's 0.33.0 entry.

CONFIGS ARE READ AT THE PROJECT ROOT, not the payload cwd. The cwd is the shell's and
follows the model's `cd` (same review, finding 2), so a session that had `cd app/Enums`
looked for `.editorconfig` in app/Enums, found nothing, and spent its one-shot silent.

WHY PATHS AND NOT RULES. The defect is not that the model does not know what
`.editorconfig` means. It is that it does not OPEN it before writing a new file —
it emits its own defaults (2-space, single quotes, ~100 cols) into a repo
configured for tabs, double quotes and 120, and the next `npm run format` churns
the whole file. That is a not-looking deficit, and a hook fixes it.

It is deliberately NOT a digest. An earlier design emitted "the three settings
most often violated" — a distilled checklist injected before the model reads the
source. That is the precise shape rationale/stack-skill-baselines.md measured as
making review WORSE: the treatment agent read three bullets and returned findings
that were a strict subset of what the blind control found by reading the file. A
summary substitutes for a read. So this emits locations, and the model opens
them.

CI IS AUTHORITATIVE, and that is the one judgment here worth stating: a formatter
config that CI never invokes is decoration, and a repo with two formatters
configured has one that wins and one that fights. Both are named in the output
because neither is discoverable from any single file.

Off switches: CC_REMIND=off silences every advisory nudge in this marketplace;
CC_CONVENTIONS=off silences only this one.
CC_REMIND / CC_CONVENTIONS unset: the /config options cc_remind / cc_conventions decide.
```

### Once per session, keyed on the context

```text
ONCE PER SESSION. The paths do not change mid-session, and a second copy costs
the same tokens for no new information.
CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
subagents at all, and a subagent shares its parent's session_id while getting its
own transcript. Keying a one-shot on session_id therefore dedups the worker against
nudges only the PARENT ever saw, so the context where most fan-out code is written
is the one context this never speaks in. Pattern and rationale: the context-key one-shot in hooks/scan.sh.
```

### Interpreter writes

```text
Interpreter writes, through the bash-write-effects block: read with the old marker, then date it, on every call — the
one-shot spent too, since the marker is per project and a subagent's first run must not inherit a stale window. A spent
one-shot reads nothing: no git status for an answer nothing below would use. A failed Bash call fires PostToolUseFailure.
```

### Cheap exit first

```text
CHEAP EXIT FIRST: with Bash in the matcher this runs after every shell command, and
once the one-shot is spent nothing below can change the answer.
```

### Code only

```text
Code only. A markdown or JSON edit is not where formatter churn happens, and
firing on every doc write is how a nudge gets tuned out.
```

### Bash targets

```text
BASH: a relative target resolves against the payload cwd — the Bash tool's own cwd,
which is the one place that cwd is exactly right. Kept only when it lands under the
project root and is now an existing code file. At most 8 targets per call, so a
mass-write command cannot make one hook call slow. Then a code file the effects
block listed: absolute, under the root and on disk already.
```

### pyproject.toml

```text
pyproject/package.json only count when they actually carry tool config
```

### The CI lint invocation

```text
The CI lint invocation — authoritative, and not derivable from any config file.

SIX FORMATS, because only one of them was ever read. Scanning `.github/workflows/`
alone meant every GitLab, CircleCI, Jenkins, Azure and Bitbucket repo got the configs
half of this message and no `CI runs:` line — and the paragraph below still told the
reader that whatever CI invokes is the standard, while naming nothing. The keyword
list is shared; only the PREFIX differs, because each format spells "this is a shell
command" its own way (`run:`, `script:`, `command:`, `sh '…'`, or a bare list item).

WHAT THIS DOES NOT CATCH: any other runner (Drone, Buildkite, Tekton, Woodpecker,
Travis, Bamboo, a Makefile target CI calls); a GitHub composite action or reusable
workflow called from the job that does the linting; a command built from a variable;
and anything after the FIRST hit — one line is named, not the pipeline.
```

### `- run:` as a list item

```text
`- run:` as a list item is the common GitHub shape; without the optional dash this
matched nothing in a real workflow and the CI half silently never fired.
```

## plugins/code-review/hooks/density.sh

### Header

```text
Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
even under a stripped PATH where `env bash` exits 127.

Comment-VOLUME guard, two lanes. PostToolUse (warn-only, at most 3 warnings per
session; a Bash call that exits non-zero fires PostToolUseFailure, which takes this
lane) compares the file just written against the comment density of its OWN
siblings AND against an absolute ceiling, and says so when it is over either — after
a Write, or an Edit or Bash write that adds prose comment lines (density_added).
Neither lane judges a file that only declares an interface or an all-abstract class (density_contract).
PreToolUse (deny, a Write or a truncating Bash cat/tee heredoc, at most TWICE per file per session) refuses a whole new
file whose comment-to-code ratio is over the ceiling before it lands. Silence is the
common case.

WHY THIS EXISTS — the gap scan.sh cannot close by design. scan.sh detects KINDS of
bad comment: restatement, banners, commented-out code, bare TODOs, dead docblock
tags, change narration. Every one of those is a pattern in a single comment. None of
them fires on a well-formed why-comment, and a file can be 81% comment with every
line individually defensible. That is not hypothetical: a 30-card run produced
`GoogleClient.php` at 180 comment lines out of 223, and scan.sh was silent on it and
on the three next-fattest files, correctly, because each comment passed every kind
check. The skill's own anti-pattern list even warns against "deleting comments to hit
a ratio" — which is right about deletion and was read as licence to never measure.

WHY SIBLINGS. A driver with vendor quirks earns more prose than a controller, and
"twice the surrounding code" is a signal no constant can give: a run at 0.3:1 in a
repo that sits at 0.1:1 is an outlier the ceiling below would wave through. This
hook reaches subagents, which is where writing actually happens and where a prose
contract had no delivery channel.

WHY A CEILING TOO (2026-09-02, owner decision). Siblings alone had two holes. A
greenfield subtree with no tracked siblings got no judgment at all, which is the
fan-out case this hook was written for. And a repo whose committed house style is
already heavy certified more of the same. The marketplace's stated default is code
that speaks for itself — minimal comments, a docblock only for what the signature
cannot state — so the limit is now min(2x the sibling median, CEIL), and a file with
no siblings is judged against CEIL alone. CEIL is 0.3:1 on prose lines by default, the one
constant here; a project with a deliberately heavier style overrides it per project
via `COMMENT_DISCIPLINE_CEILING_TENTHS` in its settings `env` (e.g. 10 for 1:1, 0 to
switch the ceiling off and keep the sibling test). The deny lane uses the same CEIL.

LIMITATION (honest scope — the four laws, see
.claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
  - The PostToolUse lane is WARN-ONLY: `additionalContext` is not a blocking key. The
    file is already on disk. It informs the next write, never the one that tripped it.
    The PreToolUse lane denies, but only a `Write` or a truncating Bash heredoc (an Edit or an
    append carries a fragment, whose ratio says nothing about the file), only over CEIL, at most TWICE
    per file per session with the same marker-on-disk bound as scan.sh — so a false
    positive costs up to two turns and the third attempt goes through with a warning.
    The bound was one until 2026-09-15; a sibling hook denying the same call spent it
    without the write ever landing, which cost this guard its only enforcement.
  - BASH LANE. Pre-write, a truncating `cat`/`tee` heredoc is judged as a Write of its body to the
    resolved path (cd_bash_target in hooks/paths.sh), first deny printed; an append (`>>`, `tee -a`)
    is a fragment and is never denied. After the command, the warn lane measures the first 3 targets
    that exist on disk, in command order, skips one whose first five lines carry a generated marker or
    that the command wrote no prose comment line to (a redirect whose text no echo, printf or heredoc spells,
    `{ …; } > f` or `gen > f`, is measured whole; a sed -i or perl -i target never is), and prints the first warning.
    After a python, node, php, ruby, perl, deno, bun, cp, mv, install or patch run it also reads the files git reports changed
    since this lane's previous call (the bash-write-effects block, at most MAX_BASH_EFFECTS), and measures each governed one
    no target named, within the same 3, once it holds more prose lines than its HEAD copy (density_added).
    A command with a line over 8 kB is not parsed for targets; its effects are still read.
    NOT SEEN on Bash: a writer the effects block does not name (npx prettier, make), gitignored files, a repo with no git,
    a mv or cp -p destination, each session's first such run, a file over 256 KB that no target named, a path held in a
    variable, a relative target after an in-command cd, files past the first 3; any file changed since this lane's previous
    call (an IDE, a parallel agent) is read as the run's write, and prose uncommitted since HEAD as its prose; pre-write
    also an interpreter write, a heredoc fed to anything but cat/tee, a heredoc whose file the
    command writes again, truncating heredocs past the 40th to a governed file (judged by neither lane), echo/printf and sed -i / perl -i content, the second
    operand of `tee a b`, `VAR=x tee f`, cat/tee behind a wrapper, brace or keyword; plus what the two blocks below miss.
  - A ratio is not a judgment. A file legitimately denser than its siblings (the one
    driver full of vendor workarounds) trips this, and that is a false positive the
    author should overrule by keeping the comments and moving on — the message says so.
  - It cannot see the AGGREGATE across a fan-out. Each subagent gets its own warning
    in its own context; nothing sums 73 files and reports "this run runs 2x the
    repo". The ledger below exists so that question can be answered later from data,
    but nothing reads it back today and calling it a feedback loop would be the
    over-claim this plugin has been pulled up on before.
  - The counter is cd_classify in hooks/paths.sh: a per-language line classifier, not a
    parser. The numerator is PROSE lines: delimiters, typed doc tags, tool directives, a
    licence first block and `|`-boxed config blocks are comments but not prose. A trailing
    comment, a mid-line `/*` and a triple-quoted string that is no docstring count as
    code; a directive it does not know counts as prose. A line it is unsure of is code. Dockerfiles and Makefiles are not judged.
  - Thresholds are a starting point, not a constant: 2.0x the sibling MEDIAN, with an
    absolute floor of 0.3 so a repo that comments almost nothing cannot make a single
    why-comment an outlier, then capped at CEIL. The floor EQUALS the default ceiling,
    so the sibling test decides only where a project raised CEIL past 0.3 or set it to 0.
    A file under 50 non-blank lines, or under 8 code lines, gets the SHORT rule instead: over the
    limit with 5+ prose lines, a code line, and more prose than code (or than CEIL allows,
    once CEIL is past 1:1); CEIL=0 switches it off. The ledger records every measurement
    so the thresholds can be revisited against real data instead of re-argued.

FAIL-OPEN: missing jq/awk, unreadable file, too few siblings, or any error exits 0.
CC_REMIND / CC_COMMENT_GUARD unset: the /config options cc_remind / cc_comment_guard decide.
State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/comment-discipline/ is only the fallback.
```

### Interpreter writes

```text
Interpreter writes, through the bash-write-effects block: read with the old marker, then date it, on every call this lane
sees, so an Edit's file or a command that wrote nothing never reads as the next run's write. The marker is this hook's own.
```

### CC_COMMENT_GUARD

```text
CC_COMMENT_GUARD=off disables the DENY lane and leaves the advisory lane on.
Added 2026-09-22 (UX 1), same reasoning as scan.sh's: the block had no off switch,
so its refusal could name none. Read from the hook's environment.
```

### Context key

```text
CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
subagents at all, and a subagent shares its parent's session_id while getting its
own transcript. Keying a one-shot on session_id therefore dedups the worker against
nudges only the PARENT ever saw, so the context where most fan-out code is written
is the one context this never speaks in. Key on transcript_path first, session_id as fallback.
```

### The payload cwd and the state root

```text
`-d` as well as `-n`: a session outlives its directories, and the `mkdir -p "$dir"`
below rebuilt a deleted three-level project tree just to hold this hook's state. Then
the state ROOT, not the cwd: the payload cwd is the shell's and follows the model's
`cd` (measured 2026-09-25, rationale/2026-09-25-session-plugin-usage-review.md finding
2 — app/Enums, app/Models, then the repo root in one session), so `<cwd>/.claude` scattered
one state dir per directory and reset MAX_WARN and the per-file dedup at every `cd`.
The address `<root>/.claude/comment-discipline` is SHARED with verbosity.sh and
scan.sh; all three moved to cc_state_root in one change (0.23.0), because re-rooting
one of them alone splits a bound across two paths. Does NOT catch a cwd that exists
but is the wrong checkout — the payload cannot say.
```

### The floor

```text
The floor is on SUBSTANTIVE LINES, not on code lines, and the difference is the
whole point. A `code >= 40` floor excludes exactly the worst case this hook exists
to catch: the observed `GoogleClient.php` was 223 lines of which 180 were comment,
so it had ~43 code lines and a code-shaped floor would have waved through the
single densest file in the run. A few code lines are still needed for the ratio to
mean anything, hence MIN_CODE — set low, as a divide-by-noise guard, not a filter.
```

### density_contract

```text
An interface or an all-abstract class has no bodies, so its docblocks are the contract and breach any ratio: a worker
deleted a real why-clause from one to pass. A file is not judged when every line outside comments is an import, package
or namespace line, an annotation, a type alias, an enum or a declaration's own lines, at least one declaration is an
interface, abstract class, protocol or Go interface, and none holds a body: `)` then `{`, `)` then `=` (Kotlin), a C#
or Dart `=>`, a get, set or init accessor's `{` or `=>`, or a `static {` initializer. One line at a time and out at the first other line: joining the text was quadratic under mawk, and a 3.7 MB
file hit the 10 s timeout. Misses: a Python ABC; a member typed `(): { … }` reads as a body, so that file is judged; an
arrow function assigned to an abstract class's property reads as no body.
```

### density_added

```text
The prose lines a PostToolUse Edit or Bash write adds: 7 of 11 warnings in real sessions followed edits that added none,
about a file's existing density. An Edit compares the file on disk with the same file, each new_string swapped back to its
old_string, so a line added inside a docstring or a leader-less block comment counts. Past 256 KB, or with a new_string
empty or not on disk, it counts its new_strings over its old_strings instead, a fragment whose first line is `*`-led read
as opening inside a block comment. A Bash write counts the text it wrote to the target ($1). A file an interpreter run
changed (mode effect) compares the file on disk with its HEAD copy, none when HEAD lacks it, up to 256 KB: the text before
the run is gone, so prose any uncommitted edit added since HEAD counts as this run's.
Misses: sed -i, perl -i and printf's substituted text add none; a new_string also present above the edit swaps the wrong copy.
```

### Path exclusions

```text
Same PATH exclusions as scan.sh, decided by hooks/paths.sh against the same LOGICAL
path (worktree prefix stripped): generated, vendored and marketplace tooling trees
have deliberate header blocks. A missing paths.sh judges nothing. Config/prose formats
use comments for navigation, which this rule does not govern.
```

### Build files

```text
A comment per instruction is idiomatic in a build file (owner decision 2026-10-02); scan.sh still reads them.
```

### The context key is hashed

```text
Hashed, not raw: `.transcript_path` is an absolute path, so `density-$sid` names a
nested file whose parents are never created. Every state write then fails silently,
`warned` stays 0, MAX_WARN never engages, the per-file dedup never engages, and the
self-output filter below never engages — so a track run raises the sibling median to
match its own dense output and certifies the drift it just wrote. Same idiom as
the `seen=` line of hooks/conventions.sh.
```

### Unwritable state

```text
Same rule as scan.sh's deny lane and verbosity.sh: a bound that cannot be recorded
is not a bound. Unwritable state means this hook does nothing at all, rather than
warning on every single edit for the rest of the session.
```

### PreToolUse lane

```text
---- PreToolUse lane: deny a whole new file over CEIL, at most TWICE per file ----
Same bound and the same reasoning as scan.sh's deny: the model wrote it, so the
model is the audience; `ask` would interrupt the human for a style call; and a
deny that cannot record its bounding marker is withheld rather than left unbounded.
```

### Bounded retries

```text
BOUNDED RETRIES, not a one-shot — same defect and same fix as scan.sh: a sibling
PreToolUse deny blocks the write too, and the old one-shot was spent on a write
that never landed, so the next edit of this file went through unchecked.
```

### Atomic tries

```text
ATOMIC, same claim as scan.sh: a noclobber file per try (O_CREAT|O_EXCL), not
mkdir(1), which uutils coreutils makes non-exclusive under a race. A `.dN` directory
from <=0.31.0 or a legacy zero-byte marker counts as a try, so an upgrade
mid-session does not grant a fresh budget.
Residual, same as scan.sh: the bound is spent on a DENY, which does not prove the
write landed — two co-firing siblings can still exhaust it.
```

### Write versus Edit

```text
A Write is a whole new text and keeps the whole-file ratio; an Edit or a Bash write is judged only once it adds prose,
unless the command's text for this target could not be read (mode whole).
```

### Baseline

```text
---- baseline: same-language siblings, nearest directory first ----
Cached per directory per session — a fan-out writing 30 files into one package
must not re-scan that package 30 times.
```

### Resolved forms

```text
Resolved forms, computed once. Needed in two places that must agree: the
repo-root bound on the sibling walk, and the "already measured this session"
ledger — git reports symlink-free paths and the edited path usually is not one.
```

### The baseline must be pre-existing code

```text
THE BASELINE MUST BE PRE-EXISTING CODE, and this is the subtlety the whole hook
turns on. A fan-out that writes 73 uniformly dense files into one new package
would otherwise compute its baseline FROM ITS OWN OUTPUT, find no outlier, and
certify the drift it just created. That is precisely the run this hook exists
for. So siblings are drawn from files git already TRACKS — committed code is
house style; a file this run created is not — and any file this session has
already written is filtered out on top, which covers a tracked file the run
rewrote. Not a git repo, or git absent: fall back to `find`, and say so in the
ledger by way of the baseline it produces.
```

### Walk up, bounded by the repository root

```text
WALK UP until there is enough tracked code to average, capped at 4 levels. One
widening step is not enough: a feature fan-out creates a whole new SUBTREE
(`app/Services/Google/Contracts/`), so neither that directory nor its parent has
any tracked file, and a two-step search finds nothing and exits silently on
exactly the run this hook is for. Depth grows with the walk so a shallow level
can still reach the code below it.

THE WALK IS BOUNDED BY THE REPOSITORY ROOT, and that bound is load-bearing rather
than tidy. Without it a file in a repo with no tracked code walks out of the
project entirely and averages whatever `.php` files happen to sit in the parent
directory — a sibling checkout, a scratch dir — then reports that as "its
siblings". A baseline computed from unrelated code is worse than no baseline,
because the warning names a house style that does not exist.
Both sides of the bound are resolved with `pwd -P` before comparison. They must
be: `git rev-parse --show-toplevel` returns a symlink-free path, while the edited
file's path usually is not — on macOS every `/var/...` path is really
`/private/var/...` — so a raw string prefix test fails on exactly the temp dirs
this is tested in, and silently reduces the walk to zero levels.
```

### Median

```text
Median of the per-sibling ratios in tenths. Median, not mean: one 90%-comment
interface file in the sample must not redefine the house style by itself.
No usable siblings leaves base empty, and the ceiling alone judges the file.
```

### One find for the sibling set

```text
One find for the whole set, -L so a tracked symlink is sized by its target: 25 siblings of 7.7 MB took the classifier 8 s against a 10 s timeout.
```

### Ledger

```text
LEDGER. Every measurement, warned or not — machine-local, never in the project
tree, capped, and read by nothing automatically. Same placement and same honest
framing as verbosity.sh's: it exists so the thresholds above can be revisited
against real data rather than re-argued.
```

### Chunk text

```text
The text each chunk wrote, keyed by its target as spelled: a heredoc body as written, an echo/printf argument list
with its redirects, flags and outer quotes dropped. The first 40 chunks, the deny lane's cap.
```

## plugins/code-review/hooks/paths.sh

### Header

```text
Shared path scoping and the comment classifier for comment-discipline's two file guards (scan.sh, density.sh).
Not executable and has no shebang: it is only ever sourced.

WHY THIS EXISTS. Both guards skip `*/.claude/*` — meant to exempt the Claude
configuration directory, whose contents nobody edits for readability. The pattern
also matched every source file inside a git worktree, because this marketplace's own
skills place worktrees at `.claude/worktrees/<branch>`: `worktree-isolation` says so,
and `track-orchestration/references/algorithm.md` literally runs
`git worktree add .claude/worktrees/<run-branch>-track-<slug>`. So the parallel-track
execution path wrote all of its code into the one directory the comment guard was
hardcoded to ignore, and a 73-file run drew not a single warning — one of two
independent reasons that guard was silent (the other being that scan.sh detects
comment KINDS, which is what density.sh was added to complement).

The fix is scoping, not deleting the exemption: `.claude/settings.json` should still
be exempt when it sits in a worktree. So the exclusion test runs against a LOGICAL
path with any worktree prefix stripped — inside a worktree, a file is judged by where
it sits in the checkout, exactly as the same file would be judged in the main tree.

LIMITATION (honest scope): the `.claude/worktrees/<name>/` shape is a convention this
marketplace states, not one git enforces. A worktree placed anywhere else was never
excluded and is unaffected; a worktree placed at `.claude/wt/<name>` would still be
skipped, and nothing here can detect that without probing the filesystem for a `.git`
file on every edit, which is a cost this hook does not want on its hot path.
```

### cd_logical_path

```text
cd_logical_path <path> — prints the path with every leading
`…/.claude/worktrees/<name>/` segment removed, so exclusion patterns see the
checkout-relative shape. Loops: a worktree checked out inside a worktree is
unusual but the nesting is what the pattern would otherwise trip on.
```

### cd_effect_files

```text
The files an interpreter, cp, mv, install or patch run changed come from cc_bash_write_effects, pasted in each hook because it
runs before this file is sourced. cd_effect_files <effects> <targets> <cwd> <hascd> prints each governed one no target resolves to.
```

### cd_effect_added

```text
cd_effect_added <root> <file> prints what a run added to <file>, nothing past 1 MiB: the whole file when HEAD lacks it, else the
`+` lines of `git diff -U0 HEAD`, a \037 line between hunks. The text before the run is gone, so any change uncommitted since HEAD reads as added.
```

## plugins/code-review/hooks/review-debt.sh

### Header, THE RULE

Moved when the reminder stopped saying "Per-card reviews do not cover cross-card changes." (code-review 0.34.1): the clause spoke of task-runner cards to users who never ran task-runner.

```text
  - Both lines say per-card reviews do not cover cross-card changes: in a 2026-10-13
    session the model declined the nudge citing the per-card reviews of an unregistered
    run, and whole-branch passes in the same retro found defects no card's review could see.
```

### Header

```text
Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even under a
stripped or broken PATH, where `env bash` itself exits 127.

Review-debt nudge. ADVISORY: one line of additionalContext on a user prompt when the
code changed since this context's last review is big enough, or sensitive enough, that
an independent pass is worth asking for. It never blocks and it never reviews.

WHY THIS EXISTS. Measured 2026-09-25 (rationale/2026-09-25-session-plugin-usage-review.md,
finding 7): one inline session shipped ~40 task-list items over 22 days — a second auth
guard, impersonation with an audit trail, invite and API tokens, encrypted credentials —
and dispatched ZERO reviewer agents. Its tests, PHPStan and CI were green on every item.
In the same weeks a sibling session's pipeline reviewers caught what those tools had
passed: API keys in logs, a race that overwrote a failure with "succeeded", a refusal
detector firing on ordinary words. That session lacked the prompt, not the tools: its
prompts ("proceed next recommended") carry no keyword a prompt router can match, and the
per-edit nudges never saw its writes (finding 1). So this measures the DIFF, not the words.

THE RULE, per context (keyed on cksum(transcript_path)):
  - base: `<root>/.claude/code-review/review-base-<ctx>` holds a commit. The first prompt
    with no base records HEAD and says nothing — the nudge counts only what THIS context
    wrote, never the history it walked into.
  - changed = `git diff --name-only <base>` (commits since base plus the working tree),
    minus *.md, lockfiles, `.claude/`, `taskmaster-docs/` and generated/vendor dirs.
  - speak when changed >= 8 files, or >= 1 path matches the auth-surface pattern below.
  - ONCE PER HEAD: re-fire only after HEAD moves AND the count grew past what last fired.
  - SHIP PROMPTS skip the once-per-HEAD wait: a prompt whose first 400 characters outside
    code fences say commit, push, merge, PR or pull request is judged at once, untracked
    files counted too, and the line opens "Before this ships". It re-fires only when the
    count grew past what the last ship line said. Measured 2026-10-13: a money diff sat
    uncommitted when the user asked for a PR and a merge; HEAD had not moved, so the nudge
    stayed silent until after the merge, and the review it then prompted found a critical
    bug already on master.
  - base_f also holds the branch it was recorded on. A branch change moves the base to the
    commit the switch landed on (the HEAD reflog's newest `checkout:` entry, looked for only
    back to the old base's own entry), else to HEAD. Measured 2026-10-13: after `git switch`
    to a branch built on the old base, the old ancestor rule charged that branch's 162
    existing files to the session. The reflog point keeps a `git switch -c` plus commits made
    in one turn in the count, where a reset to HEAD would drop them.
  - a review moves the base to HEAD: an Agent/Task dispatch whose subagent_type ends in
    `reviewer` or sits in `security:` / `code-review:`, a Skill call of code-review:review,
    security:review or the host's built-in code-review / security-review, or a prompt the
    user typed as one of those slash commands (a typed command never reaches PostToolUse,
    and without this the user who ran the review this nudge asks for would be nudged again).

WHY UserPromptSubmit, not Stop as the review table first proposed: a Stop hook reaches the
model only by blocking, and blocking on review debt would repeat finding 4 (a completion
gate blocking a correctly-waiting turn). A prompt-time line costs nothing when ignored.

SILENT, and why:
  - outside a git work tree, or before the first commit — there is no diff to measure;
  - under an active task-runner run (`<root>/.claude/task-runner/active-run.json`): runs
    carry their own reviewer discipline, so each prompt there also moves the base to HEAD,
    or the whole run's diff would be charged to the first prompt after it;
  - off switches: CC_REMIND=off silences every advisory nudge in this marketplace;
    CC_REVIEW_NUDGE=off silences only this one.
    CC_REMIND / CC_REVIEW_NUDGE unset: the /config options cc_remind / cc_review_nudge decide.

CHEAP ON THE SILENT PATH: the state root (one `git rev-parse`), HEAD (a second), the branch
(a `git symbolic-ref`), a stat of the run marker and two one-line reads. The diff runs at
most once per HEAD, except on a ship prompt, which also lists untracked files. Git runs with
GIT_OPTIONAL_LOCKS=0 so it never contends with the model's own `git` for index.lock.

LIMITATION (honest scope — the four laws, see
.claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
  - COMMIT-DRIVEN except at a ship prompt. Between ship prompts the diff is evaluated once
    per HEAD, so uncommitted work is seen at the next commit or the next prompt naming a
    ship verb. A ship verb is matched on words, not intent: "push notifications" counts, a
    ship request worded without one ("land it", "/git-workflow:finish") does not, and a
    ship verb past 400 characters or inside a code fence is not read. Untracked files are
    counted only on a ship prompt.
  - A review is recognised by NAME, not by what it covered. A reviewer dispatched on one
    file moves the base past twenty; a review done outside these channels (a PR review,
    a manual read) is invisible and the nudge still fires.
  - The auth-surface pattern is a path regex: `tokens.css` (design tokens) matches it,
    and an auth bug in `app/Services/Billing.php` does not. It is the shared prompt-shape
    block's cc_prompt_auth_surface, edited there for every copy.
  - A base that stops being an ancestor of HEAD (rebase, amend) is reset to HEAD silently
    rather than diffed across branches — an amended commit's changes are lost to the count.
    A branch change keeps nothing from the branch left behind: switching away and back
    starts the count again. Without a HEAD reflog (or with the switch older than its last
    200 entries) the base moves to HEAD, dropping commits made on the new branch before
    this prompt. A base recorded before 0.33.0 holds no branch; it adopts the current one.
  - A stale active-run.json (a crashed run) keeps this silent until the file is removed.
  - Whether a nudged review was WORTH it is agent-graded; nothing here reads the verdict.

FAIL-OPEN: missing jq/git, unreadable state, or any error exits 0 with no output.
State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); the <root>/.claude/code-review/ above is only the fallback.
```

### The event name

```text
The event name is read, and inferred from the payload's shape when absent, so one
missing field cannot silently disable both halves.
```

### State file formats

```text
base_f is "<base commit> <branch>"; seen_f is "<last HEAD evaluated> <count that last
fired> <count the last ship line named>".
```

### Where the switch landed

```text
Where the switch landed, searched only back to the old base's own entry: an older
checkout predates this base, and moving the base onto it would charge history.
```

### The auth surface

```text
`auth` but not `author`: a publishing app's AuthorController is not an auth surface. The words are the prompt-shape block's
cc_prompt_auth_surface; taskmaster's reminder reads the block's narrower cc_prompt_auth_ask on prompts.
```

### The ship line's count

```text
A ship line answers to the last ship line, so a ship prompt still speaks after a plain
nudge at the same count; it also raises the plain count, so the next commit stays quiet.
```

## plugins/code-review/hooks/scan.sh

### Header

```text
Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
even under a stripped PATH where `env bash` exits 127.
comment-discipline guard. On an Edit/Write/MultiEdit or a Bash cat/tee heredoc it inspects the *added* text
and reports the high-confidence noise patterns; the elision deny below also reads what that text replaces.
Silence is the common case.

ONE DETECTOR, TWO LANES — the event decides which:

  PostToolUse (default when no event name is present) — WARN. Emits
  {"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}}, exit 0
  — the one non-blocking channel the executing model actually receives; plain stdout
  text with exit 0 never reaches it (same reasoning as task-runner/hooks/scope.sh).
  `additionalContext` is NOT a blocking key: it adds context, it cannot veto. This lane
  never blocks anything, ever. A Bash call that exits non-zero fires PostToolUseFailure
  instead (hooks.json registers that for Bash): it takes this lane, answering in its own envelope.

  PreToolUse — DENY, narrowly. Warning after the write is warning about a file that is
  already on disk, and a warning the model may read and walk past is not enforcement.
  So the three strictest categories — a comment restating the next line, commented-out
  code, and a docblock tag that repeats the signature — are denied BEFORE the write,
  and of the comment categories only those. The third joined on 2026-09-02: `@param $id The id` / `@return void`
  is a syntax match with no prose judgment in it, and it was the shape most of the
  observed noise took (a full PHPDoc block per method, every tag filled in). Banners,
  bare TODOs and change-narration comments stay warn-only: they are house-style calls,
  a TODO can be a legitimate mid-task marker, and narration cues are phrase matches
  that can catch a legitimate why-comment phrased as a change event.

  ELISION DENY (elision_judge) — a second deny with its own switch, CC_ELISION_GUARD, which
  CC_COMMENT_GUARD=off leaves on: a write that replaces existing code with a placeholder
  comment (`// ... existing code ...`) is refused when the new text holds more of them than
  what it replaces — the file on disk for a Write or overwriting heredoc; for an Edit both its
  old_string(s) and the whole file before it — AND a non-blank line of the replaced text is gone.
  When one call trips both denies, only the elision reason is printed and only
  its bound is spent. A placeholder it lets through — a new file, an ellipsis-only comment, a
  write past its bound, any write with CC_ELISION_GUARD=off — leaves a one-shot marker the
  PostToolUse lane turns into a warning; CC_REMIND=off writes no marker and so silences it.
  A write that removes no line, or an Edit the two comparisons disagree on, leaves no marker.

BOUNDED: each deny fires AT MOST TWICE PER FILE PER SESSION, on its own budget. Once a budget is spent the edit
goes through and the PostToolUse lane warns instead, so a false positive costs at most two
extra turns per budget — up to four for a write tripping both — and can never wedge a session. The bound was one until 2026-09-15, when a
sibling hook denying the same call was found to spend it with no write ever landing. Without a session_id the bound cannot be enforced, so the
deny is withheld entirely. Generated files (a `@generated` / `generated by` / `do not
edit` marker in the first five added lines) are exempt from both, as are the extensions
already excluded below; the excluded paths are exempt from the comment deny only.

BASH LANE — a `cat`/`tee` heredoc body is judged as a Write of that text to that path
(cc_bash_write_chunks, cd_bash_target in hooks/paths.sh), chunks in command order, first verdict
printed. Measured: rationale/2026-09-25-session-plugin-usage-review.md finding 1, 233 of 238 writes.
After a python, node, php, ruby, perl, deno, bun, cp, mv, install or patch run the warn lane also reads the files git reports
changed since its previous call (the bash-write-effects block, at most MAX_BASH_EFFECTS) and judges each governed one no
target names on what it added (cd_effect_added in hooks/paths.sh): the whole file when HEAD lacks it, else its `+` lines
against HEAD, so a comment any uncommitted edit added since HEAD is judged again. Never denied: the write has landed.
Effects miss a writer the block does not name (npx prettier, make), gitignored files, a repo with no git, a mv or cp -p
destination, each session's first such run and a file over 1 MiB; any file changed since the lane's previous call (an IDE,
a parallel agent) is read as the run's write. A command with a line over 8 kB is not parsed for targets; its effects are read.
NOT SEEN on Bash: interpreter, cp and mv writes before they land (the deny lane), a heredoc fed to anything but cat/tee,
echo/printf content, sed -i / perl -i content, a path held in a variable, a relative
target after an in-command cd, the second operand of `tee a b`, `VAR=x tee f`, cat/tee behind a
wrapper, brace or keyword (`/bin/cat`, `command cat`, `env X=1 cat`, `(cat`, `{ cat`, `then cat`,
`sudo -E tee`); plus what the two blocks below say they miss.

Fail-open throughout: a missing jq/awk, or any error, exits 0 and denies nothing.
CC_REMIND / CC_COMMENT_GUARD / CC_ELISION_GUARD unset: the /config options cc_remind / cc_comment_guard / cc_elision_guard decide.
Deny and elision-warn markers: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/comment-discipline/ is only the fallback.
```

The "same reasoning as task-runner/hooks/scope.sh" above moved out of that hook on 2026-10-28: it is in rationale/derivations/plugin-task-runner.md § plugins/task-runner/hooks/scope.sh.

### One detector, two lanes

```text
One detector, two lanes. Absent event name = PostToolUse, the original behavior; a failed Bash call's PostToolUseFailure
takes the PostToolUse lane, and its envelope names the event it ran for (hev).
```

### CC_REMIND

```text
CC_REMIND is the marketplace-wide advisory switch, and the README promised it here
for two releases while nothing read it. It silences the WARN lane only: a PreToolUse
deny is not an advisory, so an env var must not be able to turn a block into a pass.
```

### Interpreter writes

```text
Interpreter writes, through the bash-write-effects block: read with the old marker, then date it, on every call this lane
sees, so an Edit's file or a command that wrote nothing never reads as the next run's write. The marker is this hook's own.
```

### Very long lines

```text
The blocks mask a line character by character, quadratic in its length: a 200 kB line, or 100 lines of 8 kB, outlasts the
timeout, so such a command's text is not parsed. The files an interpreter run changed are read from disk and still judged.
```

### CC_COMMENT_GUARD and CC_ELISION_GUARD

```text
CC_COMMENT_GUARD=off disables the DENY lane and leaves the advisory lane on.
Added 2026-09-22 (UX 1): until now the block had no off switch at all — CC_REMIND
covers the advisory only — so the refusal could name none, which is what
pc_offswitch_named reports. Read from the hook's environment, which the edit text
cannot reach. Two lanes, two switches: silencing the block keeps the finding visible.
CC_ELISION_GUARD=off turns only the elision deny into a warning, and CC_COMMENT_GUARD=off leaves that deny running.
```

### Code only; build files are code

```text
Code only. Config and prose formats use comments for navigation, which this rule
does not govern — so YAML stays OUT deliberately, including docker-compose.yml,
CI workflows and k8s manifests, where a `# the web service` header is a real
navigation aid rather than a restatement.

BUILD FILES ARE CODE, and that is why they are in. A Dockerfile and a Makefile are
imperative step lists, not documents: `# install dependencies` above
`RUN apt-get install -y …` restates its next line exactly the way `// increment the
counter` does above `counter++`, and *.sh has always been governed for that reason.
Extensionless names are matched by basename, so the worktree-stripped path is not
enough on its own — see cd_governed in hooks/paths.sh, which holds the list.
```

### Exempt paths

```text
Generated, vendored, and marketplace tooling paths are exempt: their header banners and
usage blocks are deliberate, and nobody edits them by hand for readability.

Tested against the LOGICAL path — a worktree prefix stripped — because this
marketplace places worktrees at `.claude/worktrees/<branch>`, and `*/.claude/*`
was therefore exempting every source file written by a track run. See
hooks/paths.sh. A missing lib exits 0: a path it cannot classify is not judged.
```

### scan_awk

```text
scan_awk [elision|elision-lines] reads text in the language cd_lang set; `elision` prints elision_n's count, EO and EL
instead, `elision-lines` every line elision_n would name, in its order, at most 64.
```

### split_ident

```text
camelCase and snake_case carry the same words a comment would spell out, so a name
only counts as "already says it" once it is split back into those words.
```

### op_tokens

```text
Operators say in symbols what a restating comment says in words; without this map
"// increment the counter" over "counter++" reads as new information.
```

### obody

```text
The language-blind leaders of f55e7ab4: a line they read as a comment is never a restatement target.
```

### exempt

```text
Legally required, machine-read, or tool-directive comments are not prose anyone
chose to write, so they are outside this rule entirely.
```

### doc_code

```text
A /** */ line borrows code punctuation to describe a shape: ` * Site => [server, repository, last deploy failed].` was denied
as code and a worker reshaped tuples and signatures to pass. There a line is code only with a token prose does not use (`;`,
a `$var`, `->`, a call, an `=` assignment, a control-flow header, a leading import/export/return with a brace, a trailing
`{` or `[`) and is not a period-ended sentence of 3+ lowercase words. Misses: such a sentence.
```

### is_narration

```text
The diff addressing its reviewer: a comment describing the EDIT — its author, its
correctness, the review that asked for it — rather than the code. A why-comment
states a standing constraint; a change event ("now handles", "updated to", "fix
per review") is stale the moment the change merges. Phrase cues, so warn-only.
A ticket, issue, or URL rescues the comment outright: a reference to track is the
keep-case form ("Retry cap of 5 as discussed in ADR-12"), same idiom as is_bare_todo.
```

### elision_n

```text
Counts non-doc bodies, enclosing brackets aside, that an ellipsis opens (no name glued to it) or closes and that hold,
once every ellipsis, ( ) [ ] , ; : is a space, only a listed phrase then ELIDF filler — an ELIDE phrase ("the" allowed
first) after an opening ellipsis, else an ELIDN code noun: a placeholder is never prose or documentation.
EO counts ellipsis-only bodies, EL is the first such line.
```

### str_line

```text
STR marks a line that starts inside a multi-line string: a template literal or Go raw string, a triple quote, or a
shell quote or heredoc body. SS is what is open at the line end: for TL a stack of "`" and "{" (a `${` expression),
"*" a block comment, `"""`, "<<WORD" or "<<-WORD" a heredoc. A wrong guess hides, or exposes, every line to the next delimiter.
```

### restates

```text
Every content word of the comment must already be recoverable from the code line.
Requiring ALL of them, not a ratio, is what keeps this warning credible.
```

### pads

```text
Warn-only. A tag is padding when its words come back from its own name and native type (or, for
@return and @var, the declaration below it); a non-native type, a fact word or a continued line spares it.
```

### Line 1 is machine-read

```text
Line 1 is machine-read by the shell: how many findings are in the three
BLOCKABLE categories (restatement, commented-out code, dead docblock tag).
Those are the strictest detectors here — restates() requires EVERY content
word of the comment to be recoverable from the code line, is_code() matches
syntax, and is_dead_tag() fires only when the tag description is empty or
the parameter name itself. Banners, bare TODOs and change-narration comments
stay warn-only: they are house-style calls, a TODO can be a legitimate
mid-task marker, and narration cues are phrase matches.
```

### Where CC_REMIND is named

```text
The switch is named HERE and not in "$warn": the deny below reuses that text, and
CC_REMIND does not silence a deny — naming it there would send the blocked reader
to a variable that changes nothing.
```

### PreToolUse lane: deny, bounded, the bound as precondition

```text
---- PreToolUse lane: deny the three blockable categories, at most TWICE per file ----

WHY DENY AND NOT ASK: the model wrote the comment, so the model is the right
audience for the correction. `ask` would interrupt the HUMAN for a style nit,
once per tripping edit — during a task run that is dozens of prompts about
something the human did not write and cannot usefully adjudicate.

WHY BOUNDED PER FILE: a deny the model cannot satisfy would otherwise loop.
The third attempt on the same file in the same session is allowed through,
and the PostToolUse lane warns on it instead — so a false positive costs at
most two extra turns, never a wedged session. Same bounding idea as
task-runner's one-block-per-commit completion gate. Two rather than one
because the bound is spent on the DENY, not on an observed write: when a
sibling hook denies the same call the write never lands, and a one-shot
bound was therefore consumed without the model ever seeing its own file.

THE BOUND IS THE PRECONDITION, NOT A COURTESY. Every input the bound needs —
a session id, a cwd, a hashable path, and a marker that actually landed on disk —
is checked BEFORE the deny is emitted, and any one of them missing withholds the
deny entirely. An earlier revision wrote the marker with `2>/dev/null` and ignored
the result, which meant a read-only `.claude` state dir (sealed root when cwd was
absent, a 555 checkout, a container mount) produced a deny on every attempt with
nothing recording that it had fired: precisely the unwedgeable loop this comment
promised could not happen. Blocking is only defensible while it is bounded, so a
bound that cannot be recorded means no block at all.
```

### Context key

```text
CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
subagents at all, and a subagent shares its parent's session_id while getting its
own transcript. Keying a one-shot on session_id therefore dedups the worker against
nudges only the PARENT ever saw, so the context where most fan-out code is written
is the one context this never speaks in. Pattern and rationale: hooks/conventions.sh (context-key one-shot).
```

### The payload cwd and the state root

```text
`-d` as well as `-n`: a deleted project dir came back three levels deep holding only
the `mkdir -p` of this hook's state dir below. A cwd that is gone is also nowhere to
record the bound, so it withholds the deny on the same rule as the rest of this block.
Then the state ROOT, not the cwd. This comment said the payload cwd was "where the
session STARTED"; it is the shell's cwd and follows the model's `cd` (measured
2026-09-25, rationale/2026-09-25-session-plugin-usage-review.md finding 2: app/Enums,
app/Models, then the repo root in one session). Under `<cwd>/.claude` every `cd` handed
each file a fresh DENY_CAP (scripts/__tests__/cwd-guard.test.sh replays it). The address `<root>/.claude/comment-discipline` is SHARED
with density.sh and verbosity.sh; all three moved to cc_state_root in one change
(0.23.0), because re-rooting one alone splits the bound. Does NOT catch a cwd that
exists but belongs to another checkout.
```

### The context key is hashed

```text
THE KEY IS A PATH, SO IT MUST BE HASHED BEFORE IT CAN BE A FILENAME. `.transcript_path`
is an absolute path; interpolating it raw builds `…/blocked-/Users/…/x.jsonl-<key>`,
whose parents `mkdir -p "<root>/.claude/comment-discipline"` never creates. Every write
then fails, the withhold below fires, and the deny is silently absent on every edit of
every file — the tooth reads as present in this file and is gone in every real session.
Hashed with the same cksum idiom as hooks/conventions.sh (its `seen=` line), which got
this right.
```

### Bounded retries

```text
BOUNDED RETRIES, not a one-shot. The bound is spent when this hook DENIES, but a
deny does not mean the write landed: any sibling PreToolUse hook denying the same
call (testing:protect-tests, secret-scanning/scan, command-guard, …) blocks it too,
and the old one-shot was already gone. The model then fixed the sibling's complaint,
re-wrote, and this hook was silent — the comment noise shipped. Measured 2026-09-15
with all 31 plugins installed; unreachable with this plugin alone, which is why it
survived. Two denies per file per session bounds a pathological loop exactly as the
one-shot did while surviving one co-firing deny.
```

### Atomic tries

```text
ATOMIC, because a counter file is not: a read-modify-write counter let two parallel
subagents editing one file both read 0 and both write 1, denying it more than
DENY_CAP times. Each try is a file created by bash's noclobber, which opens with
O_CREAT|O_EXCL in the shell itself. Not mkdir(1): uutils coreutils (Ubuntu 26.04's
/usr/bin/mkdir) stats first and exits 0 when its mkdir(2) loses the race, so 20
parallel calls denied 3 times in 8 of 60 rounds (measured 2026-10-07, 0.31.1).
`-e`, not `-f`: a `.dN` DIRECTORY from <=0.31.0 still counts after a mid-session
upgrade, and so does a legacy zero-byte marker from <=0.19.0, as one try.
```

### The state dir ignores itself

```text
The state dir ignores itself (0.18.3): a marker per denied file showed up as
untracked in every repo without a hand-written ignore line.
```

### Residual

```text
RESIDUAL, stated rather than hidden: the bound is spent when this hook DENIES, and a
deny does not prove the write landed. Two co-firing siblings can still exhaust both
tries on writes that never happened, and the third edit then ships unchecked. Spending
the bound only on an observed write needs a PostToolUse handshake, which is a larger
change to a guard with 55 assertions; two tries survives the measured single-sibling
case, which is the one reproduced with all 31 plugins installed.
```

### elision_state

```text
elision_state <file_path> [probe] sets edir and ekey, the state dir and the per-context, per-file key of the elision
markers; status 1 when no context, cwd or hashable path exists to keep them under, or, given probe, when this
context holds no elision-warn- marker at all, so a write that needs none skips the path hash.
```

### elision_judge

```text
elision_judge <file_path> <new text> sets msg and returns 0 when the new text holds more elision_n placeholders than
what it replaces — the existing file, never one over ELISION_MAX bytes; for an Edit both its old_string(s) and the
whole file before it — and a non-blank line of the replaced text (the file, or the old_string(s)) is gone from it.
Ignores cd_path_exempt, since code loss matters there too; the bound is the comment deny's, on its own
elision-blocked- markers. A write it lets through that still adds a placeholder — a new file (or one with no
non-blank line), an ellipsis-only body, a write past the bound, any write with the deny off — leaves the one-shot
elision-warn- marker elision_warn reads, unless CC_REMIND is off; a write whose counts did not grow, one that removes
no line, or an Edit its two comparisons disagree on, leaves none, and a denied call's are removed by emit.
Both name the first placeholder line the replaced text holds no copy of, else the first in the new text.
Misses: a placeholder trailing code on its line, a markup comment spanning lines, `// ...existing code` or `...$rest`
(glued, no closing ellipsis), an ellipsis neither opening nor closing the body (`// keep ... existing code`,
`// existing code ...;`) or bracketed (`// [...] existing code`, `// existing code (...)`), one closing it after no
code noun (`// omitted ...`), a phrase not at the body start (`// ... and the rest of the file`), one followed by
anything but filler (`// ... rest of the file is unchanged ...`, `// ... rest of the code, see git`),
any line of a doc comment (`/** */`, `///`, a docstring), a placeholder line inside a multi-line string (str_line),
an appending heredoc (never judged, so never warned),
and every line after an unbalanced backtick (a regex such as /`/g, JSX text) or a `$(( 1 << y ))` up to the next one,
or after a `/\/*` regex read as an opening block comment; a placeholder added where no line is removed; an Edit
adding a placeholder line the file already holds, and one whose new_string opens by closing a template literal, then
adds a placeholder. A replacement that removes a line can still be denied for adding placeholder-shaped text inside
a string the tracker misreads (a PHP `<<<` body, a template after `/\/*`).
Still read as comments: lines of PHP `<<<` and Ruby `<<~` heredocs, Rust raw and C# verbatim strings, Elixir and Julia
`"""`, Perl `<<EOT`, Lua `[[ ]]`, C++ `R"(`, plain multi-line strings in Rust, PHP and Ruby, and of an Edit whose
new_string starts inside a string its unchanged text opened when the file is missing, over ELISION_MAX or lacks an old_string.
```

### The whole file after an Edit; CRLF

```text
An Edit is judged on the whole file after it too, so a new_string that starts inside a string the file opened reads as text.
A CRLF file is read as LF unless an old_string carries \r, so a multi-line old_string written with LF still matches.
```

### elision_warn

```text
elision_warn <file_path> <new text> consumes the file's elision-warn- marker on any write and appends its warning to
ew. The text on disk is already the new text here, so only the PreToolUse lane can tell what the write replaced.
A marker whose placeholder line this text no longer holds — left by a write another hook denied — is dropped unsaid.
```

### emit

```text
jq builds the envelope so the message stays valid JSON whatever the comment text
contains. jq presence is guaranteed by the guard at the top of the block.
A deny also removes the elision-warn- markers this call wrote: no PostToolUse follows a refused call.
```

## plugins/code-review/hooks/verbosity.sh

### Header

```text
Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
even under a stripped PATH where `env bash` exits 127.

PostToolUse output-discipline guard (warn-only, at most ONE warning per session).
Measures how much conversational prose this session has emitted per tool call and
says so once when the session is an outlier. Silence is the overwhelmingly common
case — see the calibration below.

WHY A MEASUREMENT AND NOT A RULE: "be concise" already exists as prose in many
places and loses, because it competes against task-local instructions that are more
specific — ledgers, status tables, "report back" contracts. A rule that says the same
thing more loudly is rule N+1 and loses the same way. This hook does not add a rule.
It reports a number about THIS session that nothing else in the marketplace measures.

THE METRIC: total characters of assistant text ÷ number of assistant tool calls,
cumulative over the session transcript. High = the session is narrating relative to
how much it is doing.

CALIBRATION (measured 2026-07-28 over 1,933 local session transcripts with >=8 tool
calls; 135 main-thread, 1,798 subagent):
    main-thread   p50=155  p90=325  p95=389  p99=821  max=910
    subagent      p50=152  p90=441  p95=634  p99=1118 max=3120
The threshold is 600, which fired on 3 of 135 observed main-thread sessions (2.2%)
and on none below p95. It is set to catch outliers, not to nag the median.

SUBAGENTS ARE EXEMPT. Their p95 is 634 against the main thread's 389 because a
subagent's final text IS its return value — narration is its contract, not a defect.
Judging them by this metric would be measuring the wrong thing.

LIMITATION (honest scope — the four laws, see
.claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
  - WARN-ONLY, and PostToolUse at that: it emits `additionalContext`, which is not a
    blocking key. It cannot stop a verbose turn, only inform the ones after it.
    Stop-event delivery was considered and rejected: a Stop hook reaches the model
    only by BLOCKING (exit 2), and spending a whole extra turn to complain about
    output volume would emit more prose than it saves.
  - The metric is CUMULATIVE, so a session that narrated early stays flagged even
    after it tightens up. One warning per session bounds the cost of that.
  - Prose the USER asked for (a written report, a long explanation) counts against
    the ratio. The hook cannot tell requested prose from unrequested narration, and
    does not pretend to — which is the main reason it warns instead of blocking.
  - The threshold is calibrated on ONE machine's transcripts. It is a starting number
    with its sample stated, not a universal constant.
  - Assumes PostToolUse carries `transcript_path`. If it does not, every path here
    exits 0 and the hook is simply silent — it degrades to nothing, never to noise.
  - The ledger below is WRITE-ONLY by design: nothing reads it back automatically.
    It exists so the threshold and this hook's effect can be evaluated later against
    real data instead of re-argued. Calling it a feedback loop today would be the
    over-claim this plugin's own review flagged in `hindsight`.

FAIL-OPEN: missing jq/awk, unreadable transcript, or any error exits 0.
CC_REMIND unset: the /config option cc_remind decides.
State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/comment-discipline/ is only the fallback.
```

### Subagent transcripts

```text
Subagent transcripts are exempt (see header). Match the path, not the content.
```

### The payload cwd and the state root

```text
`-d`, not just `-n`: a session outlives the directory, and `mkdir -p` below is happy to
rebuild three levels of a project tree the user has just deleted — measured on a deleted
`work/acme/design-studio`, which came back holding nothing but this hook's state dir.

THE PAYLOAD cwd IS THE SHELL'S cwd, and it follows the model's `cd`. This header said it
was "whatever the session STARTED in" until 0.23.0, and used that to keep state at
`<cwd>/.claude/comment-discipline`. Measured false 2026-09-25
(rationale/2026-09-25-session-plugin-usage-review.md, finding 2): one session's cwd was
app/Enums, then app/Models, then the repo root; this "shown once per session" warning
fired three times, one state dir per directory, and another repo had one COMMITTED.
So state lives at cc_state_root (the block above: git toplevel, else CLAUDE_PROJECT_DIR,
else cwd). The address `<root>/.claude/comment-discipline` is SHARED with density.sh and
scan.sh, and all three moved in one change — a one-shot split across two addresses is no
one-shot at all. (conventions.sh keys its one-shot under $TMPDIR and never shared it.)
Does NOT catch: a cwd that exists but is not the project (a stale session left in a
sibling checkout) — nothing in the payload distinguishes those.
```

### Cheap path first, and the state file

```text
CHEAP PATH FIRST. This hook runs after every tool call, so the common case must
not parse the transcript. `wc -l` is one read of the file's size class, and the
state file short-circuits every call after a warning has already been spent.

State file: one line, "<lines-at-last-scan> <warned:0|1>". A scan costs one jq
pass, so it is rate-limited to once per RESCAN_EVERY new transcript lines rather
than once per session — a session that turns verbose late is still caught, while
the number of expensive passes stays bounded and small.
```

### Both bounds live in the state file

```text
BOTH BOUNDS BELOW LIVE IN THAT STATE FILE — "at most one warning per session" and
"at most one transcript scan per RESCAN_EVERY lines". If it cannot be written, the
hook has no memory: it warns on every tool call and re-scans the whole transcript
every time, which is the opposite of both promises. So writability is checked ONCE,
here, on the cheap path, before any expensive work — an unwritable state dir means
this hook does nothing at all. Same rule as the deny lane in scan.sh: a bound that
cannot be recorded is not a bound.
```

### Ledger

```text
LEDGER. Every scan is recorded, warned or not — this is the only measurement
trail any plugin in this marketplace leaves. The threshold above was calibrated
once, on one machine, from transcripts that predate this hook; without a record
of what it sees in practice, nothing could ever say whether 600 is right, or
whether the warning changed the sessions that got it. A number nobody reads back
is the failure this plugin's own review named.

Machine-local, never inside the project tree — same placement reasoning as
hindsight/hooks/collect.sh. One compact row per scan, capped so an old ledger
cannot grow without bound. Nothing reads this automatically; it is a dataset for
a future evaluation, and saying that is the honest scope.
```
