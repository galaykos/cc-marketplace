# skill-router hooks and harnesses: the comment text moved out of the code (2026-10-04)

The text below was moved verbatim on 2026-10-04 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-skill-router.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/skill-router/hooks/route.sh

### Header: shebang, contract and delivery channel

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
hold even under a stripped/broken PATH, where `env bash` itself exits 127.
PostToolUse router. Given the edited file, match rules.tsv and inject one
directive to load the relevant skill — every `high` row fires inline once per
signal per session (a `glob` row on the path, a `content` row on the file's
contents, a `command` row on a Bash command string); `low` content matches
accumulate into the session-state digest. All inline nudges for one edit are delivered as
a SINGLE {"hookSpecificOutput":{"hookEventName":"PostToolUse",
"additionalContext":...}} envelope — the one non-blocking channel the
executing model actually receives; plain stdout with exit 0 never reaches it
(same channel doctrine as task-runner/hooks/scope.sh and
comment-discipline/hooks/scan.sh). Fail-open: any error, or a
missing jq, exits silently and never blocks the edit.
```

### Header: BASH WRITES ROUTE TOO

```text
BASH WRITES ROUTE TOO (0.20.0) — the matcher carries `Bash`. Measured 2026-09-25
(rationale/2026-09-25-session-plugin-usage-review.md, finding 1): with the host's
`bashFirst` steering, one session wrote 233 of 238 main-thread files through
`cat > f <<EOF`, and this hook, matched on Edit|Write only, routed ONE edit across
~40 items of auth, token and HTTP-client work — the "Signals from recent edits"
digest fired zero times there. A Bash payload is now routed exactly as if each
target the command names had been Edited: `cc_bash_write_targets` (shared block
below) lists them, the first 8 are examined, and only one that is an EXISTING
REGULAR FILE UNDER THE PROJECT ROOT routes — a `>` into /tmp, into a log outside the
repo, or onto a path the command then deleted routes nothing. Same one-shot, same
single envelope per call, however many files one command wrote.
```

### Header: COST

```text
COST, because this now runs after EVERY Bash call: a call with no write target and no
`command` row match exits after two jq reads, at most one awk, one grep selecting
rules.tsv's `command` rows and one `grep -E` per such row — before plugins-dir.sh or
any state is touched. The `case` prefilter drops `git status` before awk even starts.
Only a raw `command` row hit pays one more awk (route_cmd_mask) and a second grep.
```

### Header: COMMAND ROWS

```text
COMMAND ROWS (routing review 2026-09-26, S8): a CLI that writes its own files —
`npx shadcn@latest add @magicui/marquee` — names no redirect target, so no file row
could ever see it; the installed component routed only on its first LATER edit. A
`command` row matches its ERE against the Bash command string and fires inline, once
per signal per context, like a `high` glob row. `high` only: a `low` command row is
ignored (there is no file to list in the digest). The ERE runs against the command with
single- and double-quoted text masked and heredoc bodies blanked (route_cmd_mask), so a
commit message, a grep pattern, an echoed string or a heredoc writing a doc that MENTIONS
the command neither routes nor spends the one-shot; `$(…)` inside double quotes is live
code and still routes. LIMITATION: an unquoted mention (`echo run shadcn add`, `\"`
escapes) still routes; a quoted CLI name (`npx "shadcn" add`) is masked and does not;
backtick substitution inside double quotes is masked; a CLI invoked through a script or
an npm `scripts` alias names nothing the row can see. `@base`/`@path` markers see an
empty string on a command row.
```

### Header: NOT CAUGHT, and the unmetered Bash output

```text
NOT CAUGHT (the block's own list): interpreter writes (python open(), php
file_put_contents), cp/mv/install destinations, `{ …; } > f` groups, a path held in a
variable. The
dynamic budget probe (scripts/context-budget.sh) sends Edit payloads only, so a Bash
call's output is unmetered there; per target it is the text an Edit of that file gets.
```

### Header: no lock, the off switch and where state lives

```text
Honest limitation: state writes are read-modify-write with no lock — two
concurrent invocations in one session can drop a pending_low entry (tool
calls are serialized in practice; not worth a lock).
CC_REMIND unset: the /config option cc_remind decides.
State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/skill-router/ is only the fallback.
```

### route_cmd_mask

```text
route_cmd_mask <command> — the command as COMMAND rows see it (header: COMMAND ROWS):
single- and double-quoted text replaced by `_`, heredoc bodies blanked. A stack of
U(nquoted)/S/D/C states tracks nesting, so `$(…)` inside double quotes stays live code
and a heredoc opened there (`git commit -m "$(cat <<'EOF'`) is still recognised.
```

### OFF SWITCH: why CC_REMIND is read and CC_ROUTE is not

```text
OFF SWITCH. `CC_REMIND=off` is the marketplace-wide advisory mute, and eight
sibling READMEs promise it silences "every advisory nudge in this marketplace"
— a promise this plugin's own README repeated while this hook, its headline
advisory channel, never read the variable. route-prompt.sh has honoured it
since it shipped; the per-edit nudges did not, so a user who muted the
marketplace still got them on every Edit. `CC_ROUTE` is deliberately NOT read
here: it names the prompt-level tool-fit check only (route-prompt.sh:26), and
widening an existing switch silently is worse than the gap it closes. There is
no file-routing-only switch, and the README says so.
```

### The Bash no-target exit

```text
BASH, no-target exit first (header: COST). The `case` is a superset of every
shape the block can return (`>`, tee, sed/perl -i), so it is safe to skip awk on.
```

### COMMAND rows in the Bash block

```text
COMMAND rows (header). One `skill<TAB>plugin<TAB>marker<TAB>matched text` line per
hit; the installed, marker and one-shot filters run in the high pass below, once
the project root is known. An empty marker is spelled `-`: `read` with a tab IFS
collapses an empty field and would shift the matched text into its place.
```

### CONTEXT KEY

```text
CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
subagents at all, and a subagent shares its parent's session_id while getting its
own transcript. Keying a one-shot on session_id therefore dedups the worker against
nudges only the PARENT ever saw, so the context where most fan-out code is written
is the one context this never speaks in. Pattern and rationale: code-review/hooks/conventions.sh (context-key one-shot).
```

### pathInProject and apply_patch

```text
`pathInProject` is the JetBrains-MCP create_new_file key (schema read 2026-09-14);
an IDE-driven session writes every file through it and would otherwise route nothing.
apply_patch carries no single path, so it stays unrouted — stated, not hidden.
```

### The -d guard on the payload cwd

```text
`-d`, not just `-n`: the state write below is `mkdir -p` under the project root,
which RECREATES a project directory the session has deleted — reproduced live three
levels deep (2026-09-22 panel, architecture #1). A payload naming a directory that no
longer exists has no state worth keeping and no file worth routing. Same guard as
plugins/overseer/hooks/track-read.sh:30. LIMITATION: it proves the path EXISTS, not
that it is the project — a payload whose cwd is `/` or `$HOME` outside any git repo
still passes, and the state dir is created there. Nothing available to a hook can
tell those apart.
```

### STATE ROOT

```text
STATE ROOT (finding 2 of the review named in the header). The payload cwd follows
the model's `cd`; state, manifests and the repo-relative path all key on the
project root instead, so one session keeps one state file however often it moves.
```

### TARGETS

```text
TARGETS, as two parallel arrays: the spelling recorded in pending_low, and the file
on disk. An Edit is one target, spelled as its payload spelled it (unchanged). A Bash
target resolves against the payload `$cwd` (the Bash tool's cwd), is canonicalised
through its directory (so `../x` cannot slip out of the root test), and must already
exist as a regular file under the root (PostToolUse runs after the command, so a
target that is absent now was never written or was removed again). LIMITATION: a `cd`
INSIDE the same command (`cd app && cat > f`) moves the base the shell really used;
whether the host samples cwd before or after the command is unverified here, so such
a relative target may resolve wrong — it then usually fails the existence test and
stays silent, and at worst routes a same-named file.
```

### The sibling plugins directory

```text
Sibling plugins directory, for the installed-plugin filter. Resolved by
hooks/plugins-dir.sh, which handles both the flat and the versioned-cache
layouts — see that file's header for why dirname alone silently disabled this
hook on every real install. Empty when it cannot be determined, and empty
means fire anyway (bias to surface). A missing lib lands on the same default.
```

### The hashed state key

```text
Hashed, not raw: the CONTEXT KEY read above takes `.transcript_path` first and that is
an absolute path, so `fired-$session_id.json` names a nested file whose parents are
never created. The write fails, `fired` is empty on every call, and the "same skill is
not re-nudged on later edits" property (`already_fired`) never holds — every edit
re-injects directives the model already has. Same idiom as
code-review/hooks/conventions.sh (hashed state key).
```

### set_target: the root-relative path

```text
`rel` is the path RELATIVE TO THE PROJECT ROOT when the file sits under it, so a
`**/dir/**` row and an `@path` marker see `app/Enums/Status.php` whether the write
came from the root, from `cd app/Enums`, or as an absolute path — and a checkout
that merely lives under a directory named `tests/` or `app/` no longer matches those
rows on every file. A file outside the root keeps the payload's spelling (the
pre-0.20.0 behaviour for every file).
```

### inline_ext

```text
A code or style file, the only kind a `content`+`high` row fires inline on (high pass).
```

### match_glob: case-insensitive directory segments

```text
DIRECTORY SEGMENTS MATCH CASE-INSENSITIVELY, on purpose. The same framework
directory ships under two casings depending on the scaffolder that made it:
Laravel's current Inertia starter kits generate `resources/js/pages/` while
the older convention (and rules.tsv) says `Pages`. A case-SENSITIVE test
meant `**/resources/js/Pages/**` — inertia's ONLY routing row — fired on
zero files in every lowercase project, so the plugin routed nothing there
and `/inertia:review` had to be typed by hand. `**/Livewire/**` had the same
exposure, masked only because livewire has a second row (`*.blade.php`).

LIMITATION: case is checkable, a wrong directory NAME is not. A row naming a
directory the framework does not use still matches nothing, and no gate here
can see that.
```

### marker_ok: the marker grammar

```text
$1 stack_marker — 0 = fire, 1 = suppress. `||`-separated
alternatives, each `[!]<manifest>~<ERE>`, tried in order: the FIRST
decisive alternative wins — its grep verdict (exit 0 fire / exit 1
suppress, after `!` inversion) is final, so an authoritative source
(installed node_modules version) listed first overrides a looser declared
range behind it. Indecisive alternatives — absent/unreadable manifest,
missing `~`, empty side, grep exit >= 2 — are skipped. No decisive
alternative at all fires: an undetectable stack keeps today's behavior.

`@base` as the manifest name matches the ERE against the edited file's
BASENAME instead of a file's content, so a row can exclude a file SHAPE:
`!@base~\.config\.` suppresses on `vite.config.js`. Added 0.16.0 because the
`*.js`/`*.ts` design-principle rows fired SOLID and cognitive-load nudges on
`tailwind.config.js`, `eslint.config.js`, `*.d.ts` and `*.min.js` — files with
no classes, no design and nothing to review against those skills — and a
bare-extension glob has no way to say "except these". Before 0.16.0 an
`@base` alternative was indecisive (no such file) and skipped, so a rules.tsv
carrying one is safe under an older route.sh: it simply fires.

`@path` is the same device one level up: the ERE runs against the edited
file's PATH (`rel`, see set_target), so a row can exclude a
DIRECTORY. `!@path~(^|/)dist/` keeps the markup a11y rows off built output —
a bundled `dist/index.html` has the same BASENAME as its source, so `@base`
cannot tell them apart, and match_glob's one path-aware form (`**/dir/**`)
can only say "inside", never "not inside". LIMITATION (honest scope): the
value is root-relative only for a file under the project root — outside it,
whatever the payload carried — so an exclusion must anchor on `(^|/)`, never
on `^` alone, and a build directory under a name nobody listed is still routed. Unknown to an
older route.sh, where `@path` is just a manifest that does not exist and the
alternative is skipped: the row fires, the same safe fallback as `@base`.
`?` PREFIX — `?package.json~"next"` — makes the alternative REQUIRE its manifest:
absent or unreadable is then decisive-SUPPRESS instead of skipped, so a chain of
`?` alternatives reads "fire only on a manifest that exists and says yes". It is
the general form of the `||!@base~.` default-deny tail 0.18.0 bolted onto four
rows; those rows now carry `?` instead, so one mechanism expresses it. Per-row and
opt-in — an unprefixed alternative keeps the fire-if-uncertain default. Write `?`
first when negating too (`?!composer.json~laravel/framework`).
LIMITATION: absent/unreadable manifest is the ONLY indecisiveness it converts. A
malformed ERE (grep exit >= 2) still skips the alternative, so a row with a broken
regex and a present manifest keeps firing; and marker_ok reads `$root/<manifest>`
only, so a monorepo whose package.json sits in a workspace subdirectory is "absent"
here and a `?` row suppresses there. Until 0.20.0 it read the payload cwd, which
followed the model's `cd` (a write after `cd app/Enums` read app/Enums/composer.json)
and, as a side effect, served a session STARTED inside a workspace that workspace's
manifest; that session now reads the repo root's. Walking up from the file to the
nearest manifest was rejected: a Laravel app's per-module composer.json (nwidart
modules, local packages/) would then suppress laravel-best-practices on the very
files it is for. Unknown to an older route.sh, where
`?package.json` is a manifest name that does not exist: the alternative is skipped
and the row fires — the same safe fallback `@base` and `@path` have.
```

### emit_nudge

```text
When the SKILL.md is locatable, name its path: a subagent context has no
Skill tool, so "load the skill" is only actionable there as a Read.
Under a versioned cache the SKILL.md sits one level below the plugin dir, so
the path comes from pr_plugin_root rather than a join onto the plugins root.
$3 replaces the "This edit touches <file>" subject for a command row, which has
no file; every file row omits it, so their text is unchanged.
```

### The high-confidence pass

```text
---- high-confidence pass: EVERY surviving, not-yet-fired match nudges ----
All relevant skills for THIS edit fire (e.g. a11y alongside ui-ux, and the
stack skill, on a single .tsx) — no break after the first. Session dedup via
`fired` still prevents re-nudging the same skill on later edits; emitted_now
dedups two rules — or two files of one Bash call — that map to one skill.

CONTENT + HIGH (routing review 2026-09-26, finding 1): a `content` row marked `high`
fires here on a code or style file (inline_ext), from the file ON DISK, and never
enters the digest below. Every library row (MUI, component libraries, motion,
three.js …) used to be `content`+`low`, so its skill surfaced on the NEXT user prompt
— in a build turn, after the last file was written — and in a subagent never, because
UserPromptSubmit does not fire there and only the main thread's digest is flushed.
Inline PostToolUse context reaches both. On any other file (a NOTES.md mentioning
gsap, a .py holding `new THREE.`, which used to fire and spend the one-shot) the match
goes to the digest below, as a `low` row's does. The digest pass reuses this pass's
one read per target (`hcs`).
COMMAND rows matched in the Bash block above. No file, so `@base`/`@path` see "".
```

### Delivery

```text
---- deliver: ONE envelope per invocation, before state persistence so an
unwritable state dir cannot swallow a nudge the model should have seen ----
```

### The low-confidence pass

```text
---- low-confidence pass: accumulate content matches (no inline output) ----
Read from the file ON DISK, so a Bash heredoc's body is judged exactly as an
Edit's result would be. One `skill<TAB>file` line per hit. A `high` content row
on a code or style file was handled inline above and is skipped here, so it never
reaches the digest; on any other file it lands here like a `low` row.
```

### Persistence

```text
---- persist state only if something changed ----
The README has said "(gitignored)" of this directory since it existed; nothing
made that true, and the per-session file showed up as untracked in every repo
without a hand-written ignore line. A directory can ignore itself.
```

## plugins/skill-router/hooks/route-prompt.sh

Editor's note (2026-10-04, card 03): citations below that have moved since they were written — route.sh's "CONTEXT KEY block" is now a one-line "Context key" comment in its main block (its text: § plugins/skill-router/hooks/route.sh, ### CONTEXT KEY); route.sh's "deliver block" is now the function `deliver_nudges`; `testing/hooks/test-shape.sh:90` is now near its line 157; "the block above the heredoc" is ### The protocol, not a catalog, below.

Editor's note (2026-10-04): § plugins/skill-router/hooks/route.sh, ### OFF SWITCH: why CC_REMIND is read and CC_ROUTE is not, says `CC_ROUTE` "names the prompt-level tool-fit check only". In this hook `CC_ROUTE=off` exits before the pending-signal flush, so it also withholds the next-prompt flush of low-confidence signals; they then appear only in summary.sh's SessionEnd line (probed 2026-10-04; the README states it).

### Header: shebang, contract and history

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
hold even under a stripped/broken PATH, where `env bash` itself exits 127.

UserPromptSubmit tool-fit check. This hook does NOT decide which command fits —
it hands the model the rules for judging and points at the command list the HOST
already put in this session. A previous version matched prompt patterns to
commands in a table; a table only ever routes the phrasings its author thought
of, and every new plugin needed a new row. The judgment belongs to the model,
which reads meaning; the hook's job is the discipline around that judgment.

It used to rebuild the list too — one truncated frontmatter line per installed
command — which cost ~5.2 kB per session to restate what the model could already
read, and grew with every plugin. See the block above the heredoc for what that
removal gave up (the repo-evidence filter went with it).

Fires once per session, on the first work-shaped prompt: a chat-only session
pays nothing, and once injected the catalog stays in context for later prompts.
Fail-open: any error, or a missing jq, exits silently and never blocks.
CC_REMIND / CC_ROUTE unset: the /config options cc_remind / cc_route decide.
State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/skill-router/ is only the fallback.
```

### OFF SWITCHES

```text
OFF SWITCHES. CC_REMIND=off silences every advisory nudge in the marketplace
(this is one); CC_ROUTE=off silences only this check. Environment is the one
state independently-installed plugins genuinely share.
```

### The pending-signal flush, its context key and state root

```text
---- pending-signal flush. Low-confidence signals route.sh accumulated are
surfaced on the NEXT prompt — a channel the model receives in time to act —
instead of only at SessionEnd, an event after which no model turn exists.
Each entry surfaces once (marked flushed in the state file); summary.sh's
SessionEnd ledger still records everything. Runs before every later exit —
slash-command prompts included (a /task-runner:run session must still see a
pending security signal), and "looks good, continue" is exactly the prompt
where one must not stay buried. Honest limitation: if the state file is
unwritable the flushed flag cannot persist and entries re-surface next
prompt — fail-open toward repetition, never toward losing a signal.
CONTEXT KEY — must match route.sh's CONTEXT KEY block exactly, field order
included: read `.transcript_path // .session_id`, then hash. Reading the raw
`.session_id` here named a file route.sh never writes, so this flush found nothing
on every prompt and the whole low-confidence channel was dead. The cksum applies to
the fallback branch too, so no payload shape makes the two spellings coincide.
STATE ROOT — the same rule, one level up: route.sh writes under cc_state_root of
ITS payload cwd, so this reads under cc_state_root of this one. Reading the raw cwd
after the model had `cd`-ed would look in a directory the writer never used.
```

### Trigger narrowing

```text
TRIGGER NARROWING, identical in shape to the reminder hooks': drop fenced and
backticked spans, read only the head, refuse prompts ABOUT this machinery, and
refuse this hook's own output echoed back. LIMITATION (honest scope): heuristic,
not parsing — CC_ROUTE=off is the reliable control, this is the cheap one.
```

### The work-shaped gate: one grep, three tiers, and the weak-tier bound

```text
WORK-SHAPED GATE. The one pattern left, and deliberately not a routing table:
it asks "is this a request to do work?", never "which tool". Everything about
WHICH is the model's, downstream. A miss here costs a check, not a wrong route.

ONE grep, three tiers: validate.sh budgets four prompt-matching greps here and
calls a fifth a routing table regrowing in shell, so the tiers are alternations
inside this pattern rather than lines of their own.

  MAKING VERBS — build, refactor, deploy … : match bare. Unchanged.
  STRONG symptom — error, crash, 500s, regressed, why is, investigate, not
    working: match bare. A prompt carrying one of these is about a defect
    whatever the surrounding grammar.
  WEAK symptom — down, slow, broken, failing, fails, leak, stuck: match ONLY
    after a state verb (is/are/went/keeps/got/…), with at most one word
    between. These are ordinary English before they are incident vocabulary.

WHY THE WEAK TIER IS BOUND AND THE STRONG ONE IS NOT. Symptom phrasing was
added because `production is down` and `why is the checkout page broken`
reached this gate and were dropped, while `fix …` sailed through — an incident
is reported by its effect, not by a verb, so the one moment where tool choice
matters most was the moment the catalog never reached. But bare `down` also
matches `scroll down and tell me what you see`, and bare `slow` matches `the
meeting ran slow today`. Each false positive injects the ~2.6k-token catalog
into a session that would otherwise pay nothing, and no gate can see it:
context-budget.sh measures one fixed making-verb prompt in an empty sandbox,
so this cost is real and structurally unmeasurable. The state verb is what
separates a system in a bad state from an ordinary sentence. Bound pattern:
taskmaster/hooks/preview-guard.sh, whose weak .html tier is bounded for the
same reason — a weak signal that never clears is noise wearing a gate's name.

HONEST LIMITATION. The bound is grammatical, not semantic. A symptom phrased
without a state verb — `payment failures spiking`, `memory leak in the worker`
— is missed, and a chat sentence that happens to carry one (`the build is slow
to watch`) still fires. It trades recall on the weak tier for the silence of
the plain-prompt path, which §1 calls the overwhelming case; the STRONG tier
is what carries recall, and it is unbounded. A miss here costs a check, never
a wrong route.
```

### Once per session: the raw session_id

```text
ONCE PER SESSION. The catalog stays in context after the first injection, so a
second copy buys nothing and costs the same tokens again.

`.session_id` RAW is correct here and is NOT the pc_context_key defect. That gate
exists because a subagent shares its parent's session_id, so a one-shot keyed on it
dedups the worker against a nudge only the parent saw — but UserPromptSubmit never
fires in a subagent at all (route.sh's CONTEXT KEY block and testing/hooks/test-shape.sh:90
both state PostToolUse is the only channel that reaches one). There is no second context to starve. The flush block above keys on
`.transcript_path // .session_id` for a different reason: it READS the state file
route.sh writes, so it must spell the key exactly as route.sh does.
```

### The catalog marker: fail open on an unwritable TMPDIR, `-e` not `-d`

```text
FAIL OPEN on an unwritable TMPDIR. `mkdir || exit 0` conflated two causes with
opposite correct responses: the marker already exists (fired this session —
suppress, the whole point), or TMPDIR is not writable so the marker can never
exist (suppressing costs the catalog on EVERY prompt of EVERY session, silently).
route.sh's deliver block states this plugin's doctrine for exactly this case — "an unwritable
state dir cannot swallow a nudge the model should have seen" — and delivers before
persisting. This is the same rule on the bigger payload. mkdir stays the atomic
first attempt; the existence test only runs once it has already failed.

`-e`, not `-d`: the first version of this fix tested for a DIRECTORY, so a plain
FILE squatting the marker path fell through both branches and the ~9 KB catalog
injected on every prompt of the session — a worse failure than the one being
fixed. Anything at the path means the marker state is either "fired" or unusable;
suppressing is right in both (one lost catalog beats 9 KB per prompt), and the
fail-open branch stays reachable only when the path is genuinely vacant, i.e. the
parent is unwritable.
```

### The protocol, not a catalog

```text
---- the protocol, not a catalog --------------------------------------------
This hook used to rebuild every installed plugin's commands as one truncated line
each: 61 rows, 5,179 of the 6,892 chars it emitted, a second copy of a listing the
host had already sent this session and one row longer per command installed. What
the model does NOT have from that listing is the discipline below, which is the
whole reason this hook exists; the rows were the part it could already read.

LIMITATION (honest scope), and it is a real trade. The host listing is not filtered
by repo evidence, so a Laravel repo now sees the Next.js review in it where the
built catalog hid that row — the stack-relevance walk went with the rows it filtered.
Step 1 below ("most requests fit none of them") is the only thing left holding that
down, and it is the model's judgment, not a gate. Nothing here can verify the host
actually sent a listing either; if a session has none, step 1 reads as vacuous and
the hook is silent rather than wrong.
```

## plugins/skill-router/hooks/summary.sh

Editor's note (2026-10-04, card 03): route.sh's "CONTEXT KEY block" is now a one-line "Context key" comment in its main block (its text: § plugins/skill-router/hooks/route.sh, ### CONTEXT KEY).

### Header: shebang, contract and state

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
hold even under a stripped/broken PATH.
SessionEnd ledger + cleanup. The model-visible surfacing of low-confidence
signals happens in route-prompt.sh's next-prompt flush — SessionEnd is an
event after which no model turn exists, so the digest line printed here is
transcript residue covering only entries the flush never surfaced. The real
jobs are the surfaced.jsonl ledger append and removing the state file.
Fail-open: any error exits silently.
CC_SURFACED_LOG unset: the /config option cc_surfaced_log decides.
State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/skill-router/ is only the fallback.
```

### Two values, two jobs: ctx_src and session_id

```text
TWO VALUES, TWO JOBS — do not collapse them.
 ctx_src   addresses the state FILE and must match route.sh's CONTEXT KEY block
           exactly, field order included. route.sh reads `.transcript_path // .session_id` and
           hashes it; this hook used to read the raw `.session_id`, so it named a
           file the writer never creates — the ledger below never got a row and
           the `rm -f` never ran. The cksum is applied to the fallback branch too,
           so there is no payload shape where the two spellings coincide.
 session_id is a RECORDED FIELD in surfaced.jsonl, never a key. It stays the raw
           session id: a reader grepping the ledger wants the id the host reports,
           not a transcript path. Same distinction hindsight/hooks/skill-use.sh
           blesses with `context-key-ok`.
Change one side of ctx_src and you must change all three (route.sh, route-prompt.sh, here).
The DIRECTORY is the same three-hook contract: all three resolve it with cc_state_root,
so the file route.sh wrote from `app/Enums` is the one found here from the repo root.
```

### A deleted cwd

```text
A cwd that no longer exists yields no root and this exits; a state file left under
the root by that session is gitignored and orphaned, not misread by the next one
(the key is per transcript).
```

### The surfaced ledger

```text
SURFACED LEDGER. Before the state file goes, append what this session's
router actually surfaced to a machine-local JSONL. This file is the only
record anywhere that a routing rule did anything: until it existed, every
argument this marketplace made about a plugin's worth was made from token
counts and trigger-phrase overlap, because there was no denominator. A rule
that surfaced nothing across N sessions is the cheapest possible retirement
argument, and that sentence was unwriteable while this line was `rm -f` alone.

It records what the router OFFERED, not what the model loaded — hence
`surfaced`, never `usage`. Nothing reads it automatically; the one reader in
this repo is `scripts/turn-cost.sh --skills`, a maintainer path that ranks
skills and never proposes a deletion. (This comment used to name
/hindsight:harvest; grep of plugins/hindsight/ finds zero references to this
ledger — that command has never read it.)
Machine-local ($HOME, never the project tree), same slug rule as
hindsight/hooks/collect.sh, fail-silent, and skipped entirely when
CC_SURFACED_LOG=off. The slug is taken from the PROJECT ROOT, not the payload cwd:
a session that ended after `cd app/Models` filed its row under a slug of its own,
so one project could split into one ledger per directory the model ended in. The only
reader (turn-cost.sh --skills) globs every slug, so the rows it already has stay
counted; they just stop multiplying.
```

## plugins/skill-router/hooks/prime.sh

Editor's note (2026-10-04, card 03): `scripts/generate.sh:216-221` below is stale — the chassis dispatch is now the `case` in `render_chassis` (generate.sh:288-297 on this date), and it renders three chassis types plus `optout`, not four. The rows "PHP side" and "JS side" name skills (plain php, react) that this file no longer primes.

### Header: shebang and contract

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
hold even under a stripped/broken PATH.
SessionStart primer. Sniffs the repo's manifests directly and injects a
one-line index of the skills relevant to this stack, filtered to installed
plugins. Does NOT read stack-scan — that is a conversational skill with no
persisted output a hook could read. Fail-open: any error exits silently.
```

### Header: manifests are read at the project root

```text
MANIFESTS ARE READ AT THE PROJECT ROOT (0.20.0), through the shared `cc_state_root`
block below — the same root route.sh reads its stack markers at. The payload cwd follows
the model's `cd` (rationale/2026-09-25-session-plugin-usage-review.md, finding 2), and
SessionStart fires again on resume and compact, so a session compacted while `cd`-ed
into `app/Enums` was re-primed from THAT directory: no composer.json there, and the
index dropped laravel-best-practices mid-session. Same trade route.sh states: a session
started inside a monorepo workspace used to be primed from that workspace's manifests
and is now primed from the repo root's.
```

### Header: two callers, one table

```text
TWO CALLERS, ONE TABLE. The evidence rows live in `sr_repo_skills` below, and
hooks/subagent-skills.sh SOURCES this file to call it: a subagent is handed the skills
its frontmatter declares only where these same rows find the stack. The rows stay in
THIS file because two gates read them here by path — pc_prime_coverage and
validate.sh's skill-resolution loop both grep prime.sh for `add <skill>` — so moving
them to a separate library would blind both. The hook body at the bottom runs only
when the file is executed; a caller that sources it gets the functions and nothing else.
```

### has, has_dir and dep

```text
Bounded checks against $SR_ROOT — maxdepth caps cost, -print -quit stops at the first hit.
$1 manifest, $2 ERE — a dependency-name match, not a substring anywhere
```

### sr_repo_skills and the skill map it mirrors

```text
sr_repo_skills <project-root> — calls `add <skill> <owning_plugin>` once per row whose
evidence holds. `add` is the CALLER's: the hook body below filters it to installed
plugins and dedups; subagent-skills.sh records the pair and intersects it with an
agent's declared list.

Rows below mirror coding-entry/references/skill-map.md, which is the documented
manifest-shaped map. Keep the two in step; skill-map.md's own header warns that
"two copies of one matcher guarantees that one goes stale", and this file WAS the
unacknowledged third copy. Generating this table from that file is the follow-up
(it needs a fifth chassis type — scripts/generate.sh:216-221 dispatches four and
dies on anything else), so until then the comment is the only thing holding them
together, which is a `recorded` tier and stated as such.
```

### The rows

```text
PHP side. laravel and plain php are stack-EXCLUSIVE per skill-map.md — a Laravel
rules.tsv applies via its `!composer.json~laravel/framework` markers.
JS side. react-native and react are exclusive the same way.
next and vite: declared in skill-map.md's Frontend table since it was written and
absent here, so a Next + Vite + Tailwind repo was primed with package-hygiene,
a11y-audit and tailwind-best-practices and told nothing about the two skills whose
whole subject is those two tools. pc_prime_coverage only checks this file against
the map, never the map against this file, so the gap was structurally invisible.
NOT exclusive of each other: a Next app can carry vite for its test runner, and both
skills are wanted then.
Tailwind requires an actual Tailwind signal. This line previously read
grep -qE '"(react|vue|@?tailwind)' — so ANY React or Vue dependency asserted
tailwind-best-practices on a repo with no Tailwind in it. That is the falsehood
this card exists to remove: it was emitted in the session's FIRST line, and every
blocking gate passed it, because no gate reads this map.
The two rows skill-map.md declared and this file never primed — both were standing
`map-unprimed` WARNs from pc_prime_coverage, and both are file-presence sniffs of the
same shape as the rows above. LIMITATION: `.github/workflows/` is the GitHub signal
only, so a GitLab, CircleCI, Jenkins or Buildkite pipeline primes nothing; and the
MariaDB sniff reads the two canonical compose filenames at the repo root, so a
`.yaml` spelling, a compose file in a subdirectory, or a MariaDB reached over the
network is missed — the same known misses rules.tsv's mariadb rows carry.
```

### The hook body: the plugins directory

```text
Both the flat and the versioned-cache layouts — see hooks/plugins-dir.sh.
```

## plugins/skill-router/hooks/compact-capsule.sh

### Header: shebang and what it re-states

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
hold even under a stripped/broken PATH.

SessionStart, matcher `compact` ONLY. After a compaction, re-states the task
state that lives on disk and that the summary may have dropped: the arc phase
sentinel, a registered task-runner run and its scope lock, and any open
taskmaster ledgers. Every one of those files survives compaction; what does not
survive is the model's knowledge that they exist, so it never thinks to look.
approaches/hooks/compact-recovery.sh solves this for ONE ledger (its own
deliberation marker) and this hook covers the rest; it deliberately does not
mention that marker, so a session with both installed hears each once.
```

### Header: why SessionStart and not PreCompact

```text
WHY SessionStart AND NOT PreCompact. PreCompact stdout goes to the debug log and
never reaches the model — the documented context-injecting events are
UserPromptSubmit, UserPromptExpansion, SessionStart and PostModelSwitch. So the
capsule cannot be planted before the summary; it is re-asserted after it, once.
```

### Header: why skill-router, and the cost

```text
WHY skill-router. It already owns the SessionStart catalog and the per-session
routing state, and it is the plugin most bundles share, so the capsule fires in
the most installs for the fewest declarations.

COST. Matcher `compact` — silent on startup, resume, clear and fork, so the
always-on budget reads 0 (context-budget.sh drives SessionStart with
source=startup). A session that compacts pays one short block per compaction,
and only when at least one ledger exists.
```

### Header: the measurement rider

```text
MEASUREMENT RIDER. The phase sentinel records the session_id that wrote it and
the payload carries the session_id after compaction. Whether those match is the
open question in rationale/collective-taskforce-backlog.md #6 (two shipped
mechanisms key on it). Each firing appends one line to
.claude/skill-router/compact-log.jsonl saying whether they matched. Standing:
recorded — nothing reads it yet; it exists so the answer accrues on real
sessions instead of waiting for a probe that has not been run in 25 days.
The log lives per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/skill-router/ is only the fallback.
```

### Header: limitation

```text
LIMITATION (honest scope):
  - Advisory. SessionStart stdout informs a turn; it cannot block one.
  - Names the files and their headline fields; the reasoning behind a phase or a
    card lives in the summarized transcript and no hook can pull it back.
  - Cannot tell a live ledger from a stale one. It prints the sentinel's own
    started_at and defers to each owner's TTL (taskmaster's reminder hook
    unlinks a sentinel older than its cc_phase_ttl_min).
  - Knows the ledgers it names. A plugin that keeps state elsewhere is invisible
    here — add its path to this file, which is why the list is short and literal.
```

### The project root

```text
Every ledger below lives at the PROJECT root. Read under the payload cwd, a
compaction after `cd app/Models` would find none of them and stay silent while a
run, a scope lock and a phase sentinel sat two levels up (review finding 2 measured
that drift, rationale/2026-09-25-session-plugin-usage-review.md).
```

## plugins/skill-router/hooks/subagent-skills.sh

### Header: shebang and contract

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
hold even under a stripped/broken PATH.
SubagentStart: hand a plugin subagent the Read paths of the skills its own frontmatter
declares in `bestpractices-skill:`, kept to the ones THIS project's stack uses. One
`hookSpecificOutput.additionalContext`, a few hundred characters: an instruction line and
one absolute SKILL.md path per kept skill. The body is NOT injected — the agent Reads it.
```

### Header: why

```text
WHY. `bestpractices-skill:` is this marketplace's own frontmatter key; Claude Code does
nothing with it. Only task-runner's dispatcher turns it into Read paths, so an agent
spawned any other way starts with no rubric. Measured 2026-09-25
(rationale/2026-09-25-session-plugin-usage-review.md, finding 6): three ad-hoc
`ui-ux:ui-ux-reviewer` spawns made 95-101 Read/Grep/Glob calls each and read ZERO
SKILL.md files, while task-runner-dispatched workers in another session read them 156+
times. The host's `skills:` preload was the other fix and was rejected for these lists:
it is stack-blind, so frontend-reviewer in a Laravel/Inertia repo would carry the React
Native and Next.js bodies (~4.4k tokens) on every spawn. Only the stack-independent
`ui-ux:a11y-audit` is preloaded that way.
```

### Header: the filter

```text
THE FILTER is prime.sh's own evidence table (`sr_repo_skills`, sourced from that file so
the SessionStart index and this hook cannot disagree about what the stack is), read at
the project root through `cc_state_root` — which prime.sh defines — so a spawn from a
model `cd`-ed into a subdirectory sees the same stack. A declared skill is kept only when
a row there finds its evidence AND its owning plugin is installed AND its SKILL.md exists.
Declared order is kept. A skill the agent already preloads through the host's `skills:`
key is dropped — its body is in context before this line arrives.
```

### Header: off switches and the silent cases

```text
OFF SWITCHES: CC_SUBAGENT_SKILLS=off silences this hook alone; CC_REMIND=off does too.
CC_SUBAGENT_SKILLS / CC_REMIND unset: the /config options cc_subagent_skills / cc_remind decide.
SILENT also when: the agent type is not plugin-scoped (`Explore`, `general-purpose`, a
project agent), its plugin is not in this marketplace's install root or is disabled, the
definition has no `bestpractices-skill:`, nothing declared matches the stack, or jq is
missing. No marker file: the host itself re-injects a SubagentStart context only when
the subagent's context no longer holds the earlier copy (docs, hooks § SubagentStart,
read 2026-09-25), so a resumed agent does not pay twice.
```

### Header: cost

```text
COST. Every plugin-scoped spawn (the hooks.json matcher keeps built-in agents out) runs
one jq read, one awk over the agent file and, when a list exists, prime.sh's evidence
rows: manifest greps plus up to ten `find -maxdepth 3 -print -quit` calls — measured
200-265 ms per spawn on two real Laravel/Inertia repos with 282 MB and 422 MB of
node_modules (2026-09-25). The output is capped at CAP characters, about 600 in practice;
a path past the cap is dropped whole, never cut mid-path.
`scripts/context-budget.sh` executes SessionStart, UserPromptSubmit and Pre/PostToolUse
hooks only, so this channel is NOT metered there.
```

### Header: limitations

```text
LIMITATIONS, stated rather than implied:
  - A declared skill prime.sh has NO evidence row for (motion-best-practices,
    security-review, performance-tuning, observability-design) is never injected: no
    manifest can say it applies, and an unconditional Read is the stack-blind cost this
    hook exists to avoid. Those agents get what their own body text tells them, as before.
  - The filter inherits prime.sh's misses: a11y-audit is evidenced by a .tsx/.jsx file
    within three levels of the root, so a11y-engineer in a Vue- or Blade-only repo is
    told nothing; devops-practices needs `.github/workflows/`; a monorepo whose manifests
    sit in a workspace below the root reads as having none.
  - Advisory: additionalContext cannot make the agent Read. Probed ONCE live (CLI
    2.1.282, haiku, --plugin-dir, a Laravel/Inertia repo): web-dev:frontend-reviewer
    received exactly the inertia and vite paths, as "SubagentStart hook additional
    context" in its own transcript, and quoted them back. Whether an agent then READS
    them on a real task is unmeasured.
  - "This marketplace" means the plugins root resolved from this hook's own
    CLAUDE_PLUGIN_ROOT (hooks/plugins-dir.sh). Another marketplace's plugin with the
    same name as one here is resolved against this one's definition.
```

### No plugins root

```text
No root, no path to name: unlike route.sh's fire-if-uncertain, silence is the only
honest output here.
```

### Finding the agent definition

```text
The host reports the frontmatter `name`, not the filename; they agree across this
marketplace today, and the scan covers the day one does not.
```

### Reading the frontmatter

```text
Frontmatter only — the same read validate.sh's stack-authoring guard uses. `skills:`
is read inline (`[a, b]` or `a, b`) and as a block list; a plugin prefix is dropped.
```

## plugins/skill-router/hooks/plugins-dir.sh

Editor's note (2026-10-04, card 03): route-prompt.sh no longer sources this file or builds a catalog; its callers are route.sh, prime.sh and subagent-skills.sh.

### Header: what it is and why it exists

```text
Layout-agnostic resolution of the installed-plugins root. Sourced by prime.sh,
route.sh and route-prompt.sh — the three hooks that need to see SIBLING plugins.
Not executable and has no shebang: it is only ever sourced.

WHY THIS EXISTS. All three hooks used `dirname "$CLAUDE_PLUGIN_ROOT"`, which is
the plugins root only under a FLAT layout (`<plugins>/<plugin>`). A real install
is VERSIONED (`<marketplace>/<plugin>/<version>`), so dirname landed on
`<marketplace>/<plugin>`, whose only children are version directories. Every
`[ -d "$plugins_dir/<sibling>" ]` check then reported the sibling missing, the
installed-filter suppressed every rule, and `route-prompt.sh`'s catalog glob
matched nothing — the router was silent on every real install. The smoke
fixtures build a flat layout by construction, so CI stayed green throughout.
Both layouts are now resolved, and `versioned-layout-tests.sh` runs the whole
suite a second time against a versioned fixture so this cannot regress silently.
```

### Header: detection is one rule

```text
DETECTION IS ONE RULE: `CLAUDE_PLUGIN_ROOT`'s basename is version-shaped
(`0.10.0`, `v1.2`, `2`) → versioned, the root is two levels up; anything else →
flat, one level up. It needs neither a plugin.json nor a probe of sibling
directories, so it holds on a partially populated cache and on a checkout whose
siblings are bare directories. No plugin is named like a bare version number.
```

### Header: residual — the version pr_plugin_root picks

```text
RESIDUAL, stated rather than implied: the cache keeps every version ever
installed (6 of skill-router on the machine this was found on) and nothing on
disk marks which one is enabled. `pr_plugin_root` returns the highest version it
can order, which is a guess — a good one, and the callers only use it to name a
path they have already confirmed exists. It is not a claim about which version
Claude Code loaded.
```

### pr_resolve_plugins_dir

```text
Empty PLUGINS_DIR is the fire-if-uncertain case every caller already handles:
route.sh and prime.sh surface the skill anyway, route-prompt.sh skips its
catalog. Both are the safe direction for their respective jobs.
Version-shaped: reject anything with a character a version cannot carry,
so a plugin named `2fa-helper` stays on the flat branch.
```

### pr_load_enabled: enablement

```text
---- enablement -------------------------------------------------------------
WHY THIS EXISTS. pr_plugin_roots walks every directory under PLUGINS_DIR. On a
real install that root is the versioned CACHE, which keeps every plugin ever
installed — including plugins later dropped from the marketplace and bundles the
user switched off. Version dedup ran on that list and the stack filter ran on it;
enablement never did. So route-prompt.sh's catalog advertised commands that
cannot be invoked, at the exact surface where the model picks a tool. Measured on
the machine this was found on: 20 of 108 advertised commands were unreachable,
16 of them owned by plugins no longer present in marketplace.json.

FAIL OPEN, deliberately, and it is the same bias the rest of this file declares.
PR_ENABLED stays EMPTY whenever enablement cannot be read — jq absent, no
settings file, no enabledPlugins key — and an empty set filters nothing, which is
byte-for-byte the previous behaviour. Only a plugin we can positively prove is
not enabled gets suppressed.

LAYERS. enabledPlugins is settable at user and project scope, so the set is the
UNION of every file readable here. Reading one layer would suppress plugins that
another layer legitimately enables. A key is `<name>@<marketplace>`; the
marketplace half is dropped because every consumer here addresses plugins by
bare name.

HONEST LIMIT, stated rather than implied: managed-policy settings are not read.
On a fleet that enables plugins ONLY through managed policy, some other layer
will usually still list something, and those policy-enabled plugins would then be
filtered out. That is the one case where this can suppress a live plugin, and it
is why the union above is as wide as it is.
```

### pr_load_enabled: the scope guard

```text
SCOPE GUARD, and it is the whole reason this is safe. `enabledPlugins`
describes the user's OWN install and nothing else. PLUGINS_DIR is not always
that tree: smoke harnesses build scratch roots under $TMPDIR, a vendored
checkout resolves here, and so does a second marketplace. Against those trees
the enabled set is not an authority, and applying it suppressed every row —
which is exactly how this was caught, by versioned-layout-tests.sh and
route-marker-tests.sh going red the first time the filter shipped without
this guard.

So the settings under <config> govern only trees UNDER <config>. Anything
else falls back to the undeterminable path and keeps every plugin, which is
the previous behaviour. A name-overlap heuristic was tried first and is not
enough: a scratch tree that happens to contain one real plugin name would
activate the filter and then suppress every fixture-only sibling.
```

### pr_plugin_installed: fire-if-uncertain

```text
"Fire-if-uncertain" is the router's declared bias: a nudge toward a plugin that
turns out to be absent costs one line; a suppressed nudge costs the whole point
of the router, which is exactly the failure this file was written for.
```

### pr_plugin_root

```text
$1 owning_plugin → prints that plugin's CONTENT root (the directory holding
skills/, commands/, agents/), or nothing. Under the versioned layout that is one
level deeper than the plugin directory, which is why callers cannot just join
paths onto PLUGINS_DIR themselves.
Highest version wins. `sort -V` is not POSIX and is absent on some BSD
userlands; a lexical sort can pick 0.9.0 over 0.10.0, which is a valid
installed version and a worse guess, never a broken path.
```

### pr_plugin_roots

```text
Exactly one line per plugin whatever the layout — a versioned cache holding six
releases of one plugin must not put six copies of its commands in a catalog.
```

## plugins/skill-router/scripts/__tests__/route.test.sh

### Header

```text
Author-time tests for hooks/route.sh — the PostToolUse file router — and for the
state-root contract it shares with route-prompt.sh (flush) and summary.sh (ledger).

Drives the hooks with host-shaped payloads (tool_name, session_id, transcript_path,
cwd, tool_input) against temp GIT repos, because both halves of 0.20.0 depend on one:
a Bash write routes only under the project root, and the project root is the git
toplevel (rationale/2026-09-25-session-plugin-usage-review.md, findings 1 and 2).
Every Bash case RUNS its command first, in the payload cwd — PostToolUse fires after
the tool, and the hook reads the file the command left on disk.

Asserts: a heredoc write routes the same skills an Edit of that file does, and its
content signal reaches pending_low; a Bash call with no write target, with a target
that is missing afterwards, or with a target outside the root is silent and creates
no state; a payload cwd in a subdirectory keeps state at the repo root, leaves no
`.claude/` in the subdirectory, and still matches `**/app/**` and reads the root's
manifest; directory globs match the ROOT-relative path; the per-signal one-shot holds
across an Edit then a Bash write; one envelope per call; the 8-target cap; CC_REMIND.
This session exports it, pointing at the marketplace repo; cc_state_root honours it
outside git, so a stray value would make a fixture look like part of this repo.
```

### The 2026-09-26 routing review cases

```text
---- routing review 2026-09-26: content+high inline, wrong-route fixes, new rows, and the
     Bash `command` signal. Every case uses its own transcript unless it tests the
     one-shot, so a skill fired by an earlier case cannot mask a later one.
```

## plugins/skill-router/scripts/__tests__/compact-capsule.test.sh

### Header

```text
Author-time tests for hooks/compact-capsule.sh — the SessionStart(compact)
capsule that re-states on-disk task state after a compaction.

Drives the hook with the payload shape the host sends on SessionStart
(session_id, cwd, source) and asserts: silent on every non-compact source,
silent when no ledger exists, names each ledger it knows with its file path,
says whether the phase sentinel was written by this session, appends one
measurement line per firing, fails open on malformed ledgers, and — with the payload
cwd in a SUBDIRECTORY of a git repo — still reads the ledgers at the repo root and
writes nothing into the subdirectory.
This session exports it (pointing at the marketplace repo); cc_state_root honours it
outside git, so the harness must not inherit it.
```

## plugins/skill-router/scripts/__tests__/subagent-skills.test.sh

### Header

```text
Author-time tests for hooks/subagent-skills.sh — the SubagentStart hook that hands a
plugin subagent the Read paths of its declared `bestpractices-skill:` list, filtered to
this project's stack by prime.sh's evidence rows — and for prime.sh reading manifests
at the project root rather than the payload cwd (0.20.0).

Runs the REAL hooks against a FAKE installed marketplace: the versioned cache layout a
real install uses (`<cache>/<marketplace>/<plugin>/<version>/`), holding the real agent
files of web-dev, laravel, ui-ux and code-review (their frontmatter is what is under
test) and a stub SKILL.md for every skill those plugins ship. CLAUDE_PLUGIN_ROOT points
into that cache, which is all hooks/plugins-dir.sh reads to find the siblings.
Payload shape per the hooks docs § SubagentStart (session_id, transcript_path, cwd,
hook_event_name, agent_id, agent_type), agent_type plugin-scoped (`web-dev:frontend-reviewer`).

Asserts: a Laravel/Inertia repo gives frontend-reviewer inertia (plus vite when
package.json declares it) and never react-native or nextjs; a Next.js repo gives it
nextjs; a declared skill whose plugin is absent is dropped; a skill the agent preloads
via `skills:` is dropped; an agent without the field, a built-in or unknown agent type,
and both off switches are silent; a subdirectory cwd gives the same output as the root;
the output is one SubagentStart envelope under the byte cap, paths whole; and prime.sh
primes the same line from a subdirectory as from the root.
This session exports it, pointing at the marketplace repo; cc_state_root honours it
outside git, so a stray value would make a fixture look like part of this repo.
```

### Section banners

```text
--- fake installed marketplace ------------------------------------------------------
--- fixture repos -------------------------------------------------------------------
--- drivers ---------------------------------------------------------------------------
```
