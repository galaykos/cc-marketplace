# Shared blocks and chassis templates: the comment text moved out of the code (2026-10-04, 2026-10-28)

The text below was moved verbatim on 2026-10-04 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/templates-and-blocks.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

The second move, on 2026-10-28, held each block to its first line, its pointer line, each function's contract and one line per trap, and each chassis template to a header of at most three lines (the `generated from` line, what the hook does and misses, the pointer). Its text is every `### Moved 2026-10-28` below: the lines as they stood, with the `# ` leader and the indentation before it removed, each introduced by where it sat; the file kept the one-line form named there, or nothing. Every paste of a changed block was rewritten byte-for-byte in the same change.

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

### Moved 2026-10-28

Between the `The host exports only SAVED options` line and the `Misses:` line; nothing kept in its place, since the contract above it already orders the variable before the option:

```text
A non-empty variable beats the option: the environment is shared, so one export before launch
switches every plugin that reads it.
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

### Moved 2026-10-28

Below the contract; kept as one line, ``A backup suffix is never a target: the word after BSD sed's -I, or a `''` or `.`-led word after a bare sed -i unless it is the only file.``:

```text
BSD sed's -I always takes the next word as its backup suffix, so that word is never a target; after a bare sed -i,
a `''` or `.`-led word is read as one too, unless it would be the only file.
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
cc_bash_effects_mark <root> <marker> <session> — nothing unless <root>/.git exists:
  outside git there is no effect to read, and a marker there is a stray file in the
  user's directory. Makes <marker>'s directory when it is missing and gives it a `*`
  .gitignore whenever it has none, so a repo-path fallback state dir stays invisible to
  git even when another hook of the plugin made the dir first; then rewrites <marker>
  with the cksum of <session> (a write, not touch: a write always moves mtime).
cc_bash_write_effects <root> <marker> <command> <max> <session> — nothing, and no git,
  unless <marker> exists, <root> is not $HOME, <command> holds python, php, ruby, perl or
  node (any version suffix, any directory before it), nodejs, deno, bun, cp, mv, install
  or patch as a word (after the start, whitespace, ; & | ( or a backtick; before
  whitespace, ; & | ) a backtick, < or >, or at the end), and <marker> holds the cksum of
  <session>. Then nothing when git config status.showUntrackedFiles is no (false, off,
  0). Else, in <root>: GIT_OPTIONAL_LOCKS=0 git status --porcelain -z
  --untracked-files=all --no-renames --ignore-submodules=all, each path led by ./,
  through one xargs -0 find … -prune -newer <marker> -type f, capped by head -n <max>,
  printed as <root>/<path>. The regex runs under LC_ALL=C.
Caller: read the effects with the OLD marker, then mark — on every call the hook sees,
  an Edit or a command that wrote nothing too; pass the payload's session_id to both;
  register the hook on PostToolUseFailure for Bash as well and answer in that event's
  envelope; feed each path to the per-file logic the Write branch uses, deduped against
  cc_bash_write_targets; name the <max> constant.
```

### Where it departs from the design sketch, and why

```text
- The filter matches any interpreter word, not only a heredoc, -c/-e or a script path:
  python -m black . writes files and has none of the three. A wrong match costs one git
  status, never a wrong report — the mtime test decides what is printed.
- One find over git's whole list, capped after it. The first cut walked the list in a
  bash `read -d ''` loop, a byte per syscall, testing each path with -f and -nt before
  the cap: 30,000 untracked files cost 325 ms a hook, eight hooks a call (2026-10-15
  range review B8/E5). tr|sed|tr strips git's `XY ` prefix without a loop (sed -z is
  GNU-only); xargs splits the list under ARG_MAX; find -newer, sub-second on GNU and
  BSD, decides alone, so macOS bash 3.2's whole-second -nt no longer admits the previous
  call's file to a cap slot. The ./ lead keeps a path named -delete a path: find reads
  a leading - as an expression.
- LC_ALL=C around the regex: in a UTF-8 locale glibc's matcher is quadratic on a long
  token with no separator, and `echo '<150 kB base64>' | base64 -d > logo.png` cost
  scan.sh 244 ms where it cost 14 (2026-10-15 range review E3).
- The marker holds the session's cksum, and another session's marker reads as none: a
  marker that outlived its session read the user's overnight edits as the next
  session's first run (B4/E2, measured with an AWS key id and an eval() in an IDE
  edit). Stored as a cksum, the form pc_marker_key asks of a key that reaches a path;
  session_id, not transcript_path, so a session's subagents share one window. Cost: the
  first call of each session that reaches the hook reads nothing, and two sessions in
  one repo at once read nothing whenever the other session's call came last.
- No read when <root> is $HOME or status.showUntrackedFiles is no: a session in a
  non-git folder under a dotfiles $HOME took $HOME for its root, and
  --untracked-files=all overrode the config there: 150,000 files, 1.5 s a hook, and
  the session's own transcript under .claude/projects reported as written (E4).
- No path filter: plugin state stays out by its dir's `*` .gitignore. The first cut of
  the B7 fix (a sibling plugin's fresh marker read as the command's write) also dropped
  every path under a .claude/ dir, which hid tracked, user-authored .claude/settings.json,
  .claude/skills/** and .claude/agents/** from secret-scanning, security and the scope
  lock: python3 -c writing an API key into a tracked settings.json drew no warning
  (2026-10-15 Tier 2 review B8). route.sh and code-review's comment hooks still skip
  .claude/ by their own target rule, as they do for a Write. cc_bash_effects_mark gives
  each marker dir the .gitignore on every call. On 2026-10-15 every hooks.json hook,
  fired with CLAUDE_PLUGIN_DATA unset in a scratch repo through a prompt, Edits, python
  Bash calls (Pre, Post, PostToolUseFailure), Stop, Session and Subagent events, left no
  .claude/ path in git status: candor, code-review, comment-discipline, secret-scanning,
  security, skill-router, testing and ui-ux state dirs each carried one. Read, not run
  (no active run, no mod host): task-runner's, overseer's and prompt-coach's dirs are
  written with one.
- PostToolUseFailure: a Bash command that exits non-zero fires that event and not
  PostToolUse (the range review's live probe, CLI 2.1.300; the binary builds its payload
  from the same base as PostToolUse's, so it carries tool_input, session_id,
  transcript_path and cwd — read from the 2.1.293–2.1.300 binaries, 2.1.291 not on disk). An adopter registered on PostToolUse alone read
  nothing for it, and the next call re-dated the marker past its writes (B1). The
  envelope must name the event it ran for: the host rejects a hookEventName mismatch.
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

Second round, same day (range review fixes), 20 runs, median (max), before → after, on
a synthetic 2,786-file repo (the work repo above was not cloned again):
  (a) route.sh 11.4 (11.7) → 12.8 (13.0); every adopter +1.2 to +1.7 ms, the cksum
      the marker now holds. PreToolUse lanes unchanged.
  (b) route.sh 18.2 (19.3) → 22.8 (25.1); every adopter +4.2 to +5.3 ms: the
      showUntrackedFiles read and the tr|sed|tr|xargs|find|head pipeline.
  30,000 untracked files, no write: route.sh 281.1 → 51.5 ms, scan.sh 282.3 → 57.1.
  echo '<150 kB base64>' | base64 -d > logo.png, no match: scan.sh 244.1 → 21.2,
  density.sh 242.8 → 21.0, route.sh 419.4 → 198.7 (the rest is bash-write-targets'
  mask), write-scan.sh 432.7 → 210.6, unicode-scan.sh 416.9 → 207.9. A 1 MB token
  through route.sh: 15 s → 115 ms (route.test.sh case 25 bounds it at 3 s).
```

### What it does not catch, stated

```text
- A writer named only through another word: npx prettier --write, vendor/bin/pint,
  eslint --fix, make, git apply, git stash pop, uv run.
- Gitignored outputs, a repo with no git, a file outside <root> (/tmp), a file in a
  submodule.
- A root that is $HOME, or a repo with status.showUntrackedFiles=no: nothing at all.
- A file written and reverted in one command, or rewritten byte-identical when clean:
  not dirty; a file written and committed, or staged and committed, in one command.
- mv, cp -p and cp -a destinations keep the source's mtime: reported only when that is
  newer than <marker>.
- Files past <max>, taken in git's path order, not newest first. The cap counts files
  before the caller's own filters (its file types, its scope exemptions), so a changed
  file the caller skips can take the slot of one it would judge.
- The first call of each session that reaches the hook (no marker, or another
  session's); with two sessions in one repo at once, any call after the other
  session's.
- A run_in_background command: the hook runs at its launch, before its writes. The next
  matching Bash call reads them as its own; any other call first dates them away.
- A path with a newline in its name.
- PreToolUse lanes: the effect does not exist yet. testing's protect-tests, command-guard's
  config-guard, database's guard and devops's workflow-guard stay blind to it.
Reads too much: anything that changed a file since the hook's previous call in the
session — an IDE save, a parallel agent's tool this hook does not match, a watcher or
a job, everything changed while the hook was switched off, a state file another tool
keeps under .claude/ without a .gitignore (the host's .claude/settings.local.json where
its own ignore rule is absent, written when a permission is granted) — is reported as
this command's write. task-runner's scope.sh says so in its warning for such a path and
never tells the agent to revert it.
Standing: the byte lock is a gate (pc_shared_blocks); behaviour is gated per adopter
harness; the over-read and the racy-index cost are recorded here, nothing reads them.
```

### Adopters (2026-10-15)

```text
All eight PostToolUse hooks carrying cc_bash_write_targets, each also registered on
PostToolUseFailure for Bash: skill-router route.sh (route.test.sh cases 24 and 25),
task-runner scope.sh (a marker older than active-run.json reads nothing, so a new run
does not inherit the gap between runs; a path only the effects found is worded as
"changed since the previous tool call", may not be this command's, never "revert this
edit"), code-review density.sh
(judged only when the file holds more prose than its HEAD copy), scan.sh and
conventions.sh, security write-scan.sh, secret-scanning unicode-scan.sh and scan.sh (a
new warn-only PostToolUse lane; its Pre lane cannot see an effect). Content scanners
judge the `+` lines against HEAD, or the whole file when HEAD lacks it. The four
PreToolUse-only guards (testing protect-tests, command-guard config-guard, database
guard, devops workflow-guard) cannot judge an effect before it happens and do not adopt.
Recount: grep -rl 'cc_bash_write_effects() {' plugins/
```

### Moved 2026-10-28

The first three contract lines; the clause after `read <marker>` left, and the contract around it stayed, rewrapped:

```text
cc_bash_effects_mark <root> <marker> <session> rewrites <marker> to hold <session>'s cksum when <root> holds a .git, and gives its
directory a `*` .gitignore when it has none. Call it on EVERY call the hook sees (Write, Edit, Bash, a failed Bash too), after
cc_bash_write_effects read <marker>: the tool has finished when the hook runs, so <marker> then post-dates every write of that call.
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

A second review (2026-10-15) found more of the same: `?`-ended requests with no listed
request form ("why isn't the build passing…?", "is it possible to add…?", "can someone
look?"), a hands-off clause beside the work it constrains ("Refactor the importer, but
don't touch anything yet in the exporter"), and a ship noun as the object of feature work
("add PRs to the dashboard"). The fix narrows when the test may silence instead of listing
more phrases: the question test takes an ERE from its adopter and stays out of the way
of any prompt matching it, and a ship phrase no longer ends at to, into, onto or with.

A scheduled wakeup (2026-10-15) was still read as the user's work. In the retro's six
scheduled fires (two sessions), every prompt was text the model had passed to
ScheduleWakeup itself as a fallback ("check whether the agents finished; then build…"),
and taskmaster's reminder spoke on all three fires of one of them. Read from CLI 2.1.300: a dynamic
/loop passes the user's /loop text back as the prompt, or the sentinel
<<autonomous-loop-dynamic>>, which the host expands BEFORE the hook into text opening
"# Autonomous loop check" (first fire) or "# Autonomous loop tick", and a loop.md loop
into "# /loop tick — …". The UserPromptSubmit payload carries no origin field (session_id,
transcript_path, cwd, prompt_id, permission_mode, agent_*, effort, prompt, session_title).
The transcript's scheduled_task_fire entry is no help either: the hook started 12-28 ms
after the fire in all three measured fires, and the host batches transcript writes at
100 ms. What IS on disk is the call that scheduled the prompt, at least 60 s older (the
tool clamps delays to 60-3600 s), so cc_prompt_scheduled matches the prompt to a
ScheduleWakeup or CronCreate call in the transcript. It found all six fires in their
transcripts, including the 1,136 lines written before the first one, in 5-7 ms on a 10 MB
file, and none of the typed prompts.
Silence is the decision because the first firing was already silent: the user typed
`/loop …`, a slash command every adopter skips, so speaking on the re-fire nudges about an
ask that never drew the nudge, on a turn the host's own preamble says runs "while the user
is away". review-debt does not call it: a re-fired prompt that says push still gets its
ship line, because a push nobody is watching is the one most worth a review.

The auth half of V-20 (2026-10-15): a session took taskmaster's "state why this is
trivial" skip on a prompt disabling registration, and review found the invite dead-end it
left. The words review-debt already read on changed paths moved into the block as
cc_prompt_auth_surface, so taskmaster's reminder reads the same list on the prompt and
pc_shared_blocks keeps the two from drifting. The list gained registration and sign-up:
without them it would have missed the one measured case.

The third review (2026-10-15, Tier 2) found three over-reads. The hands-off test checked
what was left beside the clause for any strong-tier word, nouns included, so "I got a
question about the deploy, don't work on it" fired skill-router's 1,759-byte check; a
match there now counts only when it opens a clause or follows to, please, a modal or a
conjunction (`the deploy` is a noun, `then deploy` an ask). On a corpus written for this
fix (8 hands-off questions, 13 hands-off prompts carrying work), the old test fired on
7 of 8 questions and the new one on none; all 13 work prompts fire under both.
Unanchored `sign[-_ ]?up` matched DesignUpdatesController and AssignUploadsToFolder; on
paths it now needs a non-letter before it or a capital S (UserSignUpController). On this
repository's ~1,160 tracked paths the path list's 90 matches did not change; it holds no
application code, so that shows only that the rewrite from grep to awk kept the words.
On prompts the path words withheld taskmaster's skip on every near miss the review tried
("design tokens", "session retro", "guard clause", "max tokens"), so prompts read their
own word-anchored list, cc_prompt_auth_ask: no bare session, token, guard or crypt; add
account, invite, csrf, 2FA/MFA/SSO/SAML, JWT, api/access/refresh/reset tokens and keys,
session cookies, logged-in and sign-in; a camelCase name is split first (handleLogin).
On a synthetic corpus of 33 auth asks and 42 near misses, written for this fix rather than
sampled from sessions (so it favours the words it was written beside), the path list
matched 22/33 and 29/42 and the prompt list 33/33 and 12/42. A reviewer's own
measurement on a different corpus found 16/17 and 6/35 for its candidate list.
```

### Contract

```text
cc_prompt_frame <prompt> — status 0 when the prompt OPENS with <system-reminder>,
  <task-notification (attributes allowed), [SYSTEM NOTIFICATION, Stop hook feedback:,
  Another Claude session sent a message: or <agent-message, or a line opens with
  [Subagent hand-back] (after optional spaces, `*` or `_`), or opens as a host /loop
  tick: "# Autonomous loop check", "# Autonomous loop tick" or "# /loop tick". A real ask
  quoting a marker mid-sentence is an ask. The grep runs only when the marker is present.
cc_prompt_scheduled <prompt> <transcript> — status 0 when the transcript has a line
  holding `"prompt":` plus the prompt JSON-encoded by jq (the whole value, so a prefix of
  a scheduled prompt does not match) and naming a ScheduleWakeup or CronCreate call.
  Status 1 with no prompt, no such file, or no jq.
cc_prompt_auth_surface — stdin filter for paths, case-insensitive (awk, C locale): prints
  each line holding auth (not author), authorise/authorize, login, passw, token, secret,
  credential, polic, permission, role, guard, middleware, impersonat, session, oauth,
  webhook, payment, crypt, registration, a migrations/ directory, or sign-up/signup/
  sign up/sign_up after a non-letter or as a camelCase part (SignUp, Signup).
cc_prompt_auth_ask <text> — status 0 when <text>, camelCase split, holds as a word: auth
  (also un-, re-, o-; not author or authority), log in/out, logged in/out, sign in/up/out,
  passw, passkey, secret, credential, polic, permission, role, middleware, impersonat,
  webhook, payment, encrypt/decrypt/bcrypt, cryptograph, registration, account, invite,
  invitation, api/access/refresh/bearer/reset token or key, session cookie/token/id/
  fixation/hijack, 2FA, MFA, two-factor, SSO, SAML, JWT, CSRF/XSRF, or a migrations/ path.
cc_prompt_unpaste — stdin filter: each <pasted_content …>…</pasted_content …> span
  goes, text on the tag's own line stays, a line left blank by a cut is dropped. An
  opening tag with no closing tag anywhere after it is cut alone (to its `>`), and the
  text after it stays; without a `>` the line stays as it was.
cc_prompt_ship_only <text> <verb-ERE> — status 0 when the text has at least one
  <verb-ERE> match and every match is create, add, open or make governing a ship noun:
  the verb, any of a fixed list of determiners and modifiers (a, the, new, draft,
  feature, release…), at most one other word, then the noun, ended by punctuation, the
  end, a joined name, or for, from, off, against, called or named; to, into, onto and
  with make the noun an object ("add PRs to the dashboard" is work). `and`, `then`
  and `&` are turned into `;` first, so a conjunction is never the word before a noun.
  PR, pull request and commit are ship nouns always; branch, push, merge, tag and
  release only when the text also names a PR, pull request, commit or `git`, a joined
  name sits beside the noun, or feature/hotfix/release precedes it.
  A hyphen-, slash-, dot- or underscore-joined token is one word with no verb in it.
cc_prompt_question <text> <verb-ERE> — status 1 when the ERE is empty. Status 0 when
  the text ends in `?` and holds no <verb-ERE> match and no request form (can/could/
  would/will you|u|we|someone|anyone, please, why, any idea|ideas); or holds "don't
  (start) work(ing) on anything|it|this|that" before punctuation, the end, yet, for now,
  until or before, "don't <making verb> anything yet|for now|until|before", or is,
  whole, "(please) don't <making verb> anything" — and, once those clauses are cut, no
  <verb-ERE> match opens a clause (the start, after .,;:!? and any non-alphanumerics) or
  follows and, but, then, so, also, first, just, now, please, to, should, must, can,
  could, will, would or let's.
```

### What it does not catch, stated

```text
- frame: a harness frame under any other prefix is a human turn, and so is a /loop tick
  whose heading the host renames. A prompt the user types under one of the three
  headings is silenced.
- scheduled: a re-fire the transcript cannot show — a durable task from an earlier
  session, a prompt ending in a newline (the hook's read strips it), a prompt holding DEL
  (jq escapes it, the host does not) — is a human turn. A prompt the user retypes
  verbatim while its call is in the transcript is silenced, and so is one equal to a
  subagent's prompt on a JSONL line that also names ScheduleWakeup. Each call reads the
  whole transcript, so adopters call it only once the prompt would otherwise speak.
- auth_surface: path words, not prompt words; `tokens.css` and a `SessionTimer` component
  match. A sign-up glued to a lowercase prefix (presignup.tsx) no longer counts.
- auth_ask: role, policy, middleware, secret, account, invite and "log in" still over-match
  ("the role of the sidebar", a privacy policy page, a timing middleware, a secret santa
  draw, an account balance, invited speakers, "a debug log in the job"), which withholds
  the skip for one clarifying round; narrowing them needed a phrase list per word. Missed:
  a guard, token or session named alone ("add a new guard for the API"), "register the
  listener", "user", and a surface named by brand (Sanctum, Clerk).
- unpaste: a name or verb that appears only inside a paste no longer counts.
- ship_only: a feature-sense branch, tag, merge or release ending its clause reads as
  ship when the prompt also names a PR or commit ("create the PR and add tags" is
  silenced), or when a joined or dotted name sits beside it ("add the next.js tag",
  "add a tag v-shaped" with nothing after them). A version tag is a dotted name
  (v1.2.0), so a dotted name cannot be dropped from git context.
  Every other miss errs toward speaking: "create a PR into main" (into ends no ship
  phrase), "create a new branch" (no git context), "fix the failing PR" (an edit
  verb), "write a commit message", a branch name holding a
  verb spelled as separate words (the verb counts), "create and add a PR" (each verb
  needs its own noun).
- question: a `?`-ended symptom report with no <verb-ERE> match and no request form is a
  question on purpose ("the login is broken?"; skill-router passes its strong tier, so
  "what's causing the 500s?" speaks); a `?`-ended prompt naming a making verb as a noun
  ("what does the build script do?") reaches the adopter's work test, which it passes,
  and so does a polite question ("could you explain this?"), which stays silent only if
  that test does. A hands-off clause silences only when no match outside it opens a
  clause or follows a lead word, so "quick question, don't work on anything yet: why is
  the import slow" waits and "fix the parser first and don't work on it until it passes"
  speaks. A strong-tier noun opening a clause still speaks ("don't work on it; test setup
  question"), and a deferred ask without a listed lead goes quiet ("we'll fix it later,
  don't work on it yet"); the next work prompt draws the check. "don't touch the API",
  "do not work on the legacy importer" and "don't change anything in vendor/" are
  constraints, not hands-off.
- Nothing here judges intent. Standing: the shapes are gated by each adopter's harness
  (ask-ledger ledger-hook.test.sh, scripts/smoke/prompt-route-tests.sh, skill-router
  route.test.sh case 18, review-debt.test.sh, scripts/smoke/hook-guard-tests.sh); the
  byte lock by pc_shared_blocks and generate.sh --check. Which shape a live host sends a
  wakeup in was read from the 2.1.300 binary and six recorded fires, not probed live.
```

### Adopters (2026-10-14, 2026-10-15)

```text
ask-ledger ledger.sh: frame, unpaste, scheduled. skill-router route-prompt.sh: frame,
unpaste (a prompt that is only a paste is read whole), question with its strong tier and
scheduled (the tool-fit check only; the digest still flushes on a re-fire, as on a slash
command). code-review review-debt.sh: frame (ship detection skips frames) and
auth_surface on changed paths. The reminder template with promptShape: frame, unpaste,
and scheduled once the trigger matched; ship_only on the manifest's shipVerbs; with
armsClarifyGate too (taskmaster) auth_ask on the prompt head. promptShape is set by
taskmaster's remind.sh and, since 2026-10-15, by approaches' remind.sh (build-vs-buy),
debugging's and api-design's. shipVerbs is set by taskmaster, approaches (their regex)
and api-design (its extraGuard verbs; its regex is nouns, so ship_only had never
silenced it). debugging sets none: its stuck phrases hold no making verb, and the
template then renders no ship test. approaches' consult-remind.sh keeps it off: it is a
phase-any guard on irreversible commands, a paste may hold the command the user asks to
run, and no misfire on a frame was measured. candor's preamble.sh (2026-10-15): frame and
unpaste, before its one-shot marker; not ship_only or scheduled (rationale in
plugin-candor.md § preamble.sh "Prompt shape").
Recount: grep -rl 'cc_prompt_frame() {' plugins/
```

### Moved 2026-10-28

The cc_prompt_frame contract; kept as one line without its last clause:

```text
cc_prompt_frame <prompt>: status 0 when <prompt> opens as a harness frame or a host /loop tick, or a line opens with the hand-back
  marker — not a human turn.
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
  - inert (any word other than all and cd): keep a body a reader may run. The reader is
    named on the opener's line (a shell, rbash and mksh included, ssh, su, sudo -i/-s,
    runuser, chroot, exec, xargs, eval, source, `.`, or the caller's ERE, tested on that line
    lowercased, unquoted, an escaped non-word character dropped, `<>|;&()` spaced out and
    space-padded) or sits off the line (the header lists the shapes). Once a body is
    dropped, every line is kept when a later line pipes into a reader with any words before
    it (`} | sudo -u deploy bash`, `} | timeout 60 bash`, `} | mysql`) but not a grep or rg
    lead, or into a `$` command word, or, after a body inside x=$( ) or x="$( )", holds
    eval, a shell's -c or a `$` command word. For a guard that judges what runs.
  - cd: inert with eval, source, `.` and the ERE the only named readers. For a cd test: a
    cd in a body this shell runs (`. /dev/stdin <<EOF`, `eval "$(cat <<EOF …)"`) moves it,
    one in a body a named subshell runs (`bash <<EOF`) does not.
The ERE reaches awk through the environment, not `awk -v`, which would process the
backslashes in it. Every mode keeps every line after a `<<` the scan cannot place (one
inside `${ }` or `$[ ]` included; a `#` glued to a closing `)` is a word, not a comment),
and keeps a body with no terminator. Keeping is the direction every adopter is safe in:
more command text means a guard reads more and a cd test skips more relative targets.
```

### cc_strip_heredoc_bodies: what it does not catch

```text
inert drops a body fed to anything not named (python3 -, node, at, a function, alias or
coproc), a body written to a script a later line runs, and one read into a variable by `read`
and run later. all drops a body a shell runs (`bash <<EOF`), by contract. cd keeps the
off-line shapes inert keeps, so a cd in a body piped into a subshell (`cat <<EOF |` then `sh`
on the next line) still counts. A case pattern's `)` inside `$( )` closes the substitution
early for the scan. The later-line rules read a quoted `|` as a pipe (`sed 's|a|$b|'`), so a
command with one and a dropped body is read whole. A huge kept body is still slow for a caller
that judges it line by line, and a `\`-continued line is joined by repeated concatenation,
quadratic in its length (408 KB, 0.44 s).
```

### Range-review fixes (2026-10-15)

```text
Every input here was deny or ask on command-guard 0.8.4 and allow on the block as first
extracted; each is now a destructive-guard.test.sh case asserting 0.8.4's verdict.
  - A pipe into a reader after the body allowed only option flags between `|` and the shell,
    and never the ERE: `} | sudo -u deploy bash`, `timeout 60 bash`, `env X=1 bash`,
    `nice -n 5 bash`, `$SHELL`, `done | sudo -u deploy bash`, `} | mysql`. Any words may now
    sit before the reader. Loosened only that far: a `.`, source, eval or `$` word counts
    only first in the pipe, and an escaped character is dropped before the test, after the
    first draft of this fix read `grep -rn "a\|b" .` as a pipe into `.` and took a 220-line
    TSX body line by line (0.3 s to 16.6 s, past the 15 s timeout).
  - No `${ }` or `$[ ]` frame: `echo ${v%<<EOF }` and `echo $[x<<EOF ]` opened a body and hid
    the commands under them; a `#` right after `<(true)` was read as a comment, so the quote
    after it never opened. Both are frames now, a `<<` in either cannot be placed, and every
    `)` leaves a word character behind it (after a bare subshell's `)` bash does start a
    comment; reading it as a word only keeps more).
  - `x=$(cat <<'EOF' … EOF)` then `eval "$x"`, `bash -c "$x"` or `$x` ran the body. These
    count only after a body inside x=$( ) or "$( )": unconditioned, `docker exec app sh -c`
    after any python heredoc read 49 of the 2,705 transcript commands whole.
  - rbash, mksh, `sudo -i`, `runuser -l` were not readers. The shell list is still explicit:
    `[a-z]*sh` matched `git push` and `refresh` on 10 transcript openers (commit messages,
    PR bodies), each then judged line by line.
  - all hid a cd the current shell runs: `. /dev/stdin <<'EOF'` holding `cd packages/api`,
    then `echo "it.skip('x')" > a.test.js`, had protect-tests judge <cwd>/a.test.js. The cd
    tests in protect-tests.sh, write-scan.sh and paths.sh cd_has_cd call mode cd.
Measured on 2,705 distinct `<<` transcript commands against the block as first extracted:
inert output differs on 31 (18 read whole, 3.6 s at most through destructive-guard; 13 drop
a body the old later-pipe test kept for a `bash` script inside `<( )` or `$( )`, or for a `(`
it read out of quoted text), the guard's verdict on none;
all output on none; mawk and busybox awk agree on every command. cd against all, the cd test
alone: the same verdict on all 1,111 commands holding `<<` and a cd word. The 20 KB /
7-heredoc command 335-365 ms, `git status && ls -la` 24.4-24.8 ms median.
```

### Tier-2 review fixes (2026-10-15)

```text
  - The later-pipe test matched a reader's name anywhere in the piped segment, so
    `| grep -c bash`, `| grep -i ssh`, `| grep -v su` and `| grep exec` kept a dropped body.
    A 19 KB `python3 -` body then went through destructive-guard line by line in 62 s against
    the 15 s timeout, and the `git reset --hard` after it ran unjudged. A segment led by grep,
    egrep, fgrep or rg is now a filter whatever its pattern names. Every other lead still
    counts a reader named anywhere after it (`| sudo -u postgres psql`, `| docker exec -i db
    psql`, `| php artisan tinker`), because a command-word-only test would drop those bodies;
    so `| awk '/bash/'` still keeps one, the over-read side.
  - Any `"$( )"` armed the later eval / -c / `$` test, so `git commit -m "$(cat <<'EOF' …)"`
    followed by `&& bash -c 'npm test'` read the message as commands. Only an assigned one
    does now: a `"` right after `=` (`x="$(`, `export X="$(`), as the unquoted form already
    required, so `--message="$(cat <<EOF …)"` still arms it.
Modes all and cd: the grep/rg rule changes nothing (cd mode names no shell and no ERE). The
`"$( )"` rule keeps fewer lines in cd mode after a commit-message body and a later eval or `$`
word, so a relative target there is judged. Every adopter's harness passed; destructive-guard
gains 10 checks (7 fail on the block before this change).
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

## templates/blocks/write-scope.md

### Banner and canonical copy

```text
--- write scope ---------------------------------------------------------------
Canonical copy: templates/blocks/write-scope.md. Every hook defining a cc_scope_*
function must carry this block byte-for-byte (pc_shared_blocks).
```

### Why it exists

```text
database's guard.sh and security's write-scan.sh each skip a scratch target (a probe under
/tmp, a test fake outside the repo), and each held a hand copy of the rule. The copies had
already diverged: database judged a path not created yet by its nearest existing directory,
write-scan judged it whenever the dirname was missing. Both took the project root from
cc_state_root of the payload cwd, which follows the shell's cd, so with the shell in a sibling
repo a DROP TABLE migration written into the project was skipped, CLAUDE_PROJECT_DIR set or
not; before the rule existed (7caa8bd9) it asked. Tier-2 review B1 and B10, 2026-10-15.
```

### Contract

```text
cc_scope_init <state root> resolves, with cd and pwd -P, CLAUDE_PROJECT_DIR, <state root> (the
caller's cc_state_root of the payload cwd, empty for none) and $TMPDIR (default /tmp).
cc_scope_skip <path> is status 0 for scratch:
  - a target under neither root, when either is set, or
  - a target under the temp dir while the root holding it is not.
A path not created yet is judged by its nearest existing directory (cc_scope_dir). The roots
are a union, not CLAUDE_PROJECT_DIR alone: the project dir alone would skip a write into the
repo the shell cd'd into, which the cwd rule judged, so every target the hand copies judged
is still judged. cc_scope_root <dir> sets cc_scope_r to the root holding a resolved dir, the
state root first, so database's SQLite probe stops where it did when only the cwd counted; a
variable rather than stdout, so the caller pays no subshell.
```

### What it does not catch

```text
A sibling repo or worktree written by absolute path from outside both roots is skipped. With
no payload cwd and no CLAUDE_PROJECT_DIR only the temp-dir rule holds. With CLAUDE_PROJECT_DIR
set and no cwd, a target outside it is skipped where the temp-dir rule alone judged it; the
host sends a cwd on every tool call, so that is a harness shape. A directory symlinked out of
the project resolves out of it, so a write through it is skipped, as before.
```

### Adopters and measured verdict changes (2026-10-15)

```text
  - database guard.sh: scope_init calls cc_scope_init once, only for a target that would ask.
    A target under CLAUDE_PROJECT_DIR but outside the cwd's root now asks; with no cwd and
    CLAUDE_PROJECT_DIR set, a target outside the project dir is now skipped.
  - security write-scan.sh: the same two changes to its warnings, and a target whose
    directory is missing is judged by its nearest existing one (a PostToolUse target exists
    by then; no case found where it differs). A plain Write with CLAUDE_PROJECT_DIR set:
    34-35 ms per call against 34 ms (30 calls, two rounds).
guard.test.sh and write-scan.test.sh gain three scope cases each; the write into the project
from a sibling repo fails on the hand copies, the write into the cwd's repo and the target
outside both pass on both.
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

### Moved 2026-10-28

Below the pointer line; kept as one line, `No template directive in these comments: _expand_includes copies this file raw, then conditionals and substitution run over all of it.`:

```text
No template directive of any kind in these comments: _expand_includes copies this file raw, then conditionals and
substitution run over the whole text.
```

## templates/blocks/quote-match.md

Written 2026-10-29 when the block shipped (code-review 0.34.4), not moved from code. Standing: `recorded`; the byte-for-byte copies are a **gate** (`pc_shared_blocks`, pair `quote-match:cc_quote_match`).

### Why it exists

Improvement plan item 8 (`rationale/improvement-plan-2026-10-26.md`, row 8): a review finding that quotes code should quote what the file holds. Two callers judge the same rule: code-review's `scripts/quote-check.sh`, which `/code-review:review` runs before its verdict, and candor's Stop gate, which blocks a turn whose marked quote is not in the cited file (user decision 2026-10-29). Plugins install alone, so the rule is pasted, not sourced, and the two copies cannot drift.

### What it decides, and why that way

A wrong mismatch costs a reviewer a dropped finding and, in candor, a blocked turn; a wrong match costs one unchecked quote. Every rule errs toward the match.

- **Window ±3 lines by default.** A reviewer cites the line a hunk header or a blame excerpt gave, and the quote is often the statement above or below it. Seven lines tolerate that drift and still tell a quote from a line elsewhere in the file.
- **An optional fourth argument sets the window** (fix cycle 1, 2026-10-29): a whole number of lines either side, or `all` for the whole file. candor's Stop clause is specified to call it with `all` (m14 fix cycle 1), so it blocks only on a quote that is nowhere in the file: a blocked turn costs more than a review's dropped finding, and a citation a few lines off is the citation clause's business, not this one's. Anything else is status 2.
- **Three tries, as typed and then unescaped** (fix cycle 3, 2026-10-29): the quote as typed; then with one leading `+` or `-` dropped; then cut at its ellipses. Failing all three, every `\|` is read as `|` in the quote AND the window, and the three tries run again. Cycle 2 rewrote the quote in place before the `+` and `…` tries, so a true quote of a real `\|` (a grep alternation) failed whenever it also carried a `…` or a `+`: all 12 of 671 reference-implementation divergences the correctness review found had that shape. Unescaping the window too lets a table cell mixing the file's own `\|` with an escaped pipe (`'TODO\|FIXME' "$1" \| wc -l`) match.
- **`\|` is a Markdown table cell's escape** (fix cycle 2): a quote written in a table must escape its pipes, so `a | b` arrives as `a \| b`. Trying as typed first keeps a real `\|` in the file matching.
- **One leading `+` or `-` forgiven** (fix cycle 1 for `+`, cycle 3 for `-`): a reviewer copying a line from the patch keeps its marker. Dropping can only shorten the needle, so code that opens with `++` or `--` still matches. A `-` line is deleted code: the working file lacks it, but candor also searches the HEAD copy, which holds it.
- **ASCII whitespace and no-break spaces dropped, both sides,** not runs collapsed to one space: a collapse still fails `foo(a,b)` against `foo(a, b)`, a tab-indented file against a space-typed quote, and a call the file wraps over three lines against a quote typed on one. The window's lines are joined before the compare, so a quote may span lines. No-break space (U+00A0) is dropped too since fix cycle 3 (correctness review #12: the header said "every whitespace character" while only `[ \t\r\n\f\v]` was dropped, and a NBSP against a space blocked in candor); the header now names the set. Other Unicode spaces (U+2000-U+200A, U+3000) are not dropped.
- **Literal first, then `…`/`...` as cuts.** JavaScript's spread and Go's variadic `...` are code, so the quote is first matched as typed. Failing that, each ellipsis cuts it into parts that must appear in order; a leading or trailing one is then a suffix or prefix match, which is the brief's rule, and an inner one is an elided middle, which the brief did not name.
- **Under 8 non-space characters is status 0.** Counted after the cuts, in characters (UTF-8 continuation bytes are not counted), so `…;` or `x = 1` is never judged, nor a 6-letter Cyrillic word of 12 bytes.
- **Status 2 is checked first and never means a wrong quote:** a path that is not a readable regular file, over 1 MiB, a NUL in the first 8000 bytes (git's own binary test), a line that is not a whole number from 1. Past the end of the file is status 1: the file read and the text is not there.
- **The caller resolves the path.** candor already resolves a cited path its own way (`cite.sh`), and quote-check.sh resolves against the repository root; a block that searched too would answer the same question twice, differently.
- **Portable.** No shell function call, no `declare -A`, no GNU-only flag; the compare runs in one awk under `LC_ALL=C` (its one awk function, `found`, holds the three tries), the quote passed through `ENVIRON`, since `-v` would turn a `\n` in quoted code into a newline. Run under mawk 1.3.4 and busybox awk on 2026-10-29; bash 3.2 not run.

### What it misses

- A true quote that proves nothing about the finding, and a quote that matches anywhere in the window while the finding points at another line in it; with `all`, anywhere in the file.
- A file edited between the review and the check; text repeated within the window. A quote whose first character is a real `+` or `-` the file lacks matches with it dropped, and one holding `\|` matches a file with a bare `|` there.
- A Unicode space other than U+00A0 against an ASCII one.
- A quote holding a backtick, unless the caller reads a doubled-backtick marker (quote-check.sh does).

### Cost

Five processes per call (`wc`, `head | tr | wc`, `awk`). Through quote-check.sh, on findings quoting real tracked files of this repository (2026-10-29, Linux, mawk): 25 findings 93 ms, 200 findings 744 ms, median of 5. With `all` the awk reads the whole file, at most 1 MiB.

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

### shipVerbs: the ship test reads the manifest's verbs

```text
cc_prompt_ship_only takes a verb ERE. The template passed regex, which is verbs for
taskmaster and approaches but nouns for api-design (its verbs sit in extraGuard), so
api-design's ship test could never silence: "create a PR for the webhook changes" drew
the docs reminder (Tier 2 review, 2026-10-15). The manifest now names the verbs in
shipVerbs, and a manifest without it renders no ship test, so that reminder speaks on a
ship prompt rather than reading nouns as verbs. Every verb the reminder counts as work
belongs in the list: a verb left out is a verb the test never sees, which turns "integrate
X and create a PR" into a ship-only prompt. The cost runs the other way: api-design's
integrat\w* also reads the noun, so "create a PR for the Stripe integration" still speaks.
Needs promptShape for the function. Standing:
gate (scripts/smoke/hook-guard-tests.sh, api-design "ship-only prompt" and "work beside a
ship step").
```

### The auth-surface line (armsClarifyGate)

```text
The clarify gate's reminder offers a way out: "state in one line why this task is
trivial enough to skip it". A session took it on a prompt disabling registration
(2026-10-13 retro, V-20). Where the manifest sets armsClarifyGate, a second line
follows the message when cc_prompt_auth_ask matches the prompt head: the trivial
skip does not apply. The words are the prompt-shape block's prompt-side list (review-debt
reads the path list beside it), so the line also needs promptShape; without it the call
fails and no line is printed. Keyed on armsClarifyGate rather than a new manifest key
because the skip it withdraws belongs to the clarify gate's message. Standing: gate for
the line (scripts/smoke/hook-guard-tests.sh, the tm_auth cases); whether the model then
runs the round is agent-graded.
```

### Moved 2026-10-28

Header, between the `generated from` line and the pointer; kept as one line naming what the hook does and misses:

```text
Fail open: never block the prompt. Print a reminder only when the prompt reads
like the work it nudges about — a mere mention of the words stays silent.
```

Above `cc_prompt_ship_only "$head" '{{shipVerbs}}' && exit 0`; kept as `shipVerbs, not regex: a regex of nouns (api-design's) never matches a verb. Needs promptShape.`:

```text
Every shipVerbs match being create, add, open or make on a PR or commit (or, in git context, a branch, push, merge, tag or release)
asks to ship. Its own key, since a regex of nouns (api-design's) never matches a verb; needs promptShape.
```

Above `cc_prompt_auth_ask "$head" && printf …`; kept as the standing fact `An auth change is never trivial: the skip is withheld on the prompt-shape block's auth words (needs promptShape).`:

```text
The trivial skip let an auth change through: withheld on the block's prompt-side auth words (needs promptShape).
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

### Moved 2026-10-28

Header, between the `generated from` line and the pointer; kept as one line naming what the hook does and misses. The manifest's `intro` line, which sat between the first line below and the second, did not move out: it renders above the hook's main `{` now, so the header stays at three lines:

```text
Fail open: never block the prompt. Inject the boost directive when the prompt asks.
No suffix grammar — bare tokens only, fixed tier model=auto effort=xhigh
(auto = session model or opus, whichever is higher on haiku<sonnet<opus<fable).
```

Above `plugin_switch={{envVar}}`; kept as one line:

```text
CC_BOOST=off silences every boost hook and the variable plugin_switch names silences this one; either
/config option silences only this plugin's hook, and a non-empty environment variable wins over it.
```
