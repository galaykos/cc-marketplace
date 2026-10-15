# Shared blocks and chassis templates: the comment text moved out of the code (2026-10-04)

The text below was moved verbatim on 2026-10-04 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/templates-and-blocks.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## templates/blocks/option-resolver.md

### Banner and canonical copy

```text
--- option resolver -----------------------------------------------------------
Canonical copy: templates/blocks/option-resolver.md. Every hook defining cc_option must
carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
```

### cc_option: contract and why the shell wins

```text
cc_option <ENV_NAME> <default> [<level-file>] prints one line, the first non-empty of: the
variable ENV_NAME; the first word of <level-file>, if given and readable; the userConfig
option CLAUDE_PLUGIN_OPTION_<ENV_NAME>, true/false read as on/off; <default>. The shell wins
because the environment is the one state independently installed plugins share (CC_REMIND
or CC_BOOST there mutes every plugin at once); the option gives one plugin a /config row.
```

### cc_option: status

```text
Status 0, no stderr: a malformed name, an expansion error that exits bash 5, yields <default>.
```

### cc_option: what it does not catch

```text
WHAT IT DOES NOT CATCH: a caller passing a variable instead of a literal name, or a value
outside the switch's vocabulary — each hook still validates the value it gets.
```

## templates/blocks/state-root.md

### Banner and canonical copy

```text
--- state root ----------------------------------------------------------------
Canonical copy: templates/blocks/state-root.md. Every hook defining cc_state_root must
carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
```

### cc_state_root: the measurement and the resolution order

```text
The payload's `cwd` is the SHELL's cwd and follows the model's `cd` — measured
2026-09-25: app/Enums, then app/Models, then the repo root in one session, each leaving
its own `.claude/` state dir and each re-firing a "once per session" nudge. State lives
at the project root instead (pc_state_root refuses a raw `$cwd/.claude` path in a hook):
the git toplevel reached by walking UP from cwd (`--show-cdup`, so a symlinked /tmp keeps
the caller's spelling and path-prefix comparisons still hold); outside git,
CLAUDE_PROJECT_DIR when cwd sits under it; else cwd. A cwd that no longer exists yields
nothing and status 1 — the caller exits rather than resurrect a deleted project.
```

## templates/blocks/plugin-state.md

### Banner and canonical copy

```text
--- plugin state --------------------------------------------------------------
Canonical copy: templates/blocks/plugin-state.md. Every hook defining cc_plugin_state must
carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
```

### cc_plugin_state: contract, key and host constraint

```text
cc_plugin_state <root> <name> prints the directory holding a plugin's own per-project hook
state, <root> being the hook's cc_state_root result: ${CLAUDE_PLUGIN_DATA}/<key>/<name> when
the host sets that variable, else <root>/.claude/<name>, the path hooks used before it.
<key> is the root's basename with every character outside [A-Za-z0-9_-] turned into -, a -,
and the root's cksum: the host gives one data dir per plugin id, not per project (measured
2.1.282), and a raw path inside a filename names parents that never exist. tr runs under
LC_ALL=C because a UTF-8 tr stops at the first invalid byte. Status 0, no stderr; it
creates nothing, so the caller keeps its own mkdir -p.
```

### cc_plugin_state: why it exists

```text
WHY: state read by no one but the plugin's own hooks does not belong in the user's repo —
the 2026-09-29 review found .claude/code-review/ and .claude/skill-router/ created by one
prompt and one edit in a fresh repo.
```

### cc_plugin_state: what it does not catch

```text
WHAT IT DOES NOT CATCH: state another plugin, a skill or the user reads must not use it; the
fallback path is still in the repo; the data dir is keyed by plugin id, so install scopes of
one plugin share it (inferred from the docs' id rule), while a --plugin-dir copy gets its
own `-inline` directory and never sees the installed copy's state. The variable was measured
only in a SessionStart hook; other events are doc-stated. An event that lacks it falls back
to the repo path, which splits a writer from a reader running on another event.
```

## templates/blocks/bash-write-targets.md

### Banner and canonical copy

```text
--- bash write targets --------------------------------------------------------
Canonical copy: templates/blocks/bash-write-targets.md. Every hook defining
cc_bash_write_targets must carry this block byte-for-byte (pc_shared_blocks).
```

### cc_bash_write_targets: why it exists

```text
The host steers file writes through Bash (auto mode `bashFirst`); in one measured session
233 of 238 main-thread writes were `cat > file <<EOF`, invisible to a hook matching
Write|Edit.
```

### cc_bash_write_targets: contract

```text
Prints one target path per line, as spelled in the command (relative or absolute).
Heredoc BODIES are dropped and quoted text is masked before matching, so PHP `->`/`=>`,
HTML `>` and a sed script's `s|a|b|` never read as redirects or pipes; a here-string
(`<<<`) is not a heredoc. Catches `>`/`>>` onto a path (cat, echo, printf, any command),
`[sudo] tee [-a] <paths>`, and every file operand of `sed -i`/`-I`/`--in-place` / `perl -i`
after the script or its `-e`/`-f` arguments, never a redirect word or its target. BSD's
`-I` always takes the next word as its backup suffix; a `''` or a `.`-led word with no `/`
right after sed's bare `-i` is read as one too, unless it would be the only file.
```

### cc_bash_write_targets: what it does not catch, and what it reads too much

```text
Does NOT catch: sed/perl/tee operands after a `&` in `$(( ))` or `${ }` (it ends the command),
interpreter writes (python open(), php file_put_contents), cp/mv/install destinations,
`{ …; } > f` groups, a path held in a variable (`> "$f"` is skipped, never guessed),
a globbed operand (`sed -i … tests/*.js`: a word with `*`/`?` is dropped), a `\` line
continuation, sed/perl behind another command word (`gsed`, `/usr/bin/sed`, `env`,
`xargs`, `command`, `sudo -u x`, `find … -exec sed -i`), a digit- or `&`-led redirect onto
a file (`2> f`, `&> f`) and `>&` onto one (`cmd >& f.json`), a `-`-led sed/perl operand
with no `/` or `.` in it. Reads too much: a `-`-led perl script argument that has one.
```

### cc_bash_write_targets: caller contract

```text
The caller filters to existing files under its root.
```

## templates/blocks/bash-write-chunks.md

### Banner and canonical copy

```text
--- bash write chunks --------------------------------------------------------
Canonical copy: templates/blocks/bash-write-chunks.md. Every hook defining
cc_bash_write_chunks must carry this block byte-for-byte (pc_shared_blocks).
```

### cc_bash_write_chunks: contract and the two sources

```text
cc_bash_write_chunks <command> — what a Bash command puts INTO files: the text a content
guard reads on Bash where its Write path reads tool_input.content. Prints chunks: a line that
starts with \036 and carries the WRITER — the pipeline (split on ; && || and a `&` outside
`&>` `>&` `<&` `|&`, never inside quotes) whose targets the caller resolves with
cc_bash_write_targets — then the chunk's text lines. Two sources, and only two:
  - a heredoc BODY: the lines between `<<TERM` (`<<-`, quoted or `\`-escaped TERM too)
    and TERM; writer = the pipeline holding the `<<` (`cat > f <<EOF`,
    `cat <<EOF | tee -a f`);
  - the ARGUMENTS of an `echo`/`printf` segment, as written: the rest of the segment after
    the command word, quotes, escapes and any `> file` redirect kept (so match inside the
    text, never anchored at its start); writer = its pipeline
    (`echo "K=v" >> .env.example`, `printf '%s\n' v | tee f`).
```

### cc_bash_write_chunks: over-read, accepted

```text
A chunk whose writer names no file is dropped by the caller, so `git commit -F - <<EOF`
and `echo x | grep y` yield nothing. The body of ANY heredoc whose pipeline writes a file
is read, whatever consumes it — `python3 - <<PY > out.txt` included, where the script is
not what lands in out.txt. Accepted: the text sits in a file-writing command either
way.
```

### cc_bash_write_chunks: not read, stated

```text
NOT read, stated: a `{ echo …; } > f` group (the redirect sits on the closer, not on
the echo's pipeline); a here-string `<<<`; printf's format substitution (`printf
'K=%s' v` is read as written: the format and the argument, never the substituted
line); a quoted string or a `\` continuation spanning lines; a second heredoc opened
on one line; text in a command that a `&` inside `$(( ))` or `${ }` ends early.
```

### cc_bash_write_chunks: why mask() is duplicated

```text
mask() copies the one inside cc_bash_write_targets: the block is byte-locked and its
awk functions are not reachable from outside it.
```

## templates/blocks/bash-write-effects.md

### Banner and canonical copy

```text
--- bash write effects --------------------------------------------------------
Canonical copy: templates/blocks/bash-write-effects.md (added 2026-10-15). Every hook
defining cc_bash_effects_mark or cc_bash_write_effects must carry this block
byte-for-byte: pc_shared_blocks keys it on one ERE, so either function pasted alone
fails like an edited copy (gate-fixtures-check.sh pins both arms).
```

### Why it exists

```text
The 2026-10-13 session retro (rationale/session-retro-2026-10-13.md, Tier 1 §5): in four
sessions 40-85% of code writes went through interpreter heredocs (python3 - <<'EOF' ...
open(p, 'w') ...), a miss bash-write-targets names. Auth logic, migrations, composer.json
and a Dockerfile drew no router nudge, comment check, SQL guard or security scan; in one
session the security-review rule against a post-authentication refusal that leaks account
state was never loaded. Parsing interpreter source cannot keep up (a path in a variable,
a loop, Path.write_text, a library call), so this block reads the EFFECT instead: what
git sees changed since the hook's previous call.
```

### Contract

```text
cc_bash_effects_mark <root> <marker> — nothing unless <root>/.git exists: outside git
  there is no effect to read, and a marker there is a stray file in the user's
  directory. Makes <marker>'s directory with a `*` .gitignore when it is missing, so a
  repo-path fallback state dir stays invisible to git, then rewrites <marker> (a write,
  not touch: no fork, and a write always moves mtime).
cc_bash_write_effects <root> <marker> <command> <max> — nothing, and no git, unless
  <marker> exists and <command> holds python, php, ruby, perl or node (any version
  suffix, any directory before it), nodejs, deno, bun, cp, mv, install or patch as a
  word: after the start, whitespace, ; & | ( or a backtick, before whitespace or <. Then
  GIT_OPTIONAL_LOCKS=0 git status --porcelain -z --untracked-files=all --no-renames
  --ignore-submodules=all; each regular file bash's -nt does not call older than
  <marker> is a candidate, up to <max>; one find <candidates> -prune -newer <marker>
  prints the strictly newer ones as <root>/<path>.
Caller: read the effects with the OLD marker, then mark — on every call the hook sees,
  an Edit or a command that wrote nothing too; feed each path to the per-file logic the
  Write branch uses, deduped against cc_bash_write_targets; name the <max> constant.
```

### Where it departs from the design sketch, and why

```text
- The filter matches any interpreter word, not only a heredoc, -c/-e or a script path:
  python -m black . writes files and has none of the three. A wrong match costs one git
  status, never a wrong report — the mtime test decides what is printed.
- -nt, then find: bash 5's -nt is sub-second, macOS's bash 3.2 compares whole seconds
  (task-runner's scope.sh states the same). -nt picks a superset under either; find
  -newer, sub-second on GNU and BSD, decides. find gets at most <max> arguments, so a
  large dirty tree cannot overflow ARG_MAX, and it runs only when a candidate exists.
- GIT_OPTIONAL_LOCKS=0: a plain git status refreshes the index under index.lock, and a
  parallel agent's git add or commit then fails on the lock. The cost is the racy-index
  case under Measured.
- --no-renames: one path per entry; a staged rename reads as a delete and an add.
  --ignore-submodules=all: a submodule is a directory, never a file to route.
- One marker per hook per root, in the hook's cc_plugin_state dir, as sketched: shared by
  every hook it would be dated by the first to run and hide the effect from the rest.
  Per context was weighed and rejected: each parallel agent's Edits would read as the
  others' writes for the whole window between calls. Per root, a write is lost only when
  another context's call ends during this command's run.
- Marked where the effects are read, not in an EXIT trap: the tool has finished before
  PostToolUse runs, so the two are one time, and an adopter may own its EXIT trap.
- <max> is an argument, so each adopter names its cap where its header can state it.
```

### Measured 2026-10-15

```text
route.sh, 20 runs, median (max). The largest git repo `find / -maxdepth 6 -name .git`
found on the authoring machine: 2,786 tracked files, 75,692 on disk with ignored dirs.
  (a) ls -la && git status, no match:           13.6 ms (14.3); before: 7.5. Reading cwd
      and the state root on every call, which the marker needs.
  (b) python3 -c 'print(1)', match, no write:   18.5 ms (19.6)
  (c) a python heredoc writing three .php files, fresh context, on a /tmp clone:
      164.4 ms (169.5). One Edit of one of those files costs 73.1 ms: the run costs less
      than the three Edits it stands for; per-file routing, not detection, is the bulk.
A synthetic 100,000-file repo: (a) 13.5, (b) 50.0, (c) 191.5 ms.
Racy index: right after a clone or checkout, until a git command that may take
index.lock runs, a GIT_OPTIONAL_LOCKS=0 status re-hashes every racily clean file — (b)
127.5 ms on the clone above, raw status ~197 ms on the 100k repo. One ordinary git
status brings both back to the numbers above. An Edit costs the same as before.
```

### What it does not catch, stated

```text
- A writer named only through another word: npx prettier --write, vendor/bin/pint,
  eslint --fix, make, git apply, git stash pop, uv run.
- Gitignored outputs, a repo with no git, a file outside <root> (/tmp).
- A file written and reverted in one command, or rewritten byte-identical when clean:
  not dirty.
- mv, cp -p and cp -a destinations keep the source's mtime: reported only when that is
  newer than <marker>.
- Files past <max>, taken in git's path order, not newest first.
- The first call in a repo: no marker yet.
- PreToolUse lanes: the effect does not exist yet. testing's protect-tests, command-guard's
  config-guard, database's guard and devops's workflow-guard stay blind to it.
Reads too much: anything that changed a file since the hook's previous call — an IDE
save, a parallel agent's tool this hook does not match, a background job, everything
changed while the hook was switched off — is reported as this command's write.
Standing: the byte lock is a gate (pc_shared_blocks); behaviour is gated per adopter
harness; the over-read and the racy-index cost are recorded here, nothing reads them.
```

### Adopters (2026-10-15)

```text
skill-router route.sh (MAX_BASH_EFFECTS=8; route.test.sh case 24). Not adopted: the other
seven PostToolUse hooks carrying cc_bash_write_targets — secret-scanning scan.sh and
unicode-scan.sh, code-review density.sh, scan.sh and conventions.sh, security
write-scan.sh, task-runner scope.sh. Recount: grep -rl 'cc_bash_write_effects() {' plugins/
```

## templates/blocks/prompt-shape.md

### Banner and canonical copy

```text
--- prompt shape --------------------------------------------------------------
Canonical copy: templates/blocks/prompt-shape.md (added 2026-10-14). Every hook defining
any cc_prompt_* function must carry this block byte-for-byte: pc_shared_blocks keys the
block on the ERE cc_prompt_[a-z_]+, so a partial paste fails like an edited one. A
reminder hook includes it through the template when its manifest sets promptShape: true,
and generate.sh --check holds that copy to the block as well.
```

### Why it exists

```text
The 2026-10-13 session retro (rationale/session-retro-2026-10-13.md, Tier 1 §6; its
cross-cutting finding 7) found four UserPromptSubmit hooks each deciding "is this the
user asking for work" with their own partial filters. ask-ledger and skill-router's
route-prompt.sh carried one harness-frame prefix list and code-review's review-debt.sh a
third copy that already differed (`<task-notification` without the `>`). Only ask-ledger
cut <pasted_content> spans. The defects it closes: the tool-fit check fired on a question,
a hands-off ask and chat naming an error; taskmaster's work-shaped reminder fired on
"create PR"-shaped git chores, on verbs inside a paste, and on subagent hand-backs, where
it also armed the clarify gate.

The first cut (2026-10-14) erred toward silence, and a review the next day found the
prompts the hooks had spoken on before it and now silenced: a conjunction filling the slot
before a ship noun ("fix this and push"), an edit verb on a PR ("fix the failing PR"), a
ship noun used as a feature ("add tags", "add a branch to the store locator"), every
`?`-ended request ("can you fix the login bug?"), any object after "don't work on",
an unclosed paste tag eating the rest of the prompt, and the hand-back marker matched
mid-sentence. Each was turned toward speaking: a false nudge costs one line, a false
silence costs the nudge in the moment it exists for.
```

### Contract

```text
cc_prompt_frame <prompt> — status 0 when the prompt OPENS with <system-reminder>,
  <task-notification (attributes allowed), [SYSTEM NOTIFICATION, Stop hook feedback:,
  Another Claude session sent a message: or <agent-message, or a line opens with
  [Subagent hand-back] (after optional spaces, `*` or `_`). A real ask quoting a marker
  mid-sentence is an ask. The grep runs only when the marker is present.
cc_prompt_unpaste — stdin filter: each <pasted_content …>…</pasted_content …> span
  goes, text on the tag's own line stays, a line left blank by a cut is dropped. An
  opening tag with no closing tag anywhere after it is cut alone (to its `>`), and the
  text after it stays; without a `>` the line stays as it was.
cc_prompt_ship_only <text> <verb-ERE> — status 0 when the text has at least one
  <verb-ERE> match and every match is create, add, open or make governing a ship noun:
  the verb, any of a fixed list of determiners and modifiers (a, the, new, draft,
  feature, release…), at most one other word, then the noun, ended by punctuation, the
  end, a joined name, or a joining word (for, to, from, into, named…). `and`, `then`
  and `&` are turned into `;` first, so a conjunction is never the word before a noun.
  PR, pull request and commit are ship nouns always; branch, push, merge, tag and
  release only when the text also names a PR, pull request, commit or `git`, a joined
  name sits beside the noun, or feature/hotfix/release precedes it.
  A hyphen-, slash-, dot- or underscore-joined token is one word with no verb in it.
cc_prompt_question <text> — status 0 when the text ends in `?` and holds no request
  (can/could/would/will you|u|we, please, why is|are|was|were|does|do|did), or holds
  "don't (start) work(ing) on anything|it|this|that" before punctuation, the end, yet,
  for now, until or before; "don't <making verb> anything yet|for now|until|before";
  or is, whole, "(please) don't <making verb> anything".
```

### What it does not catch, stated

```text
- frame: a harness frame under any other prefix is a human turn.
- unpaste: a name or verb that appears only inside a paste no longer counts.
- ship_only: a feature-sense branch/tag/merge/release in a prompt that also names a
  PR or commit reads as ship ("create the PR and add tags to the post" is silenced).
  Every other miss errs toward speaking: "create a new branch" (no git context), "fix
  the failing PR" (an edit verb), "write a commit message", a branch name holding a
  verb spelled as separate words (the verb counts), "create and add a PR" (each verb
  needs its own noun).
- question: whole-prompt, so a trailing question without a request form hides an
  imperative before it ("fix it, ok?"), and an incident question with no `why` waits
  ("what's causing the 500s?"); a polite question with no work in it ("could you
  explain this?") reaches the adopter's work test and stays silent only if that test
  does. "don't touch the API", "do not work on the legacy importer" and "don't change
  anything in vendor/" are constraints, not hands-off, and so is "fix it, don't change
  anything else".
- Nothing here judges intent. Standing: the shapes are gated by each adopter's harness
  (ask-ledger ledger-hook.test.sh, scripts/smoke/prompt-route-tests.sh,
  review-debt.test.sh, scripts/smoke/hook-guard-tests.sh); the byte lock by
  pc_shared_blocks and generate.sh --check.
```

### Adopters (2026-10-14)

```text
ask-ledger ledger.sh: frame, unpaste. skill-router route-prompt.sh: frame, question (the
tool-fit check only). code-review review-debt.sh: frame (ship detection skips frames).
taskmaster remind.sh via promptShape: frame, unpaste, ship_only. Not adopted: candor's
preamble and the approaches, debugging and api-design reminder hooks, which set
promptShape to adopt it; review-debt's auth-surface pattern is a path regex inside
review-debt.sh, so taskmaster's reminder cannot reach it without a cross-plugin call.
```

## templates/blocks/heredoc-bodies.md

### Banner and canonical copy

```text
--- heredoc bodies ------------------------------------------------------------
Canonical copy: templates/blocks/heredoc-bodies.md. Every hook defining
cc_strip_heredoc_bodies must carry this block byte-for-byte (pc_shared_blocks).
```

### cc_strip_heredoc_bodies: why it exists

```text
Five hooks dropped heredoc bodies before reading a command, with two scanners. command-guard's
destructive-guard.sh had a quote-aware scan, built when a 21 KB `python3 - <<'EOF'` took
22.6 s against the hook's 15 s timeout (0.8.5). A one-line awk was copied into testing
protect-tests.sh, security write-scan.sh, git-workflow merge-checks.sh and code-review
paths.sh. That awk opened a body at a `<<` inside quotes or after a `#`, read one heredoc per
line, cut a delimiter at its first non-word character (`<<END-X` never closed) and dropped an
unterminated body to the end of the command. code-review made up for it with a "loose"
fallback that counted every `cd` once a `<<` sat in quotes. The block is command-guard's scan
with its reader test made a mode, so a fix to it reaches every adopter (2026-10-15).
```

### cc_strip_heredoc_bodies: contract

```text
cc_strip_heredoc_bodies <mode> <command> [<reader ERE>] prints the command without the bodies
the scan can place; a terminator goes with its body and the opener line stays.
  - all: drop every placed body. For a caller that reads the command for a word (a cd test, a
    `gh pr merge` match), where a body is text whatever reads it.
  - inert (any word other than all): keep a body a reader may run. The reader is named on
    the opener's line (a shell, ssh, su, eval, exec, source, `.`, or the caller's ERE, tested
    on that line lowercased, unquoted, `<>|;&()` spaced out and space-padded) or sits off the
    line (the header lists the shapes). For a guard that judges what runs.
The ERE reaches awk through the environment, not `awk -v`, which would process the
backslashes in it. Both modes keep every line after a `<<` the scan cannot place, and they
keep a body with no terminator. Keeping is the direction every adopter is safe in: more
command text means a guard reads more and a cd test skips more relative targets.
```

### cc_strip_heredoc_bodies: what it does not catch

```text
inert drops a body fed to anything not named (python3 -, node, sudo -s, at, a function, alias
or coproc) and a body written to a script a later line runs. all drops a body a shell runs
(`bash <<EOF`), by contract. A case pattern's `)` inside `$( )` closes the substitution early
for the scan. A huge kept body is still slow for a caller that judges it line by line.
```

### Adopters and measured verdict changes (2026-10-15)

```text
Measured on 2,611 distinct `<<` Bash commands from local session transcripts plus 24
hand-written edge shapes, each old scanner against the block:
  - command-guard destructive-guard.sh, inert with SQL_CLIENT_RE: output identical on every
    command. 20 KB / 7-heredoc command 350-359 ms (old 348-351), `git status && ls -la`
    median 25.9-26.2 ms over 20 runs (old 26.3-26.6).
  - testing protect-tests.sh and security write-scan.sh, all, cd test: no change on the
    transcripts. On the hand-written shapes a cd after a quoted, commented, backticked,
    escaped or arithmetic `<<`, or in a body whose terminator is indented, blank-padded or
    missing, now counts (relative targets skipped). A cd in the body of a second heredoc on
    one line no longer counts.
  - code-review paths.sh cd_has_cd, all: the loose fallback is gone, because the block keeps
    the lines it guarded. 2 transcript commands with a cd inside a single-quoted argument and
    a real heredoc later now read as holding no cd.
  - git-workflow merge-checks.sh, all: 3 transcript commands, all from sessions building
    merge-checks itself, are no longer silent. Each had a `gh pr merge` line inside a
    multi-line quoted string after a quoted `<<`, which the awk had wrongly opened as a body.
    The same rule now reads a real merge on a line after a quoted `<<`, which the awk hid.
Every adopter's harness passed unchanged.
Not adopted: skill-router route.sh route_cmd_mask, which blanks bodies and masks quotes in
one pass for the command rows. code-review's file-content heredoc tracking (scan.sh,
paths.sh cd_classify), which reads a shell FILE's comments, not a command. The body skipping
inside bash-write-targets and bash-write-chunks, which are byte-locked blocks of their own.
```

## templates/blocks/phase-guard.md

### Banner

```text
--- phase guard -------------------------------------------------------------
```

### Why the block file is named .md

```text
NOTE ON THE EXTENSION: this block is shell, not markdown. It is named .md because
template-engine.sh:50 hardcodes `<blocksdir>/<name>.md` for every include directive.
Teaching the engine other extensions is a change to a gated shared component and
is not worth it for one file — the engine only ever copies raw bytes.
```

### No directive in the block's comments

```text
Do NOT write a literal include or substitution directive in this file's comments:
includes are expanded once and not rescanned, but substitution runs over the whole
rendered text afterwards, so a directive quoted here becomes a missing-key error.
```

### cc_phase_guard: why the sentinel only narrows

```text
Stand down when the arc is in a phase this artifact does not own. The sentinel
only ever NARROWS: absent, foreign, stale or malformed all mean "everyone is
eligible", which is byte-for-byte today's behaviour. That is deliberate — the
plain-prompt path is the overwhelming case and must not change, so turn-taking
engages only once an entry command has actually declared a phase.
```

### cc_phase_guard: where the sentinel lives

```text
WHERE IT LIVES: <state root>/.claude/cc-phase.json, the root cc_state_root resolves
from the payload cwd. That function comes from the state-root block
(templates/blocks/state-root.md), which the reminder template includes just above
this one; a hand copy of this guard must paste it too, or the call fails and the
guard proceeds as if no sentinel existed. It read `<payload cwd>/.claude/` until
2026-09-25, and the payload cwd follows the model's `cd` (finding 2 of
rationale/2026-09-25-session-plugin-usage-review.md): a sentinel written at the root
was absent to a hook whose cwd had drifted into a subdirectory, and absent means
proceed. taskmaster/scripts/phase-sentinel.sh writes at the same root, so writer and
reader agree from any directory of the project.
```

### cc_phase_guard: reader contract

```text
Reader contract, in order:
  absent .............. proceed (no sentinel, no turns)
  jq missing .......... proceed (fail open, as every hook here does)
  unparseable ......... proceed
  session_id differs .. proceed (several sessions share one .claude/ dir)
  older than TTL ...... proceed, and unlink — a run that died mid-way must not
                        mute this project's channel in every future session.
                        The cited precedent .claude/task-runner/active-run.json
                        is cleared by a MODEL INSTRUCTION, which is why
                        candor's gate.sh (clause 4) says of it "Nothing clears it";
                        that gate survives only because it SPEAKS when it
                        blocks. A silent reader has no such remedy, so the TTL
                        is the whole of this one's safety.
  phase == our lane ... proceed
  lane is `any` ....... proceed (guards are not phase steps)
  otherwise ........... stand down, silently
```

### cc_phase_guard: why the TTL is short

```text
TTL is deliberately SHORT. Expiring early degrades to the status quo (the nudge
fires when it maybe should not); expiring late mutes a real channel. Those costs
are not symmetric, so this errs toward speaking.
```

### cc_phase_guard: how often it engages

```text
HOW OFTEN THIS ACTUALLY ENGAGES — state it plainly, because the answer is "less
often than the word turn-taking suggests". Four commands write a sentinel:
taskmaster:task (shape), task-runner:run (build), git-workflow:finish (ship), and
code-architecture:coding-task on its `trivial` verdict (build). A BARE PROMPT writes
none. So on the plain-prompt path — which this design's own notes call the
overwhelming case — no phase exists, every voice stays eligible, and what arbitrates
is the rank tiebreak, not the arc. That is collision-avoidance, not turn-taking.
Turn-taking engages once work enters through a command that declares a phase.

This is a real limit, not a defect to route around: nothing can observe "the arc"
without something declaring it, and inferring a phase from prompt text would be the
routing-table-in-shell that route-prompt.sh's own header refuses. The honest claim is
the narrow one — say the guard engages on the pipeline path, never that the
marketplace takes turns everywhere.
```

### cc_phase_guard: standing

```text
Standing: the GATE (pc_phase_guard) proves a hook READS the sentinel. No gate
can prove an artifact HONOURS it in every branch — that half is agent-graded.
```

### cc_phase_now: why it is published

```text
Also publishes cc_phase_now — the phase in force, or empty. The rank marker key
includes it, which is what lets a voice that stood down at one phase
claim a FRESH key and speak when its own phase arrives. Without it a rank claim
written on turn 1 outlives the eligibility that produced it and permanently gags
whichever hook is later the highest ELIGIBLE one.
```

### cc_phase_guard: why staleness is read from mtime

```text
Stale? mtime, not started_at — no ISO-8601 parsing in portable shell, and the
file is rewritten whenever the phase changes, so mtime IS the phase's age.
```

### cc_phase_guard: why the session test is nested ifs

```text
Nested ifs: a conjunction of two bracket tests here once tripped
chassis-template-tests.sh's "hook(plain): no extraGuard when null" assertion,
then a substring match over the whole rendered file. Since 2026-09-25 it pins the
trigger line instead — the state-root block carries that shape legitimately — so
the nesting is no longer load-bearing. It stays; it reads the same either way.
```

### cc_phase_guard: why it reads its own lane.tsv

```text
Our own lane, read from the plugin's OWN lane.tsv — never a sibling's, so this
works when the plugin is installed alone (spec S2b).
```

### cc_phase_guard: why phases are compared by position

```text
ORDERED, not equal. Exact equality was the first cut and it was a global mute: the
phases COMMANDS write (shape, build, ship) and the phases ADVISORIES declare
(understand, decide) are disjoint sets, so `want = have` was unreachable and every
phase-owning voice stood down whenever any sentinel existed. Only `any` lanes spoke.
The two vocabularies are disjoint for a real reason — "what phase is this command"
and "what phase does this advice belong to" are different questions — so the fix is
to compare position, not string.

An advisory speaks while the arc is AT or BEFORE its phase, and stands down once the
arc has moved PAST it. Clarify-the-requirements is useful at understand and shape; on
turn 40 of an executing build it is the defect this guard exists to kill.
```

### Closing banner

```text
--- end phase guard ---------------------------------------------------------
```

## templates/reminder-hook.sh.tmpl

### Off switch

```text
OFF SWITCH. CC_REMIND=off silences every reminder hook in the marketplace —
the reminder twin of the boost hooks' CC_BOOST. Environment is the one state
independently-installed plugins genuinely share. The cc_remind option in /config
silences only this plugin's reminder hooks; a set CC_REMIND still wins over it.
```

### Trigger narrowing

```text
TRIGGER NARROWING (the boost hooks' C17 pattern, applied to reminders). The
keyword used to be grepped from the WHOLE prompt, so a pasted transcript, a
task notification, or a request to change the hook itself fired the nudge.
In order: drop fenced code and backticked spans; read only the head of the
prompt (a pasted log buries its keywords deep); refuse prompts that are
ABOUT the reminder machinery; refuse this hook's own output echoed back.
LIMITATION (honest scope): heuristic, not parsing — an unquoted keyword in
the head still fires, a real request past the head no longer does.
CC_REMIND=off is the reliable control, this is the cheap one.
```

### is_about_hooks: why the noun must start a word

```text
The noun must START a word: `[ -]` before it, or the verb abutting it directly.
Without that separator `fix the webhook handler` matched `...web`+`hook` and
silently disarmed the nudge on any webhook/API prompt — measured 2026-09-15.
```

### is_own_echo

```text
own suggestion quoted back = transcript, not intent
```

### is_question_only: question-shaped prompts

```text
QUESTION-SHAPED PROMPTS (misfire regression, live transcript 2026-08-25). The
trigger is a bare verb list matched anywhere in the head, so "can I BUILD a
tool on Claude Code?" and "if we needed to BUILD from scratch, what would you
do?" both scored as work-shaped. Asking WHETHER to do the work is not asking
for it, and a clarify nudge on a question is pure noise: the deliverable is
prose, and there is no edit for the nudge to sit in front of.

CLAUSE-LEVEL, not prompt-level, because one prompt can do both ("that looks
wrong. fix the parser"). Split the head into clauses, keep only those actually
carrying the trigger, and stand down only when EVERY one of them is
interrogative — a clause counts as interrogative when it ended in `?` or opens
with a question word. A single imperative trigger clause is enough to speak.

LIMITATION (honest scope): heuristic, not parsing. "how do I add caching?" is
refused even though the user may well want it built; the nudge returns on their
next, imperative, prompt. A delayed nudge is the cheaper error than a false one,
and CC_REMIND=off remains the reliable control.
```

### Turn-taking

```text
TURN-TAKING. Evaluated only after the prompt already matched this
hook's own trigger, so an out-of-phase artifact costs one lane.tsv read and
nothing else. sid is needed by the guard's session check, so resolve it first.
```

### claim_rank and best_rank: monotonic precedence, flat markers, the phase key

```text
MONOTONIC PRECEDENCE. Rank arbitrates only between hooks that
share a phase; the phase sentinel does the real turn-taking. Guaranteed:
among hooks eligible THIS TURN, the best rank always speaks, in every
invocation order. NOT guaranteed: exactly one line — a worse-ranked sibling
that reads before its better-ranked peer claims will also print. Output is
bounded at one line per eligible hook. Claiming determinism here would be an
over-claim; hooks launch in parallel and single-voice needs a settle window,
which would cost latency on every prompt.

Markers are FLAT (cc-remind-<key>-rank-<NN>), never nested under a per-key
directory. Nested claims fail ENOENT without an -p, so no hook would ever
yield and ALL would print; and the shipped sweep below uses rmdir with
-maxdepth 1, which can neither remove a non-empty directory nor descend into
it, so every prompt would leak a marker forever and each leak is a permanent
gag. Flat markers are cleaned by that same sweep unchanged.

The key carries the PHASE, so a voice that stood down earlier gets a fresh
claim namespace when its own phase arrives instead of meeting a stale claim.
```

### The clarify-gate marker: a cross-plugin signal

```text
CROSS-PLUGIN SIGNAL, deliberately outside the yield decision. This marker is
the sole producer for taskmaster's optional clarify gate (PreToolUse, off by
default); it must be dropped whenever this hook's trigger matched, even if a
better-ranked sibling speaks instead, or retiring the old budgetExempt branch
would silently disarm that gate for everyone who set CC_CLARIFY_GATE=block.
Gated on an explicit manifest flag, not on rank, so exactly one plugin arms
it — making it unconditional would widen a deny gate's trigger to five hooks.
```

## templates/boost-hook.sh.tmpl

### Off switch

```text
OFF SWITCH. CC_BOOST=off disables every boost hook in the marketplace;
{{envVar}}=off disables this one. Environment is the only state three
independently-installed plugins genuinely share, so this works cross-plugin
even though a co-activation GUARD does not (see the skill's residual note).
Either switch's option in /config silences only this plugin's boost hook; a set
environment variable still wins over the option.
```

### Trigger narrowing

```text
TRIGGER NARROWING. The token used to be grepped from the WHOLE prompt, so a
pasted log, a quoted transcript, or the sentence "don't use <token> here"
injected the directive — before the model could read the skill's claim that
such a mention is inert. Three narrowings, in order:
  1. drop fenced code blocks and inline backticked spans (quoted text)
  2. only look at the first 200 characters — a real invocation is typed at
     the top of the prompt; a pasted log buries the token deep
  3. do not fire when the token is negated
LIMITATION (honest scope): heuristic, not parsing. It converts "any mention
anywhere fires the boost" into "a mention that reads like an invocation
fires it". A quotation in the first 200 chars with no negation still fires,
and an invocation past 200 chars no longer does — the off switch above is
the reliable control, this is the cheap one.
```

### Self-echo: why the boost tokens are enumerated

```text
  4. do not fire on this hook's OWN output echoed back. The injected directive
     opens "ULTRA-<X> ACTIVE"; a prompt quoting that is a transcript paste, not
     an invocation. Catching the self-echo is worth a line because the commonest
     way a boost banner reaches a prompt is a previous run's output.
     The boost tokens are ENUMERATED here, not `ultra-?[a-z]+`: the loose form
     also matched Claude Code's own vocabulary, so "ultracode active — now
     <token> X" (and "ultrathink active, …") silently suppressed the boost the
     user had just typed. Regression cases: scripts/smoke/hook-guard-tests.sh.
     This list is shared by every boost hook the chassis renders — a new boost
     token is added HERE, in the template, or the sibling hooks will not
     recognise its banner and will fire on a pasted one.
```

### Why a quoted heredoc

```text
The directive is emitted through a quoted heredoc: no expansion, so the
manifest text is the wire text — backticks, quotes and $ are all literal.
```
