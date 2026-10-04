# command-guard hooks: the comment text moved out of the code (2026-10-04)

The text below was moved verbatim on 2026-10-04 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-command-guard.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/command-guard/hooks/destructive-guard.sh

### Header

```text
Absolute-path shebang (not `env bash`): the fail-open guarantee has to hold even
under a stripped or broken PATH, where `env bash` itself exits 127.

PreToolUse guard on COMMAND EXECUTION — the Bash tool plus any MCP tool that
shells out or runs SQL. It classifies the command about to run:

  deny  — irreversible data loss whose blast radius cannot be read off the
          command line (`php artisan migrate:fresh`, `DROP DATABASE`,
          `docker compose down -v`, `aws s3 rb`, `terraform destroy`). The
          model is stopped; only a human can run these.
  ask   — destructive but commonly intended and scoped (`git reset --hard`,
          `kubectl delete pod`, and `rm -rf ./some-dir` only when git cannot
          restore the path — see the recoverability check). The user answers.
  allow — everything else. The hook stays silent and normal permissions apply.

The failure it exists for: an agent runs a schema-reset command mid-task
because a migration looked stuck, and the data is gone before anyone reads the
transcript. Nothing asks, because `php artisan migrate:fresh` is an ordinary
command that happens to be terminal.

Fail-open by construction: any error, missing jq, or unparseable input allows
the call. A guard that breaks the session gets uninstalled, and then it guards
nothing.

The allow-file (.claude/destructive-guard-allow) disarms every deny, so a Bash command
naming it passes only when EVERY segment is a pure read: cat head tail wc grep egrep fgrep
stat ls file diff cmp, or git log/show/diff/blame/grep/ls-files/cat-file with the subcommand
first and no output, pager, ext-diff, textconv, filters or -c option; redirects only to
/dev/null or a descriptor; no backtick, $, ~, {}, unquoted # or paren, or env assignment;
the reader's name typed bare. Everything else naming it is denied, so awk, sed -n, find, jq
and less on it are blocked — use cat/grep. WHAT IT DOES NOT CATCH: a path built from a
variable or a glob, a script file that writes it, and any program git config names (a diff
driver, textconv, clean filter, pager, core.fsmonitor, gpg.program via --show-signature),
set before the command runs. The name is matched in any ASCII letter case, in a command, a
Write/Edit path, an *apply_patch body and a *create_new_file path: a case-insensitive
filesystem opens one file under each such spelling (on a case-sensitive one a differently-cased
sibling is over-denied — harmless). NOT caught on the write path: any other MCP write tool,
NotebookEdit's notebook_path, and a non-ASCII spelling the filesystem folds to the name.

CLAUDE_DESTRUCTIVE_GUARD, read from the hook's own environment:
  unset      deny + ask, as above
  deny-only  the hard stops only; the ask tier falls through silently to
             whatever the host does next. Worth it when the host runs a
             permission classifier of its own: a hook `ask` OVERRIDES that
             classifier, so the ask tier turns a silent host judgement into a
             human click. Outside auto mode nothing replaces it — see README.
  ask        every deny becomes a prompt instead of a block
  off        disabled
Unset in the environment, the /config option claude_destructive_guard decides.

CLI mode for testing and for /command-guard:check — always reports the true
tier, including an ask that deny-only would suppress:
  destructive-guard.sh --check '<command>'   exit 0 allow | 1 ask | 2 deny
```

### Normalisation banner, over norm_cmd

```text
---------------------------------------------------------------------------
Normalisation. Every rule matches against a canonical form, because the raw
string has too many ways to say the same thing: extra whitespace, quotes
around a subcommand (`artisan "migrate:fresh"`), backslash escapes, a leading
`sudo`. Quote stripping is what makes the quoted-evasion forms match the same
rule as the plain one.
---------------------------------------------------------------------------
```

### split_segments

```text
Segment a command on shell separators (; && || | newline) so a rule fires on
the segment that would EXECUTE the match, not on a segment that merely quotes
it. Splitting is quote-aware on the RAW string — dequoting first would split
`grep -E "a|rm -rf /"` into a fake `rm -rf /` segment.

The walk runs ONCE, in END, over the whole input. It used to run per record
under RS = "\0", which BWK awk (macOS) reads as paragraph mode: a blank line
started a new record with `seg` still holding the previous one, so
`ls a` + blank line + X came back as a single reader-led segment `ls aX`.
And a backslash escapes nothing inside '…' — treating it as an escape there
left `'x\'` open, swallowing the `;` after it. The exception is $'…', where
\' IS an escape (`ans`). After two or more `$` the shells disagree — bash opens
a plain quote, zsh an ANSI one — so the walk stops trusting quotes and escapes
for the rest of the command (`raw`) and splits on every separator: too many
segments can only add a verdict, never hide one. check_cd_chain copies this walk.
```

### lead_word

```text
First real word of a segment, with the wrappers that carry no semantics of
their own stripped: sudo, env assignments, time, nohup, xargs -I{} …
```

### READERS and the reader exemption

```text
Segments whose lead word only READS are skipped: `grep -r "migrate:fresh" .`
is a search, not a migration. The exemption is dropped for the whole command
when its output is piped into a shell — there the reader's output IS the
program.
```

### git_safe_subcmd

```text
git subcommands that cannot lose committed or working-tree data. `commit` is
on the list for a reason beyond safety: a commit MESSAGE is prose, and prose
about a migration ("remove the drop table step") would otherwise trip the SQL
rules. The destructive subcommands — reset, clean, push --force, branch -D,
checkout/restore, stash, gc, reflog, filter-branch, update-ref — are absent by
design and stay subject to the table.
```

### SQL_CLIENT_RE

```text
Anything that speaks SQL, including the wrappers people reach it through
(`docker compose exec db psql …`, `ssh host mysql …`, `php artisan tinker`).
Tested against the WHOLE command, not the segment, because a heredoc body
(`mysql <<SQL` / `DROP TABLE x;` / `SQL`) splits into segments that no longer
name the client.
```

### Rule table banner: the row format and how a regex matches

```text
---------------------------------------------------------------------------
Rule table. TAB-separated: TIER \t REGEX \t WHAT \t ALTERNATIVE

Regexes are POSIX ERE matched against the normalised segment, which is padded
with a leading and trailing space — so ` rm ` matches a bare `rm` at either
end. A regex containing an uppercase letter is matched CASE-SENSITIVELY
against the case-preserving form (that is the only way `git branch -D` can be
told from `git branch -d`); every other rule matches the lowercased form.

deny rules are listed first and win: the loop takes the first hit.
---------------------------------------------------------------------------
```

### The case-sensitive rule convention, in the rule loop

```text
A rule carrying an uppercase letter is case-sensitive by convention —
`git branch -D` must not match `git branch -d`.
```

### Verdict state

```text
---------------------------------------------------------------------------
Verdict state, set by classify()
---------------------------------------------------------------------------
the command changes directory, so this process's cwd is not
the one the rm will resolve against — see git_recoverable
"cd" when the deny is a failing-cd chain: its reason differs
because re-issuing the FIXED command is the expected next move
```

### ARTIFACT_RE

```text
Build artifacts: regenerated by a build, so `rm -rf` on them is ordinary work
and prompting on it would train the user to click through the prompt.
```

### temp_remainder and is_temp_path: the OS temp directory

```text
The OS temp directory. A path INSIDE it is scratch by definition — the system
clears it on boot and every `mktemp -d` on the machine lands there — so
deleting one is ordinary work, the same call ARTIFACT_RE already makes for
node_modules. Before this, every absolute path was "outside the project" and
asked; a prompt the user always clicks through is a prompt they stop reading,
which costs the prompts that matter.

INSIDE is the whole rule. The roots themselves stay denied, because emptying
/tmp destroys state belonging to every other process on the machine and not
just this session's. So a token must name a root PLUS a component under it.

macOS per-user temp: /var/folders/<ab>/<hash>/<T|C>/… — the three
components under /var/folders ARE the root, so anything shallower than
that is the root itself or a sibling, not a path inside it.
$TMPDIR / $TMP are read from the HOOK's own environment — the environment
the Bash tool's shell inherits, same process tree — so this is the real
value, not a guess. Unset means unresolvable and returns 1, dropping the
token to the variable-collapse ask below: `rm -rf $TMPDIR/build` with
TMPDIR unset is `rm -rf /build`, which is not a temp path at all.
A glob may sit inside the scratch directory, but it must not BE the first
component: `/tmp/*` is the root emptied under a different spelling.
```

### git_recoverable

```text
Can git hand this path back? Either it is not there (deleting it is a no-op)
or every byte under it is committed and `git restore` returns it. Deleting
such a path is not a loss, and prompting on it is how a user learns to click
through prompts — including the ones that matter.

Fails CLOSED: no git, not a repo, untracked or modified or IGNORED content
under the path, a glob whose expansion is unknown — all return 1, and the
caller asks. Ignored files count as a loss precisely because git has no copy:
a `.env` under the directory is the case this guard exists for.

Called ONLY from the branch that was about to ask a human, so it adds no git
call to an ordinary Bash tool call.
`cd /elsewhere && rm -rf src` resolves src somewhere this process is not.
The segment splitter judges the rm alone, so the only safe answer is to
stop trusting cwd for the whole command.
```

### check_rm

```text
`rm -rf` is the one rule that cannot be a regex: whether it is catastrophic
depends on the TARGET, and the targets live in the same string as the flags.
tokens after the rm word
A single-component absolute path (/etc, /var, /usr) is a system directory.
This has to be a regex: a shell `case` glob cannot say "no slash after the
first one" — `/[a-z]*` matches /opt/app/releases/12 too, which silently
made every absolute path a deny.
The temp roots in their multi-component spellings. `/tmp` is already a deny
by the rule above; these name the same directories and must agree with it,
or the exemption below becomes the way to spell the root.
build artifact: fine
In-project path git can restore: not a loss, so not a prompt. `..` and
absolute paths are excluded — they can leave the repo the check consults.
```

### The allow-file: ALLOW_BASENAME and allow_file_pure_read

```text
The allow-file is the human's opt-out. It is only an opt-out if the model
cannot write it — so writing it is itself blocked, in both directions (this
check for Bash, the tool_name branch below for Write/Edit).
Every segment, not only the one naming the file: `hash -p /bin/cp cat; cat x <allow-file>`
is a cp wearing a reader's name. The split keeps `2>&1` and `&>` whole, unlike split_segments.
```

### check_whole

```text
Whole-command rules: shapes the segment splitter would cut in half, because
the separator IS the hazard.
```

### .env overwrite: is_env_secret, env_target_at_risk, deny_env_overwrite, check_env_overwrite

```text
---------------------------------------------------------------------------
.env OVERWRITE. The rule table already denies `rm .env` and `> .env`; this
covers the writers that replace the file under another name — cp/mv/install/
ln/rsync onto it, tee into it, and `artisan key:generate`, which rewrites
APP_KEY in place.

WHY (2026-09-24). An agent building a throwaway checkout ran
  cd /tmp/dq-bg && …; cp .env.example .env && php artisan key:generate
The worktree had never been created, the cd failed, the `;` carried on, and
both writes landed in the live repo: every credential gone, and everything
encrypted with the old APP_KEY unreadable. Nothing asked, because each command
is an ordinary setup step in a fresh clone.

That is also why this is decided by STATE, not spelling: `cp .env.example .env`
in a clone with no .env is the setup step, and denying it would teach the user
to switch the guard off. A target is AT RISK when it exists and git has no
clean copy of it — or when the command moves directory, because then the guard
cannot tell which .env the relative path lands on (the incident exactly). An
absolute path inside the OS temp directory is scratch and never at risk.
---------------------------------------------------------------------------
Tokens after the lead word, flags dropped. A flag that takes a value (-t DIR,
-S suffix) is a residual: the directory form is not resolved.
A truncating `> .env.local` (the rule table already owns a bare `.env`).
norm_cmd spaces every `>`, so an append arrives as `> >` and is skipped:
appending a line loses nothing.
```

### check_cd_chain: a failing cd in a ;-chain

```text
---------------------------------------------------------------------------
FAILING cd IN A ;-CHAIN. `cd X; step` runs `step` whether or not the cd
worked, and the Bash tool's shell keeps its working directory between calls,
so a failed cd drops every later step into the live project. That is the
second half of the incident above: `cd /tmp/dq-bg && …; cp .env.example .env`
with /tmp/dq-bg never created.

Fires only when it is certain the cd fails: the target is an ABSOLUTE (or ~)
path that does not exist right now, no earlier segment of the same command
names it (so `mkdir -p X; cd X; …` passes), the cd's &&-chain ends in `;` or a
newline rather than || (`cd X || exit`), something follows that `;`, and no
`set -e` precedes it. A relative target is not judged: the hook cannot be sure which directory
the Bash tool's shell is in, and a false deny here costs a turn every time.
---------------------------------------------------------------------------
awk emits one line per segment: <separator-after>\t<segment text>. Same
quote-aware walk as split_segments, keeping the separator it cut on.
`cd X && a && b; c` fails the same way the incident did: a failed cd skips
the && chain, then the `;` hands c to the live directory. So follow the
chain (&& and |) to the first separator that ends it; only `;` is a hazard.
```

### classify

```text
---------------------------------------------------------------------------
---------------------------------------------------------------------------
SQL rules only fire when something in the command speaks SQL. Without this
gate, `git commit -m "remove the drop table step"` and
`npm test -- --grep "delete from users"` both read as executed SQL.
An MCP SQL tool's payload IS the statement — there is no client name in it
to sniff, so sniffing was gating every SQL rule off for exactly the tool the
plugin claims to cover. The hook sets this from tool_name/field instead.
Env-set, so it can only ever turn SQL rules ON.
Output piped into a shell: the reader exemption is off for this command,
because `echo "rm -rf /" | sh` is not an echo.
A segment that REDIRECTS is a write, whatever its lead word claims:
`echo x > .env` truncates the credentials it says it is only printing to,
and `cat /dev/null > app.sqlite` empties a database. Same reasoning as
check_self_protection, generalised — the redirect is the effect — so such
a segment skips BOTH the reader and the git-safe exemption and goes to the
rule table. norm_cmd spaces every `>`, so this catches `>>` too.

This is also the third of the three vectors that killed the self-exemption
below (`… --check foo > /dev/<rawdisk>`): a redirect is evaluated by the
shell whatever argv claims, which is exactly why no lead word may buy a
segment its way past classification.
`git clean -n` / `--dry-run` deletes nothing — it is the preview the
ask-tier's own alternative text tells the model to run first. Asking on
the preview trained a click-through on the exact command that makes the
real one safe. `-f` alongside `-n` is still a dry run (git ignores the
force), so the test is for the n flag, not for the absence of f.
Human opt-out, checked last so it can release a deny. Regex per line,
matched against the whole normalised command.
```

### Git global options, now strip_git_global_options

```text
git GLOBAL OPTIONS sit between `git` and the subcommand, and every git rule
below is written as ` git <subcommand> …`. `git -C /path push --force`,
`git -c core.pager=cat reset --hard` and `git --git-dir=… clean -fd` therefore
matched nothing and were allowed — measured 2026-09-14 — even though `-C` is
the form an agent reaches for whenever it works outside its cwd. Strip the
option words so the rules see `git push --force`. Only options that take
their value inline or as the next word are handled; an unknown option is
left alone and falls to the old behaviour.
```

### No self-exemption for the guard's own --check

```text
NO SELF-EXEMPTION. THIS IS DELIBERATE, AND IT WAS TRIED TWICE.

The problem it tried to solve is real: this guard denies the exact command
its own /command-guard:check tells the model to type, because that command
carries the deny-tier target as an argument and arrives through the Bash
tool. See commands/check.md, which now states the limitation instead.

Attempt 1 (0.2.0) matched `bash … destructive-guard.sh … --check` as
substrings anywhere in the segment. Bypassed by `bash -c PAYLOAD name arg…`,
which runs PAYLOAD and demotes the appended magic words to $0/$1.

Attempt 2 (0.2.1) matched by ARGV POSITION — word 1 bash/sh, word 2 the
guard's own path, word 3 --check. That closed the arg-shifting wrapper and
was still bypassed three ways, because the exemption's `continue` skips
classification of the WHOLE segment while a shell segment carries side
effects the shell evaluates independently of argv:
    …guard.sh --check "$( <destructive> )"    command substitution
    …guard.sh --check ` <destructive> `       backticks
    …guard.sh --check foo > /dev/<rawdisk>    redirection
In each, the payload runs before or beside the classifier that argv says
is all that happens.

The lesson generalises past this plugin: an exemption keyed on what a
command LOOKS like cannot be safe when the shell will evaluate parts of
that same string on its own terms. Any third attempt has to classify the
segment anyway and suppress only the verdict arising from the --check
ARGUMENT — which means parsing shell grammar, which this guard
deliberately does not do. A convenience command is not worth a hole in a
deny gate, so the convenience loses.

The bypass vectors are pinned as DENY assertions in
scripts/__tests__/destructive-guard.test.sh § self-exemption. If someone
adds an exemption again, those assertions are what should stop it.
```

### Reason text and plan_audit_hint

```text
---------------------------------------------------------------------------
Reason text. It has one job beyond explaining: stop the retry loop. A model
that reads "blocked" without reading "do not rephrase" will try the same
command with different quoting, and each attempt costs a turn.
---------------------------------------------------------------------------
An `ask` is only worth the interruption if the person answering can find out what
the command would do. For a terraform/tofu apply they can: the devops plugin ships a
plan reader that exits 2 when the plan destroys a stateful resource. devops is a
SIBLING plugin, so the path is resolved from this hook's own root and named only when
the file is actually there — naming a path the reader does not have on disk is the
defect ops finding 3 fixed elsewhere in this marketplace. Panel finding 43.
```

### CLI mode, now check_cli

```text
---------------------------------------------------------------------------
CLI mode
---------------------------------------------------------------------------
```

### Hook mode: guard_file_write and guard_command

```text
---------------------------------------------------------------------------
Hook mode. Everything below fails open.
---------------------------------------------------------------------------
Write/Edit branch: the allow-file is a human artefact. Denying the model's
edit is what makes it an opt-out rather than a formality.
`*apply_patch|*create_new_file` are the MCP file-write tools an IDE-driven session
uses instead of the four host names. Without them the allow-file — the one file that
disarms this guard — was editable through any MCP server while the host tools were
blocked, which is the protection inverted. `pathInProject` is create_new_file's key;
apply_patch carries no single path, so the patch BODY is checked for the basename
instead (a patch that rewrites the allow-file must name it in its header).
A whole-file Write onto an existing .env replaces every credential in it,
and git has no copy. Edit is a targeted change and stays silent; so does a
Write that creates the file. Ask, not deny: the user may mean it.
Command-execution tools: the Bash tool, plus MCP tools that shell out or run
SQL. Named explicitly rather than by wildcard so an unrelated MCP tool whose
arguments happen to contain "drop table" is not gated.
SQL context, told rather than sniffed. A `query`/`sql` field, or a tool
named for SQL, is a SQL statement by declaration — bare `DROP DATABASE x`
carries no client name for SQL_CLIENT_RE to find.
CLAUDE_DESTRUCTIVE_GUARD=ask downgrades every deny to a prompt. It is
read from the hook's own environment, which a command string cannot
reach — `CLAUDE_DESTRUCTIVE_GUARD=off rm -rf /` does not disable it.
deny-only: stay silent on the ask tier. That tier is where this guard
overlaps the host's own auto-mode classifier, and a hook `ask` OVERRIDES
that classifier — it converts a judgement the host would have made
silently into a human click. Under deny-only the hard stops stay and the
host decides the rest. Costs: nothing gates the ask tier when the host is
NOT in auto mode, so this trades coverage for interruptions knowingly.
```

## plugins/command-guard/hooks/config-guard.sh

### Header

```text
Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
even under a stripped PATH where `env bash` exits 127.

PreToolUse guard on the agent's OWN guardrails. Returns `ask` — never a bare deny —
on a write that would weaken the configuration deciding what the agent may do:

  settings           .claude/settings.json, settings.local.json, ~/.claude/settings.json
  hooks              any hooks.json, any plugins/*/hooks/*.sh
  plugin manifests   .claude-plugin/plugin.json, marketplace.json
  lint/test config   .eslintrc*, eslint.config.*, .rubocop.yml, ruff.toml, pyproject.toml,
                     phpstan.neon[.dist], psalm.xml[.dist], .php-cs-fixer[.dist].php,
                     tsconfig.json, .golangci.y[a]ml, pytest.ini, setup.cfg, .flake8,
                     biome.json, clippy.toml

The list above is the `case` below, spelled out: the two must be read together, because
a file named here and absent there is a promise nothing keeps. pyproject.toml was in
the code and missing from this list for its first four releases.

WHY. Given a gate it cannot satisfy, the cheapest path out is to edit the gate — turn
off the rule, lower `strict`, add the file to an ignore list, delete the hook. It is
not malice, it is gradient descent, and it is invisible in a diff summary that reads
"updated config". Prose cannot reach it: the model is not violating an instruction it
remembers, it is solving the problem in front of it. A guard that fires at the moment
of the write is the only thing that turns the move into a decision the user makes.
(`karanb192/claude-code-hooks`'s `config-guard` is prior art and cites CVE-2026-25725;
this one is narrower — ask, not deny — because a legitimate config edit is common.)

WHY `ask` AND NOT `deny`. Editing these files is often exactly the task ("add a
permission", "wire a hook", "bump the plugin version"). A deny would be wrong most of
the time it fired. An ask costs one keystroke on a legitimate edit and is the whole
mechanism on an illegitimate one, because the illegitimate case is precisely the one
the user would not have approved had they been asked.

BASH WRITES (0.7.3). On Bash the guard reads the command's write targets through
cc_bash_write_targets (the block below): a `>`/`>>` redirect, `tee`, `sed -i`, `perl -i`.
At most 8 targets per call; a relative one resolves against the payload cwd, and the
first that classifies AND exists gets the same ask as a Write; a `~/` target expands to
$HOME. NOT caught on Bash: interpreter writes (python open(), php file_put_contents),
cp/mv/install destinations, `{ …; } > f` groups, a path held in a variable, a globbed
target, a dot-named config right after a bare `sed -i` with another file after it (read
as BSD's backup suffix), sed/perl behind another command word (`gsed`, `/usr/bin/sed`,
`env`, `xargs`, `command`, `find … -exec sed -i`), a digit- or `&`-led redirect onto a
config (`2> tsconfig.json`, `&> .eslintrc.json`) and `>&` onto one (`cmd >& tsconfig.json`),
a `\` continuation, a relative target after an in-command `cd` (it resolves against the
payload cwd), the 9th target on, and `rm` of a config or hook — a deletion, which stays
destructive-guard.sh's.
Both hooks now run on Bash, and each emits its own verdict.

WHAT IT DOES NOT CATCH, stated because the README tiers this:
  - A weakening in a file this list does not name. The list is literal, not clever.
  - Any judgment about WHETHER the edit weakens anything: it does not parse the file,
    it asks about the path. Adding a rule and deleting one look identical here.
    That half is agent-graded and the ask text says so.
  - The first write that CREATES one of these files (there is nothing to weaken yet),
    which is why a missing target is allowed through.

Off with CC_CONFIG_GUARD=off. Fail-open on every error path.
CC_CONFIG_GUARD / CLAUDE_DESTRUCTIVE_GUARD unset: their /config options (lower-cased) decide.
```

Editor's note (2026-10-04, on the move): one item of the NOT-caught list above was stale — a `{ …; } > f` group is
caught (`{ echo x; } > tsconfig.json` asks over an existing `tsconfig.json`), so the header's `Misses:` line does not name it.
The cap of 8 is the constant `MAX_BASH_TARGETS`.

### config_kind

```text
A hook SCRIPT, not just its manifest.
```

### The sibling's switch: CLAUDE_DESTRUCTIVE_GUARD

```text
HONOUR THE SIBLING'S SWITCH. The core-suite README (the suites were retired
2026-09-26) told an installer that
CLAUDE_DESTRUCTIVE_GUARD=deny-only buys "the free half" — no clicks — but this
guard is the plugin's OTHER ask tier and read only its own variable, so the
documented setting did not deliver what it promised. Both values that mean
"no ask tier" now silence this hook too. Measured 2026-09-15.
```

### A missing file, and the marketplace self-exemption

```text
(A brand-new hooks.json is how a guard gets INSTALLED.)
Self-exemption: this marketplace's own repository edits these files as its product.
Keyed on the marketplace manifest at the repo root, not on a plugin name, so a
consumer repo that happens to vendor a plugin is still guarded.
```

## plugins/command-guard/scripts/__tests__/destructive-guard.test.sh

### Header

```text
Tests plugins/command-guard/hooks/destructive-guard.sh.

Picked up automatically by the repo's "Plugin author-time lint + harness tests"
CI step, which globs plugins/*/scripts/__tests__/*.test.sh.

Four sections, in the order the guard can fail a user:
  1. CLASSIFICATION — a corpus of commands with the tier each must get. The
     ALLOW rows are the important half: a guard that fires on `git commit -m
     "remove the drop table step"` gets switched off within a day, and then it
     guards nothing.
  2. EVASION — the same destructive command wearing quotes, a wrapper, extra
     whitespace, a heredoc. Each must land on the same verdict as the plain
     form, or the deny is decorative.
  3. HOOK PROTOCOL — real PreToolUse stdin: the JSON shape, the tool_name
     filter, the allow-file branch on Write/Edit, the env modes.
  4. FAIL-OPEN — no jq, malformed JSON, empty input. The guard must stay
     silent and exit 0; a guard that breaks the session is uninstalled.

The harness snapshots `git status --porcelain -- plugins/command-guard` before
and after and asserts it is byte-identical: these tests drive a script whose
entire subject matter is destroying things, so proving it touched nothing is
part of the test. SCOPED to this plugin's own directory on purpose — an
unscoped snapshot reads the WHOLE working tree, so any concurrent editor
anywhere in the repo (a parallel worker, an open editor, a generator run)
failed this assert with "git status changed" while the guard had done nothing.
Honest residual: a write the guard made outside plugins/command-guard is now
invisible here. That is a real narrowing, taken because the guard's only
filesystem reach is READING `.claude/<allowfile>` (hooks/destructive-guard.sh
:566) and the assert's false positives were costing more than the coverage.
```

Editor's note (2026-10-04, on the move): two claims above were stale. The file had more than four sections — 1b
(recoverability), 1c (temp directory), 1d (.env overwrite and failing cd chain), 5 (no self-exemption) and 6 (segment
splitter) besides the four named. And `:566` was the closing brace of `is_env_secret`; the allow-file read the sentence
means is `allow_listed`.

### Helpers

```text
tier of a command via CLI mode: exit 0 allow, 1 ask, 2 deny
tier of a command as evaluated from inside $FIX
```

### Section banners

```text
---------------------------------------------------------------------------
1. CLASSIFICATION
---------------------------------------------------------------------------
---------------------------------------------------------------------------
1b. rm -rf RECOVERABILITY — the ask tier's biggest source of prompts. A path
git can restore is not a loss; one with untracked or ignored content under it
is. Driven against a real throwaway repo because the check shells out to git,
and a mocked git would be testing the mock.
---------------------------------------------------------------------------
---------------------------------------------------------------------------
1c. OS TEMP DIRECTORY — scratch by definition, so deleting a path inside it is
not a loss. The PAIRS are what matter here, not the singles: a path under the
root must be silent while the root itself stays denied, or "inside /tmp"
becomes just another way to spell /tmp.
---------------------------------------------------------------------------
---------------------------------------------------------------------------
1d. .env OVERWRITE + FAILING cd CHAIN — the 2026-09-24 incident: a hand-built
worktree was never created, `cd /tmp/dq-bg` failed, the `;` carried on, and
`cp .env.example .env && php artisan key:generate` replaced the live .env. The
PAIRS matter: the same cp is the ordinary setup step in a clone with no .env
and must stay silent there, or the guard gets switched off.
---------------------------------------------------------------------------
---------------------------------------------------------------------------
2. EVASION — same command, different clothes. Each must stay deny.
---------------------------------------------------------------------------
---------------------------------------------------------------------------
3. HOOK PROTOCOL
---------------------------------------------------------------------------
env modes
---------------------------------------------------------------------------
4. FAIL-OPEN
---------------------------------------------------------------------------
---------------------------------------------------------------------------
```

### Classification: git push and relative rm -rf

```text
0.6.0: the short flag. ` git push .*(--force| -f)` could not match `-f` as the
FIRST word after push (the pattern's own literal space consumed the only space),
so `git push -f origin main` — the commonest spelling — was allowed.
0.6.0: git GLOBAL OPTIONS between `git` and the subcommand. Every git rule is
written ` git <sub>`, so `git -C <dir> push --force` matched nothing and was
allowed — and `-C` is how an agent addresses a repo outside its cwd.
`rm -rf <relative path>` is no longer decidable from the string alone — its
tier depends on whether git can restore the path. Those cases live in the
recoverability section below, against a fixture whose state is controlled.
```

### Temp directory: $TMPDIR

```text
$TMPDIR is resolved from the hook's OWN environment and only from there: unset
means `rm -rf $TMPDIR/build` is `rm -rf /build`, which must not go silent.
```

### Allow-file: pure readers

```text
The deny half is one case per family that writes the file or runs a program.
```

### Hook protocol

```text
The ask reason names devops' plan reader when devops is installed beside this
plugin, and stays quiet when it is not — a reason naming a path that is not on the
reader's disk is worse than no reason (panel finding 43).
An IDE-driven session writes every file through an MCP server, not through the four
host tool names. Until 2026-09-14 the allow-file — the one file that disarms this
guard — was editable that way while the host tools were blocked: the protection
inverted. apply_patch carries no single path, so the patch BODY is what names it.
deny-only: hard stops stay, the ask tier goes quiet. The pairing is the test —
asserting only the silence would pass on a guard that had stopped working.
A whole-file Write onto an existing, untracked .env asks; creating one, an
Edit, and deny-only stay silent. Driven by a RELATIVE path from inside the
fixture: the fixture lives under $TMPDIR, and an absolute path there is
scratch to the guard by design (section 1c).
```

### No self-exemption

```text
---------------------------------------------------------------------------
5. NO SELF-EXEMPTION -- the guard must not carve a hole for its own CLI
---------------------------------------------------------------------------
A self-exemption was added twice and reverted twice. The motivating problem is
real and is now stated as a limitation in commands/check.md instead: this guard
denies the exact invocation /command-guard:check tells the model to type,
because that invocation carries the deny-tier target as an argument.

Both attempts leaked. 0.2.0 matched the three tokens as substrings anywhere in
the segment, and `bash -c PAYLOAD name arg...` runs PAYLOAD while demoting the
appended magic words to $0/$1. 0.2.1 matched by argv POSITION, which closed
that, and was still bypassed three ways: an exemption that `continue`s past
classification skips the WHOLE segment, and a shell segment carries side
effects the shell evaluates independently of argv -- command substitution,
backticks, and redirection.

These assertions pin every known vector as DENY. They pass with no exemption
present; they FAIL against 0.2.0 and 0.2.1. If someone adds a third exemption,
this section is what should stop it.
Shell-evaluated side effects inside an otherwise exemption-shaped segment
(bypassed 0.2.1). The payload runs before or beside the classifier that
argv says is all that happens.
HOOK MODE, not just CLI mode. Everything above drives `--check`, which reaches
classify() directly. An exemption added in the HOOK path instead — a `case` on
the raw command string before classify() is ever called — is invisible to all
of it: a reviewer built exactly that (the 0.2.0 substring bug, relocated one
layer up) and this section still passed clean while the hole was live. That is
the same CLI-mode/hook-mode composition gap that let the original defect ship,
reappearing in the tests written to close it. These drive the real PreToolUse
entry point, so a third exemption is caught wherever it is placed.
```

### Segment splitter

```text
---------------------------------------------------------------------------
6. SEGMENT SPLITTER -- two bypasses, each hiding a second command behind a
reader-led segment. Closed in 0.8.1.

(a) A backslash inside '…' is literal in bash. The walk took it as an escape,
    so `'x\'` never closed and the `;` after it was read as quoted.
(b) BWK awk (macOS /usr/bin/awk) reads RS = "\0" as paragraph mode: a blank
    line started a new record, and the per-record loop reset the quote state
    but not `seg`, so the next line was glued onto the reader before it.
    mawk and gawk do not do this, so CI (Ubuntu) cannot see a regression of
    (b) -- only a run of this file on macOS can.

---------------------------------------------------------------------------
$'…' is the one single-quoted form where \' IS an escape: the literal-backslash
rule alone would read $'x\'' as reopened and hide what follows.
after \$\$ bash opens a plain quote and zsh an ANSI one (measured on bash 3.2 and
zsh); neither reading may hide the next command
---------------------------------------------------------------------------
```

## plugins/command-guard/scripts/__tests__/config-guard.test.sh

### Header

```text
Fixture tests for hooks/config-guard.sh — the guard on the agent's own guardrails.
Asserts every ask path, every allow path, the self-exemption, and fail-open.
```

Editor's note (2026-10-04, on the move): "every ask path" over-claimed — the harness's Edit cases ask over twelve paths,
not every name `config_kind` lists; the header that replaced it says "existing listed configs".

### Section banners

```text
--- ask paths ---------------------------------------------------------------
--- allow paths -------------------------------------------------------------
--- Bash writes -------------------------------------------------------------
--- self-exemption ----------------------------------------------------------
--- off switch --------------------------------------------------------------
--- fail-open ---------------------------------------------------------------
```

### The sibling's switch

```text
The SIBLING's switch, added 0.6.3. The core-suite README (the suites were retired
2026-09-26) sold
CLAUDE_DESTRUCTIVE_GUARD=deny-only as buying the click-free half of this plugin; this
hook is its other ask tier and read only its own variable, so the documented setting
left an ask on every config write. Both values that mean "no ask tier" must silence it,
and the value that does NOT mean that (`ask`) must leave it running.
```
