# design-kit hooks and scripts: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the file named in the `##` heading, with only each comment's `# ` leader removed; the lines the file kept are not repeated here (the `set -e` rule stays in the file as one line above the first switch read). A pointer by name was left in the file, `# Why, limits, history: rationale/derivations/plugin-design-kit.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/design-kit/hooks/unread-pick.sh

### Header

```text
unread-pick.sh — UserPromptSubmit: one line, only when a board pick is waiting.

WHAT IT CATCHES. The user picked an artboard on a design-kit board (the board
posted it to the server's loopback /_decision route → .design-kit/decisions.jsonl)
and then typed a prompt without telling the session. Prints ONE line naming the
board and artboard so the session reads the pick instead of asking for it — the
"session watching the board" half of the decision channel, without polling.

WHAT IT DOES NOT DO. It never blocks, never reads the prompt, and says nothing
when every row is consumed or no board exists. Turn-taking is not hand-rolled here:
it runs the marketplace's shared phase guard (templates/blocks/phase-guard.md,
inlined below) against its OWN lane.tsv row, so the phase list cannot drift from
the declaration the way a hardcoded one did — that copy read build|verify|review|ship
and spoke through `plan`, and had no TTL and no session check, so a sentinel left by
a run that died muted this channel in every later session. Off with CC_REMIND=off or
CC_DESIGN_KIT_PICK=off.
CC_REMIND / CC_DESIGN_KIT_PICK unset: the /config options cc_remind / cc_design_kit_pick decide.

WHERE IT LOOKS. The phase sentinel and .design-kit/decisions.jsonl are read at the
project root, not the payload cwd, which follows the model's `cd` (finding 2,
rationale/2026-09-25-session-plugin-usage-review.md) — so both shared blocks are
inlined below: state-root (held byte-identical to templates/blocks/state-root.md by
pc_shared_blocks) and phase-guard. dk.sh resolves its .design-kit/ with the same
state-root block, so writer and reader agree from any directory. An explicit
DESIGN_KIT_DIR elsewhere is not seen here. NO gate holds the phase-guard copy to its
block — keeping the two identical is by hand, **recorded**.

FAIL-OPEN, like every hook here: no python3, no jq, no readable sentinel, a foreign
session or a stale one all mean "proceed" or "say nothing", never an error on the
user's prompt. `set -e` is deliberately absent — an unset variable or a non-zero
probe must not take the prompt down with it.

Standing: scripts/__tests__/unread-pick.test.sh drives silent, one-line, consumed,
phase-gated, stale-sentinel, subdirectory-cwd and no-python3 cases — **gate** (CI globs every
plugins/*/scripts/__tests__/*.test.sh). Nothing proves the model ACTS on the line
(agent-graded), and nothing here proves the guard is honoured on a branch the
harness does not drive.
```

### The root's board only

```text
The root's board only. dk.sh anchors .design-kit/ at this same root (the same
cc_state_root), and `dk decision --consume` clears rows there — so a stray
<subdir>/.design-kit/ left by a dk.sh before 0.5.1 is not announced: the consume this
line tells the model to run could never clear it, and it would repeat on every prompt.
```

### 2026-11-12 (0.13.2): per-session sentinel; the paste is gated

The phase guard now reads only this session's sentinel, `.claude/cc-phase/<session>.json`
(taskmaster 0.56.0), through the pasted phase-file block. Both pasted blocks, phase-file and
phase-guard, are now held byte-for-byte by `pc_shared_blocks`, which superseded the "NO gate
holds the phase-guard copy" paragraph above. The test payloads carry a `session_id`, and a
case proves another session's build phase does not silence this one.

### 2026-11-13 (0.15.0 review): board names, artboard numbers, the notes lease

A page posts the board string and the artboard number, and this line enters the model's context on every
prompt. The name was filtered with `[\w.-]{1,128}`, and Python's `\w` takes any Unicode letter, so a name
spelled with U+3164 (a Hangul filler that renders as nothing) in place of spaces read as a sentence. The
name is now printed only as ASCII `[A-Za-z0-9._-]{1,59}\.html?` (64 characters at most) naming a file in
`.design-kit/boards/`, the artboard only in 1..99, else the line gives a count. Notes count with dk notes'
15-minute lease (a timestamped `handed_out` older than that, status still open, counts again). Red, in a
scratch copy with the harness's exits made non-fatal: `FAIL: the hook printed a board name made of
blank-rendering letters`, `FAIL: the hook named a board with no file under boards/`, `FAIL: the hook printed a
board name over 64 characters`, `FAIL: the hook printed an artboard number out of range`, `FAIL: the hook
should count the note whose 15-minute lease ran out`. The harness's boards now exist as files.

### 0.20.0, 2026-11-24 — a row without v:2

Until 0.19.3 a page's own script posted the pick, so the line told the session of a choice the user may never have
made. A pick sent from the viewer is stored with `v: 2`; a latest row without it is now called `unconfirmed pick from
an older preview page; ask the user before acting on it`, with the clamped board name or a count and no artboard. A
row planted on disk with `v: 2` reads as confirmed. The number is a literal here, not `picks.VERSION`: the hook loads
no module of the plugin on a prompt.

## plugins/design-kit/scripts/dk.sh

Moved verbatim on 2026-10-28 from the body; lines 2-51 stay as they were because `dk --help` prints them (`sed -n '2,51p'`) and an unknown verb prints lines 7-24. The `#` lines inside the python heredocs are code and stay too.

### Help before ensure_ignored

```text
help writes nothing — it used to run after ensure_ignored, so `dk --help` edited .gitignore
```

### ensure_ignored

```text
ensure_ignored — the plugin's scratch paths never reach a commit by accident.
Once per repo: inside a git work tree, when .design-kit/ or __design-kit__/ is not
already ignored, append one managed block to .gitignore (idempotent — re-runs
rewrite the block, never duplicate it) and say so in one line. design-system/ is
NOT added: it is the tracked record. Outside git, nothing. DESIGN_KIT_IGNORE=off
skips it (a repo that wants the previews committed).
```

### drift

```text
WHAT IT CATCHES. Literal hex/rgb/hsl/oklch colours and named Tailwind palette
utilities in .tsx/.jsx/.vue/.blade.php/.css/.scss that resolve to no declared
token. WHAT IT DOES NOT. Spacing, radius, shadow and font drift; a colour
computed at runtime; a token used in the wrong role. handoff-drift.py's header
carries the full residual list.

--staged and --diff resolve the FILE LIST here, in git, so the python stays
git-free and one reader serves both modes. --diff compares against the WORKING
TREE, not HEAD: a check run before committing that reads HEAD is blind to the
edit it was run for, which is the trap this repo has already paid for once.
```

### drift: an empty selector

```text
AN EMPTY SELECTOR SCANS NOTHING, never the whole tree. `--staged` with nothing
staged, or `--diff <base>` with no changed file, used to fall through to `.`
and red a --ci run over code the change never touched.
```

### drift --print-hook

Added 2026-11-09 (design-kit 0.13.0, roadmap D6 dk6). It runs before `ensure_ignored`, like
`--help`, so printing a snippet writes no `.gitignore` block, no `.design-kit/` and no usage line.
The hook calls `handoff-drift.py` directly, not `dk drift`, for the same reason: `dk` logs and
creates state on every call, and a hook fires on every edit. It exits 2 only on `--ci`'s 1, so a
project with no tokens (2) or a file it does not scan (0) stays silent; exit 2 is the PostToolUse
code whose stderr reaches Claude. The path is absolute because a settings.json hook has no
`${CLAUDE_PLUGIN_ROOT}`; it names the installed version and goes stale on update, which the
printed note says.

### system --source rendered

Changed 2026-11-09 before 0.13.0 shipped, from review finding `dk.sh`/system SKILL.md:95. `dk system`
ran a `--dry-run` before every extraction, so a rendered source loaded the page twice, and its
`|| fail … 1` turned system-extract's exit 3 (no Playwright) into 1, against the skill's promise.
A rendered run now skips the dry-run, and the extraction's exit code passes through for every
source. `dk.test.sh` drives it with a stand-in `node` that counts its calls.

### snapshot and review

```text
Both live in snapshot.sh, which owns the exit codes — 0 rendered, 1 bad
arguments, 2 the browser or the server was unreachable — and they pass through
here unchanged, so a wired-up caller reads the same number either way.
```

### status: no URL for a dead server (2026-11-12)

`dk status` printed `.preview.url` whenever the file existed, so after a `kill -9` it printed a dead URL. It now prints it only when `.preview.pid` names a live pid (`os.kill(pid, 0)`, pid > 0). Residual: a recycled pid reads as live; the launcher's `ours()` check is not repeated here. Red: `FAIL: dk status printed a URL for a killed server`.

### notes: review fixes (2026-11-13, 0.15.0)

Cases added to `dk.test.sh` first and run red in a scratch copy of the unfixed plugin with the harness's
exits made non-fatal, then fixed. taskmaster's `preview-feedback.sh` is the twin; the two copy each other's
rules, never import them.

- **The pick as data.** `--wait` printed an unconsumed pick's `prompt` raw after the JSON rows: a page posts
  up to 4096 characters with newlines and escape codes kept, enough to forge a row or the hook's line. It now
  prints `{kind: "pick", ts, board, picked, prompt}` as one escaped JSON line. Red: `FAIL: --wait should
  print an unconsumed pick as one escaped JSON line (rc=0): implement artboard 1 of x`.
- **A pick announced once.** An unconsumed pick ended every `--wait` at once and was never marked, so a
  re-armed wait returned it forever. The wait keeps the printed row's fingerprint in `.notes-pick` (a dot
  file, never served) and waits past it until a newer pick or a note. Red: `FAIL: a second --wait returned
  the pick the first one announced`.
- **Escaping.** Rows printed `json.dumps(ensure_ascii=False)` as is. They now take taskmaster's set: `C*`,
  `Zl`, `Zp`, variation selectors, the Hangul fillers and U+2800. Red: `FAIL: dk notes printed the raw bytes
  \302\205` (U+0085), and the same for U+009B, U+200B, U+2028, U+202E, U+E0041, U+E0100, U+3164, U+2800.
- **Print, then mark; a lease.** Rows were marked before they were printed; now they print and flush under
  the lock, then the mark is saved, and a note handed out 15 minutes ago and still open is unread again.
  Red: `FAIL: a reader whose output failed still marked the note handed out` (stdout on `/dev/full`), `FAIL:
  dk notes should hand out again a note handed out 20 min ago and still open, and only that one`.
- **Parse on change.** `--wait` re-parsed both files twice a second; it now compares inode, size and mtime.
  Red: `FAIL: --wait re-read a notes file whose size and mtime did not move (rc=0)`.
- **One parse for `--shot`.** Python validated the last `--shot` value while the shell named the PNG after
  `$2`, so `--shot ../../logo --shot <id>` removed and wrote `../../logo.png`; `--all --shot <id>` took no
  PNG and exited 0. `--shot ID` must now be the whole argument list, every option may appear once, verbs do
  not mix, and the PNG path is built from the id Python printed. Red: `FAIL: --shot ../../logo --shot <id>
  should exit 2 and write nothing (rc=0, …/logo.png: PNG…)` and six usage cases that exited 0.
- **The browser run.** No `--no-sandbox` unless root or `DESIGN_KIT_BROWSER_NO_SANDBOX=1`, a throwaway
  `--user-data-dir` (it used the user's own Chrome profile), `timeout 30`, and a failed run is reported
  (exit 4) instead of hidden by `|| true`. Red: `FAIL: --shot passed --no-sandbox …`, `… (no
  --user-data-dir)`, `… with no time limit (parent bash)`, `FAIL: a browser that exits 7 should be reported`.
- **Rewrites.** A rewrite kept only lines that parsed as objects and wrote a fixed-name
  `.notes.jsonl.tmp` opened with `"w"`, which a planted symlink redirected. Now raw lines carry through,
  reads use `O_NOFOLLOW`, and the rewrite goes through `mkstemp`. Red: `FAIL: --reply dropped a line it
  could not parse`, `FAIL: --reply wrote through a symlinked temp file`.

### scratch --cleanup and --verify from the root (0.19.3)

`$DK` was anchored at the project root in 0.5.1, but `dk scratch --cleanup` and `--verify` still ran
`codebase-cleanup.sh` in the shell's cwd, which scans from there down. Run from `src/` after a
`--create` at the root, `--verify` printed `cleanup: clean` while `__design-kit__/hero.html` and
the route line stayed: a false clean in the check the in-codebase skill treats as proof (reviewer
finding, 2026-11-21). Both now run from `$ROOT` in a subshell. `--detect` and `--create` keep the
cwd on purpose: the scaffold reads `package.json`, `artisan` and `vite.config.*` there, and in a
monorepo the app's own directory is not the git root. Red against the 0.19.2 script:
`FAIL: scratch --verify from a subdirectory missed the root's scratch` (`dk.test.sh`).

### 0.20.0, 2026-11-24 — the lock, -I, mktemp, share paths, v:2

- **`.decisions.lock`.** `--consume` read decisions.jsonl, marked rows and wrote the file back with nothing held, while
  the server appended: a pick posted in between was lost, and a reader could see half a file. Both writers now hold
  the lock, and the rewrite is put in place in one step. A 0.19.3 session and a host without `fcntl` take no lock.
- **`-I`.** A python that reads its program from stdin has the cwd on its path, so a project's own `html.py` stood in
  for the module serve.py imports. `dk bundle`, `share`, `decision`, `notes` and `status` start python isolated.
- **`mktemp`.** The builders' stderr went to `/tmp/dk-board.$$` and `/tmp/dk-bundle.$$`, names another user of the machine
  can plant (I6 of the scan of 2026-11-23). It is one `mktemp` file now, gone on every exit.
- **Share paths.** `dk share` cut `$DK/` off what was typed, so only a path from the project root worked (D5). It finds
  its page as `dk check` does and refuses, with exit 2, what that refuses; a symlinked page publishes under its
  target's name, and `zip:` is an absolute path.
- **`v: 2`.** `dk decision` and the pick of `dk notes` print `picks.pick_line`, clamped again at read, as one escaped JSON
  line; `confirmed` is true for a row with `v: 2` alone, and a row's own prompt is never printed. `--consume` writes a
  clamped board into workshop.json, or nothing. Red lines and the rest: the 0.20.0 sections of serve.py and picks.py.

### 0.20.0 review, 2026-11-25 — --lan that shared nothing, and checks that held nothing

`dk share <page> --lan` and `dk serve --lan` printed a 127.0.0.1 URL and logged ok when preview.sh had left a newer
server as it was: the user was told of a share that did not exist. dk now reads `.preview.bind` after a `--lan` start
and fails with exit 4, nothing on stdout. Red: `FAIL: dk serve --lan should fail when the server stays on this machine
alone (rc=0): url=http://127.0.0.1:…/`, the same for share. The two rewrites go through `isolate.replace_file` and the
report lines through `serve.escape`, the one copy of each; `render-check.resolve` raises, and share prints its own name
before the reason (it used to say "so it cannot be checked").

Three mutants of the 0.20.0 code had survived `dk.test.sh`; each is red now, run on a copy: `dk notes` without
`.notes.lock` (`each note is handed out once`, `kept 18 of 20 posts`, 4 runs of 4) and `--reply` without it (`kept 17 of 20
posts`, 4 of 4), from 20 posts racing three readers and three repliers over a padded file; `--consume` marking every
board's rows (`consuming b.html's pick marked a.html's read`); `--board` ignored (`--board FILE should print that board's
pick`).

## plugins/design-kit/scripts/dk-usage.sh

### Header, moved 2026-11-25 (0.20.0)

Moved verbatim from lines 2-36, with only each comment's `# ` leader removed, when the header was cut to three lines. `-h` printed lines 2-33; it prints the same facts from a heredoc now, and the flags with them. One sentence does not hold: a decisions.jsonl line that is not an object ends the script with exit 1.

```text
dk-usage.sh — did design-kit earn its place? One row per surface, per project.

WHAT IT READS, per project directory given (default: cwd), in $DK =
.cc-artifacts/design-kit (else the .design-kit/ plugins before 2026-11-14 wrote):
  $DK/usage.jsonl             one line per dk verb: {ts, verb, outcome, artifact}
  $DK/decisions.jsonl         one line per board pick: only its ts and consumed are
                              read, so a row adds counts and never text of its own
  $DK/{decks,boards,artifacts,previews,exports}/  file mtimes
  $DK/design-system/DECISIONS.md  the decision ledger, if any (else design-system/);
                              component paths come from here alone
  git log                     commits touching those paths within 7 days of a decision

WHAT EACH COLUMN MEANS
  created    pages of that surface that exist
  revisited  pages whose mtime moved more than a day after their first version
  picked     decision rows (boards) / consumed decision rows (in-codebase)
  rendered   scratch verbs with outcome ok (in-codebase only)
  exported   export verbs with outcome ok, or .pdf/.png beside a deck or board
  shared     share verbs with outcome ok (LAN, pages branch, zip)
  followed-by-commit  commits in the 7 days after a decision that touch a path
             DECISIONS.md names; `n/a` when it names none — never 0, because
             0 would claim a measurement this script did not make

WHAT IT CANNOT SEE. Subagent turns; a pick pasted via the clipboard instead of the
board's decision route (that is prose in a transcript, not a decision row); a deck
opened in a browser (no request log); anything in a project you did not pass.
Zero proves nobody used it HERE; non-zero proves it fired, not that it helped.

THE VERDICT LINE. The plugin README commits to a kill trigger: 30 days after 0.2.0,
at least three projects with a design-kit folder present, followed-by-commit = 0 AND
shared = 0 across all of them → retire. This script prints that line with the
numbers it measured; it does not decide.

Standing: scripts/__tests__/dk-usage.test.sh drives a fabricated project (every
column non-zero) and an empty one (all zeros, n/a). Always exits 0.
```

## plugins/design-kit/scripts/__tests__/dk-usage.test.sh

### Header, moved 2026-11-25 (0.20.0)

Moved verbatim, with only each comment's `# ` leader removed.

```text
Drives dk-usage.sh on (a) a fabricated project where every column is non-zero — a
usage ledger, two decision rows, a DECISIONS.md line naming a component path, a git
commit touching that path inside the 7-day window, a revisited artifact, a deck with a
PDF — and (b) an empty project: all zeros and followed-by-commit = n/a. A decision row
adds counts, never text or a path of its own. Exit is 0 throughout.
```

## plugins/design-kit/scripts/__tests__/snapshot.test.sh

### Header, moved 2026-11-25 (0.20.0)

Moved verbatim, with only each comment's `# ` leader removed, when the case of sets outside `shots/` was added.

```text
Drives snapshot.sh: the argument errors (exit 1), the unreachable exit (exit 2,
NOT MEASURED — never a green), the pairing of two fixture shot sets through
`review` in BOTH diff-engine branches (Pillow present → a heatmap and a
percentage; Pillow absent → `no diff engine: install Pillow` and the pair alone,
forced with a PYTHONPATH stub so the branch runs on a machine that has Pillow),
the --storage-state checks (a missing, malformed or empty file, one inside a repo
that git does not ignore, a TRACKED one → exit 1; an ignored one reaches the browser
layer → exit 2 at a dead URL), a review run from a SUBDIRECTORY landing in the root's
.cc-artifacts/design-kit/ with a git-ref base read from the toplevel (and one whose shots sit under
the pre-2026-11-14 .design-kit/), and — only when a
Chromium-family browser is installed — one real shoot of two routes at two device
sizes off a throwaway python3 -m http.server, plus a cookie-guarded route shot
through a state file, where the SERVER logs the cookie and a localStorage beacon,
and an expired session that must shoot with a WARN naming the login URL.

WHAT THIS DOES NOT PROVE. That a shot LOOKS right: nothing here opens a browser
at a pixel and judges it, which is the agent-graded half snapshot.sh's header
claims. The fixture PNGs are flat 4x4 colour fields, so the percentage they
produce is 0 or 100 and never exercises a partial-page change. That a state file
SAVED by Playwright replays here — the fixture is hand-written in its shape; the
save was run by hand once (CHANGELOG 0.5.1). With no browser installed both shoots
are skipped and this file says so on stdout. Every server start retries on a fresh
port, but the two dead-URL picks ($port_dead, $port_free) still trust bind-then-close:
they misfire only if another process binds that exact port AND answers HTTP in the run.
```

## plugins/design-kit/scripts/__tests__/unread-pick.test.sh

### Header, moved 2026-11-25 (0.20.0)

Moved verbatim, with only each comment's `# ` leader removed.

```text
Drives hooks/unread-pick.sh: silent without decisions, one line with an unread pick,
silent once consumed, silent past the decide phase, off-switch honoured, silent with
no python3, and SPEAKING again once a dead run's sentinel ages past the guard's TTL.
Notes: a count of open, not-yet-handed-out rows and the command; an instruction-shaped
note text, selector, page and board name must never reach the line; a board is named only as short
ASCII naming a file in boards/, an artboard only in 1..99; a note's 15-minute lease runs out.
A latest row without v:2 is called unconfirmed and gives a clamped board name or a count, nothing else of its own.

CLAUDE_PLUGIN_ROOT is exported because the shared phase guard resolves the hook's lane
from ${CLAUDE_PLUGIN_ROOT}/lane.tsv — the host sets it for every plugin hook, and
without it the guard fails open and every phase case below would pass for the wrong
reason. What this does NOT prove: that the model acts on the line (agent-graded).
```

## plugins/design-kit/scripts/snapshot.sh

Moved verbatim on 2026-10-28. The header is what `--help` prints (`usage` echoes line 2 down to `set -euo pipefail`), so it keeps its usage text and loses only the history: the two paragraphs below are as they stood, and the file keeps them minus the session finding, the measurement date and the scattered-dir story. The pointer sits after `set -euo pipefail`, out of the help. The `#` lines inside the python heredocs are code and stay.

### Header: behind a login

```text
BEHIND A LOGIN. Every authenticated app in the measured sessions sat behind a login
this script could not pass, so none of them could get a before/after here (the
marketplace's rationale/2026-09-25-session-plugin-usage-review.md, UI/UX section).
--storage-state FILE replays a signed-in session: a Playwright storageState JSON,
{"cookies": [...], "origins": [{"origin", "localStorage": [{name, value}]}]}, saved
by whoever signed in
through the project's walk access, a self-registered or seeded test user and never
the user's own account (README, "Behind a login", has the one-call way to save it).
The browser's --screenshot CLI has no way to take a cookie, so this path drives the
same browser over the DevTools protocol on a pipe (--remote-debugging-pipe, python3
stdlib only): cookies set before the first navigation, localStorage seeded on each
new document of a matching origin, one browser for every shot. It settles in REAL
time — the load event, then 500 ms with no request in flight, at most 3 s — because
a virtual-time budget left CDP screenshots hanging (measured 2026-09-25, Chrome 153).
A route that ends on another URL (a sign-in redirect, an expired session) is still
shot, with a WARN naming where it landed; a file holding cookies for other hosts than
the base URL's draws a WARN too. The file holds a live session token: one
inside a git work tree that git does not ignore (a tracked file never counts as
ignored) is REFUSED, exit 1 — keep it under .design-kit/, which dk.sh keeps ignored,
or outside the repo.
```

### Header: where shots go

```text
WHERE SHOTS GO. $DESIGN_KIT_DIR (dk.sh exports it, anchored at the project root),
else .design-kit at the git toplevel — not under a subdirectory the shell cd'd into,
which scattered a second .design-kit/ (finding 2 of the same rationale file).
```

### check_state

```text
check_state <file> — exit 1 unless it exists, reads as a storageState, and cannot be
committed. `git check-ignore` never reports a tracked file as ignored, so a tracked
state file is refused even when a .gitignore pattern matches it.
```

### The browser probe

```text
The browser lives in board-export.sh; this asks it rather than re-implementing the
probe order, so a new install path is added once.
```

### review: git archive from the toplevel

```text
From the toplevel, with a toplevel-relative path: `git archive` refuses a pathspec
outside the cwd, so run from a subdirectory it never found the root's shots.
```

### 2026-11-13 — the 500 px floor, stated

Measured on Chrome 157: `--headless=new --window-size=390,844 --screenshot` writes a 390x844 PNG of a page laid out with `innerWidth` 500. So `--device mobile` shots are the left 390 px of a 500 px layout. Stated in the header's misses; not reworked (dk check emulates exact widths over DevTools).

### 0.20.0 review, 2026-11-25 — a review shows copies

From 0.20.0 a review page may load images from `shots/` and `reviews/diff/` alone, so one whose sets lie elsewhere (task-runner's walk writes `<docroot>/<group>-before` and `<docroot>/<group>`; `dk snapshot --out`) showed broken images. The rule stays: a PNG outside `shots/` is copied to `reviews/diff/<review>/<side>__<device>__<route>.png` and the page shows the copy; the folder is removed first, so a review written again holds its own copies alone. A PNG that is a symlink is not copied, since the copy would serve what it points to. Sets under `shots/` are shown where they are, the dot folder of a `--base <ref>` (404, older) included. Red: `FAIL: a review page of sets outside shots/ should load every image it shows` (HTTP 404).

## plugins/design-kit/scripts/codebase-scaffold.sh

Moved verbatim on 2026-10-28. Lines 2-34 stay as they were: `--help` prints them by number (`sed -n '2,34p'`).

### Header: what it does not catch

```text
WHAT IT DOES NOT CATCH. A project with two stacks (Laravel + a separate Vite SPA)
resolves to Laravel because `artisan` outranks `vite.config.*`; pass --stack to
override. It never starts the dev server and never composes the design — the
model does both; the strip proves the imports resolve, nothing more. Inertia with
the Svelte adapter stays `laravel`. An APP_URL that is not the URL the app is served
on (the skeleton's bare http://localhost under `php artisan serve`) is printed as is.
A Tailwind v4 entry stylesheet the scaffold cannot find (Nuxt's, any but
resources/css/app.css on Laravel) gets no @source line. Standing:
scripts/__tests__/codebase.test.sh drives --detect and --create on a Vite React
fixture (plain, inventory-filled, alias-imported), a Laravel fixture and Laravel +
Inertia React and Vue fixtures, and cmp's the stylesheet and routes file after cleanup.
```

### mark_line

```text
mark_line <file> <line>: append once, after a newline only when the file ends without one
(a routes file with no final newline had its last route joined, then deleted by cleanup)
```

### laravel: the plain template

```text
the wrapper (<x-app-layout> vs a standalone page with the layout's @vite) is
evidence-based, so the plain template also goes through scaffold-fill.py
```

## plugins/design-kit/scripts/codebase-cleanup.sh

Moved verbatim on 2026-11-21, when the header went to three lines (`--help` prints lines 2-5).

### Header before 0.19.3

```text
codebase-cleanup.sh — remove every scratch file codebase-scaffold.sh wrote.

WHAT IT CATCHES. Any path containing `__design-kit__` under the project (skipping
node_modules, vendor, .git, .cc-artifacts, .design-kit) is deleted, and every line carrying the
`__design-kit__ scratch` marker is stripped from routes/web.php and from any .css
file (the scaffold's Tailwind v4 `@source` line), restoring each file's bytes —
including a missing final newline. `--verify` only lists leftovers and exits 1 if
any exist — the gate a command runs after the pick, so "cleaned up" is proven, not
asserted.

WHAT IT DOES NOT CATCH. A scratch import the model added to an EXISTING file
(a provider registered in app.tsx, a route in a file other than routes/web.php)
carries no marker and survives; the skill forbids that edit and `git status`
is the check. A marked line in a .css under node_modules or vendor is not searched.
Standing: scripts/__tests__/codebase.test.sh drives remove and --verify on its
fixtures and cmp's the stylesheet and routes file against their originals.
```

### routes/web.php at any depth (0.19.3)

Only `./routes/web.php` was read. Once `dk.sh` ran cleanup from the project root, a Laravel app in a
subdirectory (`apps/api/routes/web.php`) would have kept its marked route line while `--verify`
said clean, so the route file is now found at any depth, by name, outside the pruned directories.
Red against the 0.19.2 script: `FAIL: verify from above the app missed its routes/web.php`
(`codebase.test.sh`).

## plugins/design-kit/scripts/handoff-drift.py

Moved verbatim on 2026-10-28: the module docstring (quotes removed; `--help` prints only its first line, which the file keeps) and one `#` block.

### Module docstring

```text
handoff-drift.py — how far shipped code drifts from the repo's declared tokens.

TWO MODES, ONE TOKEN READER.

BUNDLE MODE (the default, `handoff-drift.py <dir>`) — how far a Claude Design
handoff bundle drifts. Every colour (hex, rgb(), hsl(), oklch()) and font-family
the bundle's .html/.css files use, against every token the repo declares: `--name:`
custom properties in CSS under src/, resources/, app/, styles/ and the repo root
(this covers Tailwind v4 `@theme` blocks), `key: '#hex'` pairs in tailwind.config.*,
and `$value`s in design-system/tokens.json. Prints one DRIFT TABLE row per distinct
bundle value: nearest token, distance, verdict `match` (exact), `near` (RGB
distance <= --near, default 24) or `no token`. Exit 0 always — the table is the
output; a `no token` row is a question for the user, not a failure.

SCAN MODE (`--scan PATH...`, what `dk drift` runs) — the same question asked of the
project's OWN components. Reads .tsx/.jsx/.vue/.blade.php/.css/.scss and reports
two hit kinds: a literal colour that resolves to no declared token, and a NAMED
TAILWIND PALETTE utility (`bg-indigo-500`, `text-slate-700/50`) whose palette name
is not a declared token name — the shape that bypasses the token layer entirely, so
`dk check` and the bundle table above both stay green while the components drift.
`--ci` exits 1 on any hit; without it the table is the output and the exit is 0.
No token source anywhere exits 2 (`not measured`) in either mode: a drift check
that cannot find the tokens has not cleared anything.

WHAT SCAN MODE DOES NOT CATCH, named rather than implied. Spacing, radius, shadow
and font drift (colour only here). A colour computed at runtime, or one arriving
through a CSS file the token reader already treats as a DECLARATION site — a
literal on a `--name:` or `$name:` line is the token being defined, never a hit.
An `href`/`to` attribute value is blanked before the scan, so a `#dad` anchor is
not read as a colour, but any other 3-hex-digit slug in other syntax still is.
`bg-primary` and `var(--primary)` are clean BY CONSTRUCTION — this check proves a
component went through the token layer, never that it picked the right token, and
semantic misuse (the right token on the wrong role) is invisible to it. A named
palette utility is judged on the class STRING, so a project that renamed a scale to
`indigo` in tailwind.config is reported unless tokens.json declares that name too.
Standing: scripts/__tests__/handoff.test.sh drives bundle mode, drift.test.sh
drives scan mode (hit, clean, --ci exit, not-measured).
```

### TW_SCALES

```text
The Tailwind default palette scales. A utility naming one of these reaches a
colour without passing the token layer at all, which is why the class STRING is
the evidence here and no value lookup happens: `bg-indigo-500` resolves inside
Tailwind, never inside design-system/tokens.json. `bg-primary`, `bg-brand-600`
and any other semantic name are clean by construction — that is the whole point.
black/white/transparent/current/inherit are deliberately absent: `text-white` on
a dark button is not drift, and a row that fires on every real page is a row
someone switches off within a day.
```

## plugins/design-kit/scripts/serve.py

### 0.20.0, 2026-11-24 — pages leave the control origin

Milestone 1 of the "own artifacts" work; the scan, the spec and the red-team record live in the gitignored `.cc-artifacts/`. What a page, another site or a phone can still do, and what a user can do about it: `rationale/design-kit-threat-model.md`.

**What shipped that made it exist.** Until 0.19.3 one origin served model-written pages, the gallery, the notes, the check results and the write routes, with no policy header, no sandbox and no `Host` check on GET. The scan of 2026-11-23 ran what follows from that: a page's script posted a pick and a note and read other pages and their notes (I1); a page framed in the gallery rewrote the gallery's DOM (I2); `Host: evil.example` got pages and the index (I3); a symlink in the docroot was followed (I4); `dk decision --latest` printed a planted prompt raw, and the skill treated pick text as requirements (I5).

**One port, two kinds of document.** A page URL answers the viewer; the page itself is served only under `/_c/<segment>/`, sandboxed into an opaque origin by its own answer (isolate.py below). Rejected when the user chose the approach on 2026-11-24: a second port (pages keep their storage but share one real origin, so a page reads another page's data, and the LAN needs two ports) and headers on the page alone (a top-level page can leak by navigating itself away, and notes leave the page). The trigger to go back to a second port, deck keys, print or downloads that cannot work inside the frame, was probed in Chrome 158 the same day and not met.

**What the code does that the spec does not say.** A framed GET is written up to the in-page client, then, 50 ms later (`FRAME_WAIT_S`), the rest: Chrome starts an out-of-process frame at 0x0, and a page's first script saw 0x0 in 9 of 24 loads before and 0 of 24 after. That is timing, not a guarantee. `may_load` is asked about the resolved path too, so a motion folder that is itself a symlink inside the docroot loses its files. The 404 of a path the page may load carries `Access-Control-Allow-Origin`, so the page reads it as a 404. `without_key` keeps the query as it was typed, and only an exact `static=1` asks for the raw page. `/_page` is `writable` only where a POST would be taken, which a loopback peer naming a LAN `Host` is not. `host_ok` matches a strict form before `urlsplit`, which drops tabs and newlines and skips userinfo, so a POST to `user@localhost` is refused too. A page's own stream (`/_events?page=`) ignores the other pages of its folder, which the page can never load. `/_notes` also returns rows filed under the folder form of an index page, so notes left on `/motion/x/` before the update still list.

**Measured on 2026-11-25 for the threat model** (a served temp docroot, one run each): a hard link to `workshop.json` inside the docroot answered 200 while `/workshop.json` answered 404; a page opened at `?static=1` navigated itself to a second server with its data in the address (1 request), the same page framed made 0 and was replaced by the stopped area; a raw page's XMLHttpRequest, beacon, fetch and form to the write routes left no file.

### 0.20.0 review, 2026-11-25 — a cid is required, and the viewer gets its rules

- **A cid.** A pick or a note posted with none was recorded, so a send repeated after a lost answer could make a second row; `/_decision` and `/_note` answer 400 without 16 hex digits now. `/_allow` needs none: an approval sent twice is one approval.
- **Rules.** `viewer.js` held its own copy of the knob table, the limits, the hidden characters, the sandbox tokens and the gallery's address. They travel in `data-rules` of the viewer's document instead; `/_page` keeps the fields the spec fixed.
- **`SERVER_VERSION` 2.** `viewer.js` is read from disk at each request and the document comes from the running process, so a server started before the review would hand the new script a document with no rules: it is restarted.
- **One home each.** What a page is, the content prefix, the opener that follows no link and the replace in one step are isolate.py's; the escape is `escape`, which `show`, dk.sh and the report lines share; a row and its version are picks.py's. `flow_steps` no longer builds a fake row to read `workshop.json` through.

### 0.20.0, 2026-11-25 — the Firefox hand run

Playwright's Firefox build 1555 (157.0, BuildID 20261002045259), headless, Linux, with the prefs Playwright ships in the build. Each run had a network namespace of its own with only the loopback address in it (`unshare -rn`). The spec's criteria 2, 6, 19, 28 and 33, two ways:

- **With no driver**, once: `firefox --headless --profile DIR --no-remote URL` on nine pages of `attack.test.sh` (frame.js there; loads, top and self navigations, posts, the SVG and the XHTML; no click), a second local server counting what arrived: 0 requests, and 56 from the same nine on the control server.
- **With the build's own WebDriver BiDi server** (`--remote-debugging-port`), three times or more, the same result each time. A page cannot report by POST from inside the sandbox, and none can see the viewer or press a key in it. So the bodies of `viewer.test.sh` (the parts `files`, `picks`, `once`, `place`, `prints`, `keeps`) and `attack.test.sh` (without its approved-host part, which needs Chrome's host map) ran as they are on a scratch stand-in for `browser_lib.py` outside the repository. `notes` stops at the second failure below, so its steps were driven one by one.

**Criterion 2: held for every vector it lists; one more vector failed.** Fetch, beacon, EventSource, WebSocket, image, form, popup, top navigation, the six self navigations, the own-folder SVG and XHTML: 0 requests, frame.js there and undone. The control: 6 of 6 self navigations with the driver and without, 71 of the 73 other paths. 36 of attack.test.sh's 39 assertions there held; the other three are the tab and the request below, and the two control paths that did not arrive. **Failed:** in a page that undid frame.js, a Ctrl- or Shift-click event that the page's script makes itself on a link, while it handles the user's plain click or key press (ArrowRight), opens a real tab or window: 1 request, the page's text in its address. Chrome 158, the same probe: no tab, no request. None with no user action, with frame.js there, or for a Meta or a middle click. The user's own Ctrl, Shift and middle click there open a tab and make 1 request each, Alt+click nothing. Says nothing here: `<a ping>` and `<link rel=prefetch>` did not arrive from the control either; DNS prefetch and WebRTC were switched off. Preconnect opened 0 connections, since the build holds `network.http.speculative-parallel-limit` at 0.

**With stock values.** A copy of the build whose `playwright.cfg` lost seven prefs (the pop-up blocker, the two delays after which input counts, `focusmanager.testmode`, the site isolation strategy, `fission.bfcacheInParent`, the speculative connections) gave the same for attack.test.sh, the script's own click and the focus below, but for preconnect: 2 connections.

**Criterion 6: held**, framed and raw, 9 assertions: the `a;b, c ü` folder's script, module, font, image, audio and JSON, a review's `shots/` image, a deck that loads no server file.

**Criterion 19: held**, 45 assertions: the strip and no row before Send pick, one row a send, a double click, a held and a lost answer, a tab reload after it, a change after it as a second row.

**Criterion 28: held but for the focus.** Arrows right after load; P and Ctrl+P fire `beforeprint` in the frame; Alt+N from page and viewer, not in a field of either; hover outlines; a click picks, and the composer has the focus; Tab then Enter picks; Note on this page with viewport, theme and console; Escape in the composer closes it, then the drawer, then the focus is on Notes. **Failed:** after Tab then Enter the composer opens and the focus stays on the element in the page, so what is typed next goes to the page (3 of 3) until the text box is clicked or Shift+Tab leaves the page. Escape pressed there closes the drawer, and the focus does not go to Notes (3 of 3 with no composer open; after one, the second Escape did put it there). Both fixed the same day (viewer.js below, the review). The cause: a `focus()` the viewer calls does not take the focus from an element focused inside the frame (a plain `#notes.focus()` did not either); after `iframe.blur()` it does. Also where a script put the focus on the frame, not where it is there from the load or a click on text.

**Criterion 33: held**, 18 assertions, with one wait added: a write less than 100 ms old when the driver closed the window was lost (frame.js names it), and `keeps` closes it that early, because its wait for the entry of `boards/going.html` is met by the second docroot's entry of the same name. Given 0.4 s, the deleted page's entry was there and went on the next load (4 of 4).

**Not driven:** the print dialog (with it the key press never returned, so `print.always_print_silent` was set); a window that really loses the focus; a tab brought to the front (BiDi's call did not answer, so each page had a window of its own). Not run: stock Firefox, Firefox on the LAN, the dark scheme, the other criteria.

### Header, moved 2026-11-25 (0.20.0)

Moved verbatim from the module docstring, whose first line and pointer stayed, when it was cut to three lines. `--help` prints the first line only.

```text
Serves a docroot (default ./.cc-artifacts/design-kit) on 127.0.0.1:8124: /_gallery, and / and /index.html while the docroot has no index.html, a gallery (flow strip, token badges, each page in a sandboxed frame; a design-system/ folder in it is not listed), /_events SSE (0.75 s poll: reload at any change; with ?page= at a change of that page's inode, size or mtime, or of the newest mtime of a file in its own folder that is not a page, gone when its file goes, 404 where there is no page), /_index.json, /_page?page= (Sec-Fetch-Site absent or same-origin: a page's title and framed content URL, and its allowed hosts for a peer that may write), /_c/<segment>/ (GET and HEAD, with no LAN key once isolate.open_segment opens the segment: its page with frame.js first, or a file isolate.may_load gives that page both by its path and by what it resolves to, each under page_policy, readable from any origin, no-store; a framed one opened as a document is 303 to its page URL), a page URL (text/html, .html, .htm, a folder's index.html or index.htm) the viewer (/_viewer.js, /_viewer.css), never the page itself, except that a loopback peer with a headless user agent or ?static=1, and Sec-Fetch-Site absent or none, is sent (303) to the page's static segment, any other file as it is; three write routes, POST /_decision (a v:2 pick of the fields picks.py keeps and the server's own prompt into decisions.jsonl, <= 64 KiB of JSON), POST /_note (a note row with text, every field clamped, numbers to +-1e7, into notes.jsonl, <= 8 KiB), both one row per cid among the file's last 50, and POST /_allow (a host one page may load from, in or out of .allow.json through isolate.set_allow, <= 8 KiB), each under its file's lock, loopback peer and Host, an Origin, when sent, of http:// and that Host, its own X-Design-Kit-* header, else 403 / 413 / 400; a lone surrogate in a stored text is stored as ?, a file that would pass 2 MiB answers 507, a failed write a JSON 500, and no file is followed through a symlink; GET /_notes?page= and /_checks?page= (loopback) list a page's notes and its last dk check (.checks/results.json, which render-check.py alone writes: no route takes findings). Never served (404 to GET and HEAD, origin- or absolute-form target): dot paths, auth/, the IGNORED state files, *.versions.json, directory listings, a path that resolves outside the docroot or to one of these. GET, HEAD and POST answer 403 unless Host is localhost or an IP literal, and 404 to Service-Worker: script; every answer carries isolate.py's headers, an XML type (SVG, XHTML) its sandbox policy. --lan binds 0.0.0.0, asks every non-loopback peer for the key in <docroot>/.preview.key (?key= once, then an HttpOnly SameSite=Strict cookie; else 403) and exits after DESIGN_KIT_LAN_MINUTES (60); every mode exits after DESIGN_KIT_IDLE_MINUTES (240; 0 = off) with no request that passed the key gate and no open stream, and on a self-exit (idle limit, LAN limit, Ctrl-C; not a kill) removes .preview.pid/.url/.bind/.ver while the pid file names it.
Misses: whoever holds the keyed URL reads every non-state file under the docroot, signed-in screenshots included, and the key crosses the network in clear (plain HTTP); whoever holds a content URL reads that page and its files with no key until the server stops; a hard link to a never-served file is served; a raw page opened by hand (?static=1) runs with no viewer around it; where no Sec-Fetch-Dest is sent (plain-HTTP LAN) only frame.js takes a top-level framed page to its page URL; a cid older than its file's last 50 rows is recorded again; a page's stream says nothing of a file that comes into its folder older than the newest there; a host without fcntl, or a lock file that cannot be opened, leaves a write unlocked; export and publish are scripts, not routes, and nothing restores an old version; port 8123 is never the default (the taskmaster/ui-ux mockup server); a page is rendered and checked only when dk check runs (render-check.py), never on its own.
```

### 0.16.0, 2026-11-13 — the check's routes (M3, render checks)

Milestone M3 of the preview-server work (the spec lives in the gitignored `taskmaster-docs/`). The header's last miss, "nothing proves a browser rendered a page", now reads: a page is rendered and checked only when `dk check` runs. The server's part: a loopback `?_check=<run>` gets `CHECK_TAG`, one same-origin `import()` of `/_check.js` (96 bytes), instead of the reload client, so the reload snippet is unchanged (758 bytes before and after, ceiling 800). The tag goes before `</body>`, or at the end of a page that has none, since the parser takes a trailing script into the body; the reload client keeps its old rule. `/_check.js` (`scripts/check.js`) and `/_check-axe.js` (`vendor/axe-core/axe.min.js`) sit in one `SCRIPTS` table with `/_note.js`, both loopback only (404 otherwise). `POST /_check` reuses `/_note`'s guards with its own `X-Design-Kit-Check` header; `check_row` keeps named fields, needs a run id matching `[A-Za-z0-9_.-]{1,48}`, keeps at most 60 findings whose id matches `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`, clamps selector 300, text 200, detail 300, and appends under `.checks/.lock` to `.checks/inbox.jsonl`. `.checks/` is a dot folder on purpose: the dot rule keeps it unserved and `_newest_mtime` skips it, so a check never reloads an open page; `checks_dir` makes it 0700 and refuses a symlink there (500, nothing written). `GET /_checks?page=` (loopback, like `/_notes`) answers the page's entry in `.checks/results.json` and whether its mtime moved since. `show()` and its blank-character set moved here from `dk notes` so both readers escape page text with one function. Red, all in `check.test.sh` against a server without the routes: `FAIL: ?_check= from loopback did not inject the check import`, then each reject and the never-served probes.

### 0.15.0, 2026-11-13 — notes on any served page (M2, the feedback loop)

Milestone M2 of the preview-server work: A1, A2, A3, A4, A6 and A1c for design-kit. The spec lives in the gitignored `taskmaster-docs/`.

**Route (A1).** `POST /_note` shares `/_decision`'s guard code, refactored into `_not_local` plus one body reader: the key gate first, then a loopback peer even with a valid LAN key, a loopback `Host`, a loopback `Origin` when sent, its own `X-Design-Kit-Note` header (the decision header does not open it), 1..8192 bytes, a JSON object. `note_row` builds the row from named fields only, clamps each, and turns NaN, Infinity, booleans and strings in number slots into 0 (Python's `json.loads` accepts `Infinity`). `notes.jsonl` joined `IGNORED`, so it is never served and its writes do not reload open pages; `_newest_mtime` now also skips dot files (the `.notes.lock` lock and dk's `.notes.jsonl.tmp`), which are never served either. Without that, the first note created the lock, every open tab reloaded, and a half-typed note in another tab was lost. Appends and dk's rewrites hold `fcntl.flock` on `.notes.lock`, so a note posted while `dk notes --reply` rewrites the file is not dropped by `os.replace`. Red, run against HEAD's serve.py in a scratch copy: `POST /_note` 501, `GET /notes.jsonl` 200, `GET /_notes` 404, no outline tag on `?_outline=`.

**Widget (A2, A4, A6).** The reload client grew by one statement, `import(location.origin+"/_note.js").catch(function(){})`: 702 bytes before, 758 after, ceiling 800. `location.origin` rather than a bare path because a page's `<base href>` would otherwise send the import to another host. The script is `scripts/note.js`, served from the plugin, never from the docroot, so the opt-outs are the reload client's own: a headless browser, `?static=1`, a file, another server (the import 404s and the catch swallows it). The gallery gets the client without the import. Red: `FAIL: the reload client does not load the note widget from its own origin`, then `FAIL: /_note.js should be 200 JavaScript, got 404`. One exception to "not for headless": a loopback request carrying `?_outline=` gets `<script type="module" src="/_note.js">` and no reload client, and the script then draws only an outline, for `dk notes --shot`.

**Reader (A3).** `dk notes` hands out unread open rows and marks them (`handed_out`, a timestamp), `--all` lists without marking, `--wait` polls every 0.5 s and also returns on an unconsumed pick, printing it as `dk decision --latest` does and leaving it unconsumed, `--reply` rewrites one row under the lock, `--shot` runs the browser `board-export.sh --which` finds against `http://127.0.0.1:<port>` (not the URL file's host, which is the LAN address in LAN mode) into `.design-kit/.notes/` (0700, a dot folder, so never served). Red: `FAIL: dk --help does not document dk notes`. **Hook (A1c).** Red: `FAIL: notes line:` (silent). It counts open, not-handed-out notes and prints no page string; the board name of a pick, also page-posted, is now printed only when it is a plain file name, else "a board".

**Browser run, 2026-11-13** (Playwright's Chromium 157, headed user agent, through the Playwright MCP). On an artifact page: the toggle opened the panel and every element's bounding box was unchanged; the hover outline followed the pointer; a click on the Churn card's `2.1%` paragraph opened the box anchored under it with focus in the textarea; Send wrote `div[data-metric="churn"]:nth-of-type(2) > p`, which `querySelectorAll` resolves to exactly that element, viewport 1241×1252, theme `light`. A `dk notes --wait` started before the click returned with that row, exit 0. A page note carried `console.error('chart failed', new Error('boom'))` and an uncaught error as `["chart failed boom", "Uncaught Error: late failure"]`. `dk notes --reply … --status addressed` showed on the page after a reload. `?static=1`: no widget, no request for `/_note.js`, no console error. From a file and from another server serving a saved copy: no widget, no exception. On a board: Pick still recorded (`picked: 2`, toast, `dk decision --latest` read it), and typing `f`, `e`, `k` in the note box left the board's fit, edit and knobs alone. `dk notes --shot` wrote a PNG with the noted button outlined and no widget. Alt+N toggled; Tab to a page button and Enter opened the box on it. Two defects the harness could not see were found and fixed in this run: the module called `start()` above its `const` declarations, so it threw in the temporal dead zone and the import's catch hid it (no widget at all); and Escape kept the draft, so a reopened box doubled the text.

Not exercised: a screen reader (Chrome's accessibility tree lists the toggle as `button:Notes`; nothing more), Firefox and Safari, a page that styles every `div` or uses its own capture-phase handlers, a phone over LAN (the widget stays hidden off loopback by design). Residuals: a page carrying third-party script can post a note from the same origin; note text is user-typed and unverified; selectors that rely on `nth-of-type` break when the page's structure changes before a shot; no screenshot without a Chromium-family browser; notes do not travel with an exported or published page. The spec's A2 proof named a `variant` field on board rows; the row shape this milestone was given has none, so a board note's variant is only in its selector (`#board-1 …`).

### 0.15.0 review, 2026-11-13 — writes that answer, and stop

Cases added to `serve.test.sh` first and run red in a scratch copy of the unfixed server, then fixed:

- **A lone surrogate** (the widget cut text through an emoji) made the append raise `UnicodeEncodeError`,
  which nothing caught, so the post got no response; `knobs` and `text` in a decision could do the same.
  `_clean` replaces each with `?`, inside nested objects too. Red: `FAIL: a note with a lone surrogate should
  be 200 and stored with ? (000)`, the same for a decision. `RecursionError` is caught as 400 on the parse
  and the record; Python 3.14 here parses 8 KiB of `[` as a plain decode error, so that half was not
  reproduced.
- **Empty notes and failed writes** match taskmaster: a note without text is 400, a failed append a JSON
  500. Red: `FAIL: a note without text ({}) should be 400, got 200`, `FAIL: an append that fails (notes.jsonl
  is a folder) should answer 500, got 000`.
- **Numbers** clamp to ±10^7; `1e308` was a 309-digit integer per rect field. Red: `FAIL: note numbers are
  not clamped to +-1e7`.
- **A size cap.** `notes.jsonl` and `decisions.jsonl` stop at 2 MiB (507 with a JSON reason). Red: `FAIL: a
  post to a full notes.jsonl should be 507 …, got 200`, the same for `decisions.jsonl`.
- **No symlink.** `notes.jsonl` was opened with `open("a")`, so a tracked symlink there let a post append to
  its target. Appends and `_jsonl` reads now use `O_NOFOLLOW` (and appends 0600). Red: `FAIL: a note was
  appended through the notes.jsonl symlink`, `FAIL: /_notes read through the notes.jsonl symlink`.
- **The outline tag** loaded `src="/_note.js"` by bare path, which a page's `<base href>` sends elsewhere;
  it now runs the reload client's `import(location.origin+"/_note.js")`. Red: `FAIL: the outline tag loads
  /_note.js by bare path`. The reload snippet itself did not change (758 bytes, ceiling 800).

### 0.14.0, 2026-11-12 — idle shutdown, a LAN key, a reload client that survives a restart

Milestone M1 of the preview-server work: B2, B3, B6 and the header fix. The spec and the research it rests on live in the gitignored `taskmaster-docs/`.

**Idle shutdown (B3).** A server started in one session kept its port, and the docroot readable, for as long as the machine stayed up. It now exits after `DESIGN_KIT_IDLE_MINUTES` (default 240, `0` = off) with no completed request and no open `/_events` stream, in loopback and LAN mode alike, and says so on stderr at start; `preview.sh` discards that stderr, as it always has. An open tab holds the server, since the injected client keeps a stream open. A self-exit leaves `.preview.pid`, `.url` and `.bind` in place, exactly as the LAN expiry it shares a code path with (`srv.shutdown` from a thread); `preview.sh` reads the pid as dead and replaces them, and `--stop` says "nothing running" and clears them. Residual of both exits: a pid the OS has recycled reads as running, so a later `--stop` could signal an unrelated process of the same user, and `dk status` prints the stale URL. The harness case ran red first: `FAIL: no idle-shutdown notice on stderr at start`, and with the two notice checks removed, `FAIL: server outlived DESIGN_KIT_IDLE_MINUTES`.

**LAN key (B2).** Before this, `--lan` had no key: anyone on the network who guessed or saw the port read every page. The verdict is a pure function, `lan_gate(key, peer, query, cookie)`, unit-tested over loopback forms, right, wrong, short, long, empty and non-ASCII keys, cookie jars and malformed cookies; end to end, the harness requests this machine's own network address, which the server sees as a non-loopback peer. The key is 16 random bytes (`secrets.token_urlsafe`, 22 characters): plenty against guessing on a LAN inside a 60-minute window, short enough to type on a phone. The cookie is `design_kit_key`, not `key`, because cookies ignore the port and taskmaster's server answers on the same host. `--stop` deletes `.preview.key`, so ending a share retires its URL; a LAN expiry, an idle exit or a kill keep it, so a phone's link survives a restart. In LAN mode `.preview.url` holds the network address, so every URL `dk.sh` prints, and `snapshot.sh`'s review URL, carries the key too: this machine's own browser is a non-loopback peer at that address. The red runs: `FAIL: lan_gate / without_key unit cases`, and end to end `FAIL: --lan wrote no .preview.key`.

The spec asked for a 303 to the clean URL. Measured in Chrome (`google-chrome --headless=new` with a non-headless User-Agent, over CDP, 2026-11-12): a keyed link followed from another site, a page on `127.0.0.1` linking to the LAN address, got the 303 and the cookie, then 403 on the clean URL, and 403 again on reload. Chrome withholds a `SameSite=Strict` cookie on a navigation another site started, redirects included. Typed into the address bar, the same URL worked. The first keyed visit now answers 200 with the cookie and a meta refresh to the clean URL, a navigation the preview's own origin starts; the same run then served the page, with its live-reload stream open, on the click and on the reload. `Lax` would also have fixed it; `Strict` was kept because the spec named it and the meta refresh costs one small page.

**Reload client (B6).** 170 bytes before, 702 after, ASCII only. On a lost stream it shows one `role="status"` bar, fixed bottom-left, `pointer-events: none`, with no animation or transition, so `prefers-reduced-motion` has nothing to reduce; it retries at 1, 2, 4 … 30 s and, on the first stream that opens, removes the bar and reloads. The headless and `?static=1` opt-outs are unchanged code. Browser run, same Chrome: stop, the bar appeared within 2.5 s and was still one bar at 5.5 s with the page not reloaded; start, the page reloaded and the bar was gone 1.2 s later; `?static=1` carried no client; no exception. The harness asserts only the injected text (role, `setTimeout`, `location.reload`, no external asset, at most 800 bytes), not this behaviour.

**Header.** It said "export, restore and publish are scripts". No restore script or route exists in this plugin (grep, 2026-11-12); versions sit on disk under `.versions/` and nothing restores one. The header now says so.

Residuals: plain HTTP, so the key crosses the network in clear; the key sits in the URL, so it lands in the phone's history and in any chat it is pasted into; a container or VM on this machine reaching the LAN address needs the key; nothing rotates the key but `--stop`; the 403 page is the stock `http.server` error page.

### 0.14.0 review, 2026-11-12 — one target parse, cookies split by hand, the key file never followed

A review of commit `e8d64997`, before release, found these; each harness case ran red first.

- **Check and open read different paths.** `do_GET` checked `translate_path(urlsplit(self.path).path)`, the stdlib's `send_head` opened `translate_path(self.path)`, and `translate_path` ran `urlsplit` again. For the absolute-form target `http://x//auth/walk.json` the check saw `/walk.json` (host `auth`) and the open saw `//auth/walk.json`: 200 with the file on Python 3.14.4, and the same for `//.preview.key` and `//decisions.jsonl`. `do_HEAD` skipped the check (`HEAD /auth/walk.json` 200). The stdlib folds an origin-form `//x` to `/x` (gh-87389), which is why the old probes passed. Now `split_target` parses the target once, `send_head` (GET and HEAD) answers 404 unless `_servable`, and the stdlib branch it falls through to opens `translate_path(self.path)`, the same pure mapping. Page injection moved into `send_head`, so HEAD reports the injected length. Red: `FAIL: HEAD /auth/walk.json should be 404, got 200`, then `FAIL: GET http://x//auth/walk.json should be 404, got 200`.
- **SimpleCookie.** `SimpleCookie.load` returns an empty jar when any cookie in the header breaks its grammar (`theme=dark mode`, a valueless `flag`, `x=a"b`), so the key cookie was lost and a phone got 403 while that other cookie lived. Split by hand, exact name. Red: four unit cases `wanted pass, got deny`.
- **The key file.** `_lan_key` read with `open()`, wrote with `O_CREAT|O_TRUNC` and `chmod`-ed by path, all through a symlink at `.preview.key`. Now it opens `O_NOFOLLOW|O_NONBLOCK` and checks `fstat` (an `lstat` first would leave a gap before the open); anything but a regular file holding a key is unlinked and replaced `O_EXCL|O_NOFOLLOW` at 0600; a directory there is exit 4. Red: `FAIL: .preview.key is still a symlink after a --lan start`.
- **The idle clock and POST.** Every finished request reset the idle clock, key-gate 403s included, and `do_POST` never called the gate (a keyless POST got 501). Now only a request `_gate` admitted resets it, and `do_POST` calls `_gate` first; a right `?key=` on a POST passes without the cookie page, and `/_decision` stays loopback-only. Red: `FAIL: a POST from a LAN peer without the key should meet the key gate (403), got 501`. The idle case was written after its fix, then run against HEAD's serve.py in a scratch copy: `FAIL: 403s from a LAN peer without the key kept the server from its idle exit`.
- **State files on a self-exit.** Any exit through `serve_forever` (idle, LAN timer, Ctrl-C) now runs `_drop_state`: `.preview.pid`, `.url` and `.bind` go when the pid file still holds this process's pid. A SIGTERM from `--stop` skips it; the launcher removes them. Red: `FAIL: serve.py left its pid or url file after an idle exit`. This supersedes the 0.14.0 note above that a self-exit leaves the files.

### 0.13.1, 2026-11-11 — what a review found being served

A review on 2026-11-11 fetched `/auth/walk.json` (the saved login session the README tells users to keep there), `/workshop.json`, `/usage.jsonl`, `/.preview.pid`, `/artifacts/.versions/` and directory listings from a running server, all 200. After one `--lan` start, `preview.sh` reused the 0.0.0.0 server for every later loopback command; `ss` showed it still bound in a later call. A POST to `/_decision` with `Host: attacker.example` and `Origin: http://attacker.example` was stored. With ten pages in the gallery, a Playwright-driven Chrome stalled 8 s on any other request while the gallery tab was open, because each thumbnail iframe held an EventSource. Hence `_servable`, `list_directory` returning 404, the Host/Origin check, `?static=1` on thumbnails, `.preview.bind` and the LAN timer. Left open on purpose: no per-board token, since a page on the same origin can read the board's HTML and so any token in it.

Moved verbatim on 2026-10-28: the module docstring (quotes removed; `--help` prints only its first line, which the file keeps) and the measurement date from `_wants_live`'s docstring.

### Module docstring

```text
design-kit preview server — one localhost URL for every design-kit surface.

WHAT IT DOES. Serves a docroot (default ./.design-kit) on 127.0.0.1:8124 with:
  GET /              a gallery: every deck, board, artifact and preview under the
                     docroot, newest first, grouped by top-level folder, with an
                     iframe thumbnail per page
  GET /_events       Server-Sent Events; a tick each time any file under the
                     docroot changes mtime (0.75 s poll), so every served page that
                     includes the reload snippet refreshes itself
  GET /_index.json   the same listing the gallery renders, for scripts; each page
                     carries `tokens`: the design-kit-tokens stamp it was built
                     with and whether it still equals sha12(design-system/tokens.json)
  GET /<path>        static files; .html pages get the reload snippet injected
                     before </body> — except for a headless browser (User-Agent)
                     or a `?static=1` query, because an open event stream keeps a
                     screenshot or print from ever settling
  POST /_decision    the ONE write route: a board's pick / knob / text-edit state,
                     appended as one JSON line to <docroot>/decisions.jsonl with
                     consumed:false. Accepted only from a loopback client, only
                     with the X-Design-Kit-Decision header, only ≤ 8 KiB, only
                     valid JSON — else 403 / 413 / 400. `dk decision` reads it.
The gallery also shows a FLOW STRIP read from <docroot>/workshop.json (written by
dk.sh) and a per-card token badge: green when the page's stamp equals the current
tokens.json hash, amber "tokens moved since build" otherwise.
--lan binds 0.0.0.0 so a phone on the same network can open it. That is the only
path here that lets a page leave the machine, and the launcher says so. /_decision
stays loopback-only under --lan: a pick made on a phone is NOT recorded.

WHAT IT DOES NOT DO. Export, restore and publish are scripts, not HTTP; the one
write route above is append-only and never touches a served file. No auth: the LAN
mode is for a phone on your own network. Port 8123 is the taskmaster/ui-ux mockup
server and is never the default here.

Standing: scripts/__tests__/serve.test.sh drives start, static serving, the
reload injection, /_index.json, the /_decision accept and reject paths, both badge
states, and stop. Nothing proves a browser rendered a page.
```

### _wants_live

```text
Headless browsers taking a screenshot or a print must not get the
reload snippet: its open EventSource never goes idle, so a virtual-time
budget never expires and the capture hangs (measured with Chrome 2026-09-22).
`?static=1` opts any client out.
```

### 0.16.0, 2026-11-13 — the check's routes removed

The review showed `POST /_check` let any same-origin script plant findings and a page under check answer for the check (render-check.py § review fixes). The check now runs in an isolated world over DevTools, so `?_check=` injects nothing, `/_check.js`, `/_check-axe.js` and `POST /_check` are gone (404, 404, 501), and `check_row`, `CHECK_TAG` and the inbox with them. `GET /_checks` stays: it reads `results.json`, which only render-check.py writes. Red: `FAIL: ?_check= should inject nothing (200)`, `FAIL: /_check.js should no longer be served, got 200`, `FAIL: POST /_check should be gone (501, nothing written), got 200`. The reload snippet is unchanged (758 bytes, ceiling 800).

## plugins/design-kit/scripts/isolate.py

### 0.20.0, 2026-11-24 — tokens, policies, files, hosts

The rules of the isolation in one module that imports nothing from serve.py: a units harness (`isolate.test.sh`) drives each with no server. Why pages needed isolating: serve.py above.

**The content URL.** `/_c/<token>.<page>[.s]/<path>`: the token is the first 22 characters of an HMAC-SHA256 over the mode and the page's name, with a secret made at each server start and never written. The page travels inside its own segment, so a token opens one page in one mode, and a path under it is refused unless it is that page or a file the page may load. The frame's requests carry no cookie: `SameSite=Strict` is never sent from an opaque origin, so a cookie check failed for every kind of file (script, image, font, audio, module, fetch; Chrome 158 and Playwright's Firefox build 1555, 2026-11-24). The token alone fixed script, image and audio; the token with `Access-Control-Allow-Origin: *` fixed module, font and fetch too; the other folder stayed blocked. Chrome refused a same-folder Worker file; blob workers run.

**The policy.** The whole text is asserted. `sandbox` without `allow-same-origin`, `allow-popups` or `allow-top-navigation` gives the opaque origin and stops popups and top navigation; `frame-src` of the viewer, not of the page, is what stops a frame that navigates itself. Every answer under `/_c/` carries it, files included, because an own-folder SVG or XHTML opened in the frame is a document of its own. Folder names are percent-encoded byte by byte: one holding `;` or a newline would otherwise write directives. A CSP source cannot hold a bracketed IPv6 address, so at such a `Host` the own-folder sources match nothing.

**Probes before it was built, 2026-11-23 and 2026-11-24.** Chrome 158: storage, parent DOM, fetch, beacon, form, popup and top navigation blocked. Of six self navigations (href, replace, anchor, `_self` open, form, meta) 0 reached a second server, in Chrome and in Playwright's Firefox build 1555 (157), and 6 of 6 did in the unguarded Chrome control. Chrome kills the frame on a blocked self navigation, Firefox keeps it. `localStorage` throws `SecurityError` there and can be replaced; `window.name` carries state in at load. Preconnect got past the policy: 3 connections from one page in Chrome 158, `X-DNS-Prefetch-Control: off` set. Not run: Safari, stock Firefox, WebRTC, a real LAN device. In Firefox only self navigation and own-folder files were probed.

**Where the client goes (`inject`).** Right after `<head>`, else after `<html>`, else after the doctype, else first, but never past anything a browser could build an element from: the spec's literal rule (the first `<head>` the parser reports) let a script before a late `<head>` run before the client. Tags that parsers read differently end the search. It reads the first 64 KiB. A UTF-16 page gets the client first and reads as garbage.

**Hosts.** `allowed_host` is a whole-string match, so an IP, a port, `127.1`, `0x7f.0.0.1`, a trailing dot or newline, a wildcard and `http` are refused, and `.local`, `.internal`, `.localhost`, `.home.arpa` with `home.arpa` itself. `.allow.json` is checked again at each read, replaced atomically at 0600, never through a symlink; a file that cannot be read allows nothing and is set aside by the next Allow. The name is not an address: a public name that resolves to a private one is an allowed host.

Misses: the header's line. `inside()` alone lets a symlink to a never-served file through; serve.py judges the resolved path by the same list (`_real_parts`), so the server answers 404, and the header no longer lists it.

### 0.20.0 review, 2026-11-25 — one home for what both sides decide

serve.py and this module each said what a page is, from two MIME sources, and disagreed on `report.html.gz` (`text/html` to this one, `application/gzip` to the server). `is_page` asks what the server sends by, for both, so that file is one a page of its folder may load. `CONTENT`, the viewer's two asset names, `SANDBOX` (the policy's and the iframe's tokens), `nofollow` and `replace_file` are written here once: the last writes beside the file under a dot name, 0600, and puts it in place in one step or leaves nothing. `.allow.json`, dk.sh's two rewrites and render-check.py's `results.json` go through it.

## plugins/design-kit/scripts/picks.py

### 0.20.0, 2026-11-24 — what a pick may hold, and the one line a session reads

Before, `decisions.jsonl` kept the board's own `prompt` (up to 4096 characters of page text) and `dk decision --latest` printed it, under a skill that said every line of it was a requirement: any page could put words into the session (I5 of the scan of 2026-11-23). The module decides what a posted pick may hold, and composes the line; `serve.py` stores through `clean_pick`, `dk.sh` prints through `pick_line`, which clamps again at read, because an older server or another hand may have written the row. `confirmed` is true only for `v:2`, which the server writes for a loopback post that carries the route's header; in a browser only the viewer can send one, and it does on a press. A row's own `prompt` is never printed; the one the server stores is fixed text with the board's name and the number, so a session of 0.19.3 still learns the pick.

**Bounds.** A board is a base name of 1 to 128 characters with no slash, backslash or hidden character, else 400; a picked number is 1 to 99 or null; knob scopes are `all` or 1 to 99; space and radius 0 to 64, hue 0 to 360, type and density 0.5 to 3, scheme light or dark (the board's sliders are narrower: 6 to 14, 0 to 24, 0.85 to 1.25 and 0.85 to 1.2); at most 100 text edits, the lowest artboards first, each `was` and `now` at most 500 characters. A knob's number past its bound is moved to it, a picked number past its own is null, anything else out of shape is dropped. `viewer.js` gets this table in the viewer's document (the review below), and `viewer.test.sh` compares what each makes of the same report.

**Open, by choice.** The name is quoted nowhere: a file of 128 characters of prose in `boards/` reaches the session inside the summary and the fixed prompt (run on 2026-11-25: 123 characters of words and `.html` came out whole, in the line and in the prompt). A name may hold `]`, a middle dot or an arrow and so imitate a step of `dk status`. A row written into `decisions.jsonl` by hand with `v:2` reads as confirmed.

### 0.20.0 review, 2026-11-25 — the viewer reads this table

`LIMITS` holds the knobs with their bounds and words, the decimals, the artboards, the patterns of a scope and a path, and the caps on edits and characters; serve.py hands it to the viewer, which kept a copy before. `VERSION` and `new_row` are the one home of a row's version and shape; the hook keeps its own 2, because it must not load modules. Numbers read the same in the strip and in the summary: two decimals, a tie up, as JavaScript's `toFixed` words them (density 1.125 is ×1.13 in both; Python's `%.2f` says 1.12, and the strip used to show 1.2345 whole).

## plugins/design-kit/scripts/frame.js

### 0.20.0, 2026-11-24 — the client inside the frame

A page in an opaque origin has no `localStorage`, cannot post its pick and cannot be read by the viewer, so a board, a deck or an artifact already on disk would lose its state, its pick and its links. This script runs before any of the page's own and stands in for each, so nothing on disk had to be rebuilt. It is a convenience, not a boundary: a page can undo or imitate all of it, and `attack.test.sh` runs every vector both ways. `frame.test.sh` holds it under 12 KB.

**What it does, and why it looks so.** `localStorage` is a map seeded from `window.name`, which the viewer sets before `src`; keys lose the page's own `/_c/<segment>`, or a board's key (`design-kit:` and the path) would change at every server start. A key over 256 characters and a write past 256 KB throw `QuotaExceededError`, as a full store does. A POST to `/_decision` becomes a `pick` message and is answered 409, so an old board shows no "Recorded". Writes go out at most every 100 ms, on `beforeunload` as well as `pagehide`, and before each pong: Chrome's `pagehide` messages from a frame that reloads itself carry a null source, and are not delivered at all when the viewer removes the frame, so the viewer pings and waits (at most 300 ms) before it replaces one. `window.name` is written again on leaving, for a page that reloads itself. A link's target becomes `_blank` for one task, so the page's own handlers decide first wherever they listen, and the sandbox refuses the window. An empty hash is sent as `#`. A download link to a file of the page's own folder navigates the frame and is reported as a link. A click on `html` or `body` reports no element. A framed page opened top-level where no `Sec-Fetch-Dest` is sent (plain HTTP on the LAN) is taken to its page URL before its own script runs.

**Probed in Chrome 158, 2026-11-24:** `beforeprint` fires in the frame on `window.print()`, a blob download lands. Firefox was not run for these that day; `beforeprint` was on 2026-11-25 (serve.py above, the Firefox hand run).

**The modified click.** The sandbox does not stop a trusted Ctrl, Shift or middle click on a link: Chrome opens a real tab, past the viewer's link strip. `frame.js` prevents it and reports the address, but a page can avoid `frame.js`; then each such click opens a tab with 1 request, and Alt+click starts a download with 1 request and no tab (`attack.test.sh` prints the counts as NOTE lines and never fails on them). The user accepted this on 2026-11-24. In Playwright's Firefox a page needs no modifier from the user: its own Ctrl- or Shift-click event, made while it handles a plain click or a key, opens the tab (the Firefox hand run, found on 2026-11-25, after that; run again that day on the code after the review: 12 of 12, none with frame.js there).

### 0.20.0 review, 2026-11-25 — an image whose src a script sets

A page of an opaque origin reads its own folder's files across origins, so an image drawn into a canvas taints it and a WebGL texture refuses it (`SecurityError`), which broke pages that worked under 0.19.3. The client gives `crossOrigin = 'anonymous'` to an image whose `src` a script sets to a file of this server, where the page set none, and takes it back when that image goes to another address; the server sends `Access-Control-Allow-Origin: *` under `/_c/`. Run in Chrome 158 on 2026-11-25, framed and static: such an image reads back and loads as a texture; one in the markup, one by `srcset`, `setAttribute` or `innerHTML`, and a video do not unless they carry `crossorigin="anonymous"`, which the markup's, the `srcset` and the video then do. Not covered by choice: patching those too costs bytes, and the file is 12,287 of the 12,288 it may have.

## plugins/design-kit/scripts/viewer.js

### 0.20.0, 2026-11-24 — the bar around the frame

The viewer is the only thing that records: it runs on the control origin, under a policy that allows its own script file and nothing inline, with trusted types required, and it builds no markup from text (`viewer.test.sh` greps for `innerHTML` and its kin). Everything the page says arrives as a message, acted on only when its source is the viewer's own frame, its type is known and its shape fits, at most 50 a second but for storage.

**Consent.** A press on Send pick, Discard, Allow, Remove, Open or Send note counts only 600 ms after the last change was painted: of a strip, a drawer, a Network row, the window's size, its visibility, its focus, fullscreen. Any mutation in `#strips` or `#drawer` holds the guard. The window's focus is a poll of `document.hasFocus()` every 100 ms: the focus event also fires when the focus leaves the frame, and not when it comes back with the focus inside it. A page that changed its strip on purpose could keep the buttons shut for ever, so while a consent control shows, what a page brings is drawn no sooner than 1.5 s after the last change; that is why a page's key or a picked element can act up to 1.5 s late. A page that opens dialog after dialog still keeps them shut. While a POST is pending its buttons are `aria-disabled`, not `disabled`, which would drop the focus; one with no answer in 10 s offers Send again with the same `cid`.

**The pick strip** shows every report a board sends, the same again included, with the clamped snapshot that Send posts, and is kept in the tab's `sessionStorage`; no "last sent" memory (a user could not send the same pick twice). Two tabs of a board each have their own.

**Storage.** One `localStorage` entry per page key, `dk-store:<project>:<page>:<key>`, with `%` and `:` of the page's name percent-coded; the project is 12 hex digits of the docroot's real path. 0.19.3's `design-kit:/<page>` entry is moved in once. Entries of a page that is gone go only when `/_page` answers 404 for it, because `/_index.json` leaves out `.shtml` pages and `design-system/`. A store message of more than 262144 items is dropped, and at most 1000 refused keys are remembered.

**The frame.** A new `iframe` element for each load, so a load adds no history entry. It is pinged every 2 s; 8 s without an answer while the window shows draws "This page is not answering", and any later answer takes it away; dialog time counts and nothing reloads by itself. Reload page on a page that never stops computing gets the same Chrome process, so it answers only when the loop ends. A `frame-src` violation replaces the frame by the stopped area. A lost stream asks `/_page` before it says the server is lost. A kind of file refused 300 ms or more after its host's first is said with the host again; at most 10 strips, then a count, and at most 100 hosts; a host not refused again within 1 s of the next load leaves the list.

**Walked by hand on 2026-11-24** (Playwright MCP, Chrome, 1280 and 375 px, by the run's orchestrator, relayed here): boards empty and picked, a deck at `#/3`, a blocked artifact, notes, a note sent, network, stopped, gallery; no sideways scroll, frame origin null, focus rings, no page error but the fixture's two refused outside files. Not observed: the LAN, the dark scheme, a screen reader.

### 0.20.0 review, 2026-11-25 — the focus a page takes, and the key of 0.19.3

**The focus.** After one click inside a page, that page's `focus()` takes the focus out of the viewer, whatever its sandbox says: of "secret typed into the note" the composer got "se" and the page the rest. `inert`, `visibility:hidden` and `allow="focus-without-user-activation 'none'"` did not stop it, `display:none` did (the review's probes, Chrome 158, relayed). The viewer gives it back when it went from a viewer control to the frame and the user did not move it there by Tab or by a press: that is, unless the pointer is over the page, or was last a finger, with nothing typed for 500 ms, and no note is being written on an element picked in the page, where a press picks another. It looks at the window's blur and every 16 ms, gives back at most 8 times in 16 ms, and `pressed` trusts no key of a page that holds the focus otherwise.

Characters of 26 the page still got, typed at 60 ms a key, 3 runs each on 2026-11-25: Chrome 158 0 at 100 ms, 0, 0 and 3 at 5 ms, 25 with no pause; for a note on the page itself 26 with the pointer resting on the page for 0.9 s, and 26 after a touch; none where nothing was pressed in the page. Playwright's Firefox 157: 1, 1 and 2 at 100 ms, 21, 21 and 22 at 5 ms. `viewer.test.sh` prints its own counts as a NOTE. From reading, not run: giving the focus back may fight a screen reader, the browser's find, or a finger after a mouse press.

**Firefox.** `iframe.blur()` before `focus()` takes the focus out of the frame. In Playwright's build on 2026-11-25: after Tab then Enter the composer has the focus and gets what is typed (3 of 3), Escape pressed in the page with no composer open closes the drawer and focuses Notes (3 of 3). Tab from Notes stays on Notes, as before the review (3 of 3).

**The key of 0.19.3** was built with `new URL` on a raw file name, so `#`, `?`, a backslash or `%2e%2e` in it named another page and moved that page's state. Those characters are encoded first now, and the key is also looked up in the form Python's `quote()` gave the gallery's links.

**One home each:** the rules come from `data-rules`; the note list's label, "Send note", the JSON-or-null fetch and the tab's storage are one helper each.

## plugins/design-kit/scripts/viewer.css

### 0.20.0, 2026-11-24 — the contract's look

The palette is the project's, chosen with the top bar in the mockup the user picked on 2026-11-24, in the reader's light or dark scheme. `viewer.test.sh` places seven states (empty, pick, blocked, network, notes, stopped, LAN) at 1280 and 375 px, with 0 axe-core violations in the viewer's document, and takes a screenshot of each into a temp directory; a frame row keeps at least a fifth of the window. Its dark scheme's contrast is in no harness. No rules for print or forced colours.

## plugins/design-kit/scripts/note-shot.py

### 0.20.0, 2026-11-24 — the outline over DevTools

`dk notes --shot` used to ask the server for `?_outline=<selector>`, which put the plugin's own script into the page it shot, in the page's world, where the page's script can replace the DOM methods it used. `?_outline=` and `/_note.js` are gone (`dk.test.sh` asserts both) and the outline is drawn in an isolated world over DevTools, by render-check.py's Chrome; `dk.test.sh`'s hostile page answers for `querySelector` and two more and the outline still lands. The selector is page data: it travels as an argument of a function, and a NUL in it as U+FFFD, since an argument list cannot carry one.

**Choices.** 2 s of real time after the load event, not a virtual-time budget: on that clock what a scroll reveals never gets its frames. The element is scrolled to first, then the wait, then the outline is placed again. A selector that matches nothing still shoots, and says so on stderr, because the page as it is still says where the note was. The window is the note's own viewport, held to 320 to 3840 by 240 to 2160. The browser runs behind the check's dead proxy, so a host the user allowed is not loaded. With the browser's sandbox off, its line says `dk check: the browser's sandbox is off`, since the two share the class. Misses: the header's.

### 0.20.0 review, 2026-11-25 — one limit

0.19.2 gave the browser 60 s because a cold Chrome ran past 30 s on CI. Over DevTools the first answer was held to `START_S` (30 s) and each later call to 10 s, so the old failure was back. A shot is one page: its calls wait for the run's deadline, 60 s in all, and `Chrome.close` no longer waits `START_S` more for a browser that never answered. The browser lookup, the server's start and the signal handlers, copied here and drifted, are render-check.py's. Red: `FAIL: a browser that starts 11 s late should still shoot`, `FAIL: a later answer that takes 11 s should still be waited for`, `FAIL: a browser that never answers should end at the limit with exit 4`.

## plugins/design-kit/scripts/note.js (removed in 0.20.0)

The widget ran in the page. Its button, composer and list are the viewer's (viewer.js above), its selector and context are the in-page client's (frame.js), its outline for a shot is note-shot.py's. The text below stays as history; check.js still holds a copy of its selector.

### 0.15.0, 2026-11-13 — why it looks the way it does

Loaded as a module by the reload client's `import()`, so it costs the injected snippet 56 bytes instead of its own size. Everything renders in an open shadow root on a host appended to `<html>`, not `<body>`: page CSS cannot restyle it, a fixed host takes no layout space, and it does not become the body's `:last-child`, which a page's `body > :last-child` rule would otherwise stop matching. Chrome's accessibility tree still lists it. Key events are stopped at the host because a board's and a deck's document-level shortcuts read `e.target`, which shadow DOM retargets to the host, a `div`, so their "typing in a field" check fails and `f`, `e`, `k` or Space would act on the page. While picking, capture-phase listeners on `window` stop pointer and click events so a click picks instead of navigating, picking an artboard or panning a board. Alt+N, not a bare letter, because boards use F/E/K and decks S/O/P; a deck ignores Alt. Console capture wraps `console.error` and listens for `error` (capture phase, so failed `<img>`/`<script>` loads count) and `unhandledrejection`, from the moment the module runs; earlier errors are missed. The entry block sits at the end of the file: a call above the `const` declarations throws in the temporal dead zone, which the snippet's catch hides. The browser run is in the serve.py section above.

### 0.15.0 review, 2026-11-13 — browser run before and after

A private Playwright Chromium (build 1248, headed user agent) on a test page served by this server, once
with the pre-fix `note.js` and once with the fixed one. Before: `console.error('boom', o)` with a circular
`Object.create(null)` threw `Cannot convert object to primitive value` into the page, and the
`unhandledrejection` listener threw too; Alt+N in the page's own input turned the widget on; Alt+N in the
widget's textarea closed it and wiped the draft `dise`; turning the widget off and on wiped `kept draft`; an
anchor text and a console entry cut through an emoji posted strings ending in a lone `\ud83d`; with
`?_outline=#target` and a block above it growing 400 px at 300 ms, the outline box sat 416 px above the
element. After: no throw (entries `boom [object Object]` and `unhandled rejection: [object Object]`); the
page's input kept Alt+N; the draft `dise` stayed with the box open; `kept draft` survived the toggle; both
strings ended in the whole emoji; the box sat exactly on the element (screenshots looked at for both). A
real `dk notes --shot` on the same page, sandbox on, outlined "Churn 2.1%" after the shift. The list
finding (a page note's text shown twice) did not reproduce with this file: the item read `open` and the text
once, both in the DOM and the accessibility tree. The fix asked for is applied anyway: an anchorless note is
labelled `Page`, an anchored one `<tag>`, then the text once, with spaces between, so the accessible text
reads `open Page Whole page: add a Q2 column` instead of `openWhole page: …`.

### 0.16.0, 2026-11-13 — the check line

The panel's second paragraph reads `GET /_checks?page=` on every refresh: "Checked <ts> UTC: N findings" (plus "; the page changed since" when the file's mtime moved), or "Not checked". Run in Chrome 157 over CDP with a headed user agent on 2026-11-13: a checked deck showed `Checked 2026-11-13 04:59 UTC: 1 finding`, a never-checked page `Not checked` (screenshot looked at). It fetches `location.origin + '/_checks'`; the widget's older `/_notes` and `/_note` fetches are still bare paths, which a page's `<base href>` would send to another host — not changed here.

### 0.16.0, 2026-11-13 — every fetch from the page's origin

`/_notes` and `POST /_note` were still fetched by bare path, which a page's `<base href>` sends to another host; both now go through `location.origin`, as `/_checks` and the import already did. Red: the harness's static check, `FAIL: note.js fetches a bare path`. A browser run of the panel was not repeated for this change.

## plugins/design-kit/scripts/check.js

### 0.20.0, 2026-11-24 — the selector

`note.js` is gone; the copied algorithm now also lives in `frame.js`, which runs in the page's own world, where check.js cannot trust it.

### 0.16.0, 2026-11-13 — what each check measures, and why these thresholds

The in-page half of `dk check`. As first built it was imported by a loopback `?_check=<run>` page and posted to `/_check`; before release it moved to an isolated world and returns its findings over DevTools (render-check.py § review fixes), and the route is gone. It waits for `load`, `document.fonts.ready` (at most 3 s) and two frames (at most 200 ms), measures, runs axe-core, and posts one body of at most 8000 bytes to `/_check`, dropping findings from the end and counting them. Every group runs in its own `try`; one that throws is a `skipped:` line, not a lost run. Selectors are `note.js`'s algorithm, copied, because importing `note.js` would start its widget.

**Page kinds and the stage.** A board (a `design-kit-board` meta) is loaded with `#board=N`, the shell's own isolate mode, at the frame's size, and its stage is `.dk-board.isolated .dk-frame`; a deck (generator meta `design-kit slides …`) has `.deck` as its stage and is measured slide by slide (`current` moved, every fragment `shown`, transitions off, then restored, at most 60 slides); anything else measures against the viewport. That is how the designed fixed stage stays out of the overflow check: content is measured against the stage, not the window. Before this, a 1440 px artboard on a 375 px window would have been 1065 px of "overflow".

**E1.** `E1.blank`: the stage has no visible text line, image, SVG, canvas, video or control. Misses a page drawn only with CSS backgrounds. The rest of E1 comes from the browser (render-check.py below).

**E2.** `E2.overflow` / `E2.wide`: elements and text lines whose right edge passes the stage by more than 1 px, outermost first, at most 3 elements plus text up to 4, skipping anything a scroll or clip container between it and the stage holds. When the root scrolls sideways (`overflow-x` visible on `html` and `body`) each is `E2.overflow`; otherwise (a clipped root, a deck or an artboard) only those with text, media or a control are `E2.wide`, so a decorative shape bleeding off a clipped page is not reported. Text lines are measured as well as boxes because an unbroken string overflows its line while its `<p>` box stays inside. `E2.clipped`: a text node's line rects against its nearest `overflow` ancestor; reported only when the node is partly inside and partly more than 1 px outside a `hidden`/`clip` edge, so a carousel's next slide or a collapsed panel (wholly outside) is not; `auto`/`scroll` is reachable, so skipped; the stage's and the root's horizontal edge belong to the overflow check. An ellipsis or line clamp passes only when a `title` or `aria-label` on the element or an ancestor holds text. One finding per clipping box, at most 5. `E2.overlap`: text grouped by its nearest block; two blocks neither containing the other overlap when a pair of their line bands overlaps by at least 4 px each way and 35% of the smaller band. The band is the middle 0.8 em of a range rect, not the rect: a range rect is the font's content area, up to 1.4 em with Noto Sans, so at `line-height: 1` the deck's big figure and its caption "overlapped" by 53% while the glyphs had clear space between them (screenshot looked at, 2026-11-13); with the band, that slide is clean and the fixture with a `-2.2em` margin still trips. Blocks under `visibility: hidden` or an effective opacity below 0.1 are skipped (scroll reveals start at 0). `E2.target`: axe-core's `target-size` rule, off by default in 4.14.0 and turned on here, because it already implements WCAG 2.5.8's 24 px minimum with the spacing and inline exceptions a box measure would get wrong; a lone small target with nothing near it passes, two adjacent 16 px buttons fail. `E2.viewport`: no `<meta name="viewport">` at a width under 600 px; the runner emulates a desktop browser at that width, so without this line a page a phone would lay out at 980 px and shrink would read as fine.

**E3.** `axe.run(document)` (a deck: the document, then each slide), `resultTypes: ['violations']`, impact `serious` or `critical` only, at most 3 elements per rule, each with axe's own message (for contrast: the ratio, both colours, the size). Moderate and minor rules (region, landmark-one-main, page-has-heading-one) are left out: generated pages are often fragments, and those rules fired on every fixture. axe is loaded with a classic script tag removed after load, since its UMD wrapper registers with a page's AMD loader if a module is imported; a page defining `define` or `module` would hide `window.axe` and E3 would be a `skipped:` line. Misses whatever axe marks incomplete (contrast over images and gradients), dark mode, and states after interaction.

**E4.** Over every text node of the stage, hidden ones too, because a deck's later slides and speaker notes are content: `lorem ipsum`, `dolor sit amet`, `consectetur adipiscing` (any case); `TODO` and `FIXME` (upper case only, so "todo list" is not one); "placeholder", "your <one to three words> here", "insert <one or two words> here", "sample text", "dummy text"; a whole text that is a stand-in noun and a number ("Item 3", "Card 1", "Feature 2"), reported when the same noun appears twice. "Step", "Option" and "Slide" are not on that list: numbered steps and options are real content. `E4.repeat`: three or more same-tag siblings whose whole text (8+ characters, at least one letter) is identical; table cells are left out, since "Yes" or "—" down a column is normal. `E4.empty`: a table with no `<td>` holding text, an image or a control, or a list with no item holding any. At most 3 findings per id. Misses: a word list in another language, placeholder images, numbers that are made up.

Red, before each was written: the harness's fixtures ran against a check.js that only had E1.blank, in a copy that kept going past the first FAIL (2026-11-13): `FAIL: e2-overflow: wanted exit 1 and [E2.overflow 375], got exit 0 and []`, and the same line for `e2-clipped`, `e2-overlap`, `e2-target`, `e2-viewport`, `e3-contrast`, `e4-lorem`, `e4-repeat`, `e4-todo`, `e4-placeholder`, `e4-generic` and `e4-empty`; `e1-blank` red in a copy with that check disabled.

### 0.16.0, 2026-11-13 — review fixes: false findings and caps

Each verified in Chrome 157 on a fixture through the runner before the change (2026-11-13), then a harness case. **M12**: `<h3 style="font-family:system-ui,sans-serif;font-size:24px;line-height:1.2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">Short title</h3>` read as clipped (with the default serif font, Noto Serif here, it did not: its content area fits a 1.2 line); vertical edges now use the line's 0.8 em band, as overlap does, and the ellipsis wording is kept for a horizontal cut (a line clamp's for a vertical one). **M13**: a `position:fixed; transform:translateX(100%)` drawer read as three `E2.wide` "cut off"; a box whose left edge is at or past the right edge, and what it holds, is skipped. **M14**: a fixed cookie bar over a long page read as `E2.overlap`; blocks inside a fixed or sticky box are skipped, and inside the viewport a pair is dropped when `elementFromPoint` at the overlap's centre finds neither block; pairs are swept by top, so 3000 blocks no longer cost 4.5 million comparisons. **M15**: "Track your order here" and "Insert your card here" read as placeholders and a TODO in a quoted diff as `E4.todo`; the filler pattern now needs taskmaster's template nouns (one word may precede them, so "your company name here" still counts), and E4 skips `pre`, `code`, `kbd`, `samp`. Red lines, in order: `FAIL: m12-ellipsis: wanted exit 0 and [], got exit 1 and [E2.clipped 375,768,1280]`, `FAIL: m13-drawer: … [E2.wide 375,768,1280]`, `FAIL: m14-bar: … [E2.overlap 375,768]`, `FAIL: m15-copy: … [E4.placeholder 375,768,1280 …`. **Caps**: element walks stop at 4000 with a `capped` note (red `FAIL: a 6000-paragraph page did not say it was capped`), and a deck past 60 slides says which were not checked. check.js now runs as one function in an isolated world and returns its findings (60, the rest counted) instead of posting them; see render-check.py.

## plugins/design-kit/scripts/render-check.py

### 0.20.0, 2026-11-24 — the raw page under its own policy

A check opens `?static=1`, which the server sends on to the page's static content URL, so what is measured is the page in an opaque origin under the policy it has in the viewer, with the in-page client first. Three things follow. A load the policy refuses is a finding of its kind and no console error: `E1.external` off the machine, else `E1.resource`, read from the network events or, for a fetch, media, a frame, a WebSocket or a form, which the network says nothing of, from the browser's log line (`REFUSED`, linear, since the page picks the URL). The lines the client adds before a page's own are passed over, so an exception is placed in the file on disk. A content URL opens its page without the LAN key, so none is printed. What a hostile page can still do to a check: the 0.16.0 paragraph below, less its last clause: `POST /_note` and `/_decision` are refused by the page's policy now, and 127.0.0.1 is reachable by navigation (a GET), by preconnect and by TURN over TCP alone (the review below).

### 0.20.0 review, 2026-11-25 — the previous version, sealed

E6 opened an artifact's `.versions/<slug>/v<N-1>.html` from `file://`, with no policy and no sandbox, so the script of a version nobody looks at ran during `dk check` and reached every loopback service. Its bytes are now shown as the server would send the page: `Fetch.fulfillRequest` answers a static content URL of the server's origin with the page's policy (no approved host: a check loads none) and the client first. The tab sits in a browser context of its own whose proxy is the dead one, with `<-loopback>` in the bypass list, and which may save no file (a mutant without that last call survives: Chrome 158 saves nothing from such a context anyway).

Measured in Chrome 158.0.8127.36, one run each, a raw listener on 127.0.0.1 beside a page that tries a POST, a beacon, a WebSocket, an EventSource, an image, a form, a frame, a prefetch, a preconnect, a worker's fetch, TURN over TCP and a navigation. From `file://`: 8 HTTP requests, the navigation's GET and the TURN bytes. Under the policy alone: the navigation's GET, the TURN bytes and 3 empty connections (2 with no navigation), as a preconnect makes. Policy and sealed context: no connection. So a page under check, which has the policy alone, reaches loopback by navigation, preconnect and TURN. Misses: an artifact three folders deep or more loads no file of its own folder in its previous version. Red: `FAIL: a previous version reached a service of this machine: b'POST /post HTTP/1.1' …`, and `FAIL: a version drawn by its script, under the page's policy, should look like the next one`.

`find_browser`, `start_server` and `exit_on_signals` are the one copy for this script, note-shot.py and the harnesses' browser_lib.py; results.json is written through `isolate.replace_file`.

### 0.16.0, 2026-11-13 — why the DevTools pipe, and what the runner adds

**Not the CLI screenshot.** The design was to launch the browser per width as `dk notes --shot` does. Measured on Chrome 157 (`--headless=new`, 2026-11-13): `--window-size=375,812` gave `innerWidth` 500 and `innerHeight` 725, while the PNG came out 375×812; `750,1624` with a device scale factor of 2 gave 750; `--screen-info` changed nothing. New headless clamps a window to 500 px wide, so a 375 px check would have measured a 500 px layout and drawn a 375 px picture of it. (`dk snapshot --device mobile`, which asks for 390 px on that path, lays out at 500 px for the same reason; not changed here.) The runner therefore drives one browser over `--remote-debugging-pipe` with `Emulation.setDeviceMetricsOverride`, python3 stdlib only, the way `snapshot.sh`'s signed-in path already does, so no requirement is added. Three widths of a plain page took 0.6 to 0.8 s.

**Guards.** The browser is the one `board-export.sh --which` finds; its sandbox stays on unless the user is root or sets `DESIGN_KIT_BROWSER_NO_SANDBOX=1` (the `--shot` rule); a throwaway profile; `--proxy-server=http://127.0.0.1:9` and `--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1`, so every request but loopback fails and nothing leaves the machine (an IP literal included, measured). The run stops at 60 s, a page's load event at 10 s, the check at 15 s, and `check.js` must appear within 5 s of `load`. A page that hangs, or never runs the check, does the same at every width, so the first such width is one finding (`E1.no-report`) or a `not checked:` line and the rest are skipped: an infinite loop took 45.3 s across three widths before, 10.5 s after; a page with no `</body>` 39.4 s before (it got no check at all), 0.6 s after the server learned to append the tag. SIGTERM, SIGINT and SIGHUP raise, so the browser is closed and its profile removed on the way out; a browser that ignores `Browser.close` for 10 s is killed by process group. The harness asserts no browser with a `dk-check-` profile is left.

**E1 from the browser.** `Runtime.exceptionThrown`, `Runtime.consoleAPICalled` (error, assert), `Log.entryAdded` errors other than network and JavaScript (those duplicate the two above and the network events; this keeps CSP and mixed-content errors), `Network.responseReceived` at 400 and over, and `Network.loadingFailed`: a URL off this origin is `E1.external`, anything else `E1.resource`. Enabled before navigation, so an error in the first inline script is caught, which the in-page capture `note.js` uses cannot do. `/favicon.ico`, the check's own routes and cancelled requests are ignored. Red, in a scratch copy with this collection returning nothing: `FAIL: e1-image: wanted exit 1 and [E1.resource 375,768,1280], got exit 0 and []`, and the same for `e1-console`, `e1-exception` and `e1-external`. An image at an IP literal (`http://93.184.216.34/`) and one at a name both came back `E1.external` under these flags (2026-11-13).

**Merging and output.** Findings from every width are merged on (check, selector, text); a merged finding keeps the first width's detail and lists every width in `widths`. Each is printed through `serve.show`, the escaping `dk notes` uses: the harness posts an ESC, a U+202E and a newline through `console.error` and asserts one escaped line. The posted rows are taken out of `.checks/inbox.jsonl` under its lock; rows of other runs younger than an hour stay.

**E6, best effort.** Built: the widest width (on a board, each artboard) is compared with the previous shot of the same page, `dk review`'s comparison (the union canvas filled white, a pixel changed when a channel moves by more than 10), giving the share and the bounding box with Pillow, and "changed" or "same pixels" without it. The previous shot is the last check's when the file's sha256 changed since (the current shots move to `prev-*.png`); "byte-identical to the last check's" when it did not; for an artifact never checked before, its previous bundled version, `.versions/<slug>/v<N-1>.html`, rendered from `file://` at the same size; else "nothing to compare". Decks and boards keep no versions, so they compare with the last check only. Misses: a deck's later slides; anything below 6000 px; an animation still running at the shot reads as change.

**Board twins.** When two artboards of the same size render to identical pixels (Pillow) or identical PNG bytes, the second is `E4.identical`. Cheap, since the shots exist; it does not catch two artboards that differ only in a word.

**Real run, 2026-11-13.** An artifact page in the shell (blockers, build, rollout cards, a burn-down image, a footnote) bundled with `dk bundle`, with four defects: an image file that does not exist, a 71-character sha256 checksum in a `<code>`, lorem ipsum in one card, a footnote in `#a9a7a0`. `dk check` found exactly those, in 0.69 s wall: `E1.resource` (HTTP 404) at all widths, `E2.overflow` at 375 and 768 (the grid's two columns are too narrow for the checksum at 768 too), `E3.color-contrast` at 2.32:1, `E4.lorem`. A first pass of that page used a hyphenated file path instead of the checksum, and it wrapped at the hyphens, so no overflow was reported, correctly; the same pass flagged the shell's own `.pill.warn` at 4.1:1, which is why the shell's `--warn` changed. The fix moved the checksum into a `<pre>`, and the second run caught what that broke: `E3.scrollable-region-focusable`, a sideways-scrolling block no keyboard can reach. With the checksum wrapping instead, the third run was clean (exit 0, 0.71 s) and E6 said 4.12% of pixels changed inside x 88–1192, y 182–743 at 1280 px. The 375 px PNG of the first run shows the checksum running off the Build card's right edge, the broken-image icon with its alt text, the pale footnote and the lorem card. Repeated on the final code with the wrapping fix straight away: the same four findings in 0.73 s, then clean in 0.71 s, E6 4.57%.

### 0.16.0, 2026-11-13 — review fixes: an isolated world, JSON-only output, one deadline

A review of the uncommitted M3 tree listed defects; each was reproduced first, then fixed, the harness case red before and green after (red runs: the new `check.test.sh` against a copy of the unfixed tree with `fail` made non-fatal).

**The check moved out of the page's reach (M9, H2, M1, M10).** check.js was imported into the page itself and posted to `POST /_check`; a page script could preset `window.__designKitCheck` so check.js never ran, post its own findings with the run id from its URL, and render-check.py took the last inbox row for that id. Red: a fixture doing both printed `FAIL: forged: wanted exit 1 and [E4.lorem 375,768,1280], got exit 1 and [Trust-this-page 375,768,1280]`; a preset `Promise.resolve(1)` and a replaced `Math.max` each ended in a traceback and exit 1, which dk.sh logs as ok. Now, after `load`, the runner calls `Page.createIsolatedWorld` on the page's frame, evaluates `vendor/axe-core/axe.min.js` and then check.js there, and takes check.js's completion value over DevTools; `HEIGHT_JS` runs in that world too. Measured on Chrome 157 before building it: a page's prototype override of `getBoundingClientRect` and its globals are invisible in the isolated world, DOM `error` events of failed elements reach a listener there, and console calls and script errors do not (they come from `Runtime.*` events, as E1 already did). `take()` keeps only named fields of a dict answer and ids matching `E[1-4](\.[a-z][a-z0-9-]*)?`; anything else is "not checked". No route serves the check or takes findings any more, so a server from before 0.16.0 checks as well: red `FAIL: clean: wanted exit 0 and [], got exit 4` ("the check script never ran (… Content-Security-Policy …)") against a stand-in old server. `main()` is wrapped: an unexpected exception exits 4 naming only its type, never 1 and never page text.

**Every printed line is one JSON object (H2).** The `skipped:` lines carried page-posted strings and the `summary:` line the page's path and the prefix of any posted id, as prose under the tool's voice. Notes are now `{"note", "at", "text"}` (`change`, `not checked`, `skipped`, `dropped`, `capped`, `shot`) and the summary `{"summary": {...}}`, all through `serve.show`. Red: `FAIL: a line dk check printed is not one JSON object`.

**Bounds on what the page names (M2, M3, L4).** Board metas: ids of 1 to 3 digits (a 300-digit one is ignored), widths clamped to 240-3840 and heights to 100-6000, and `open()` inside the per-job try. Red: `FAIL: a board with a huge width and a 300-digit id: want exit 0, artboard-1 only, got 4` with the sandbox hint. The previous-version slug must be one plain name (`[A-Za-z0-9][A-Za-z0-9._-]*`) and the file's realpath must sit under the page's `.versions/`: red `FAIL: a version slug climbing out of .versions/ was followed`. Artboards past the eighth and slides past the sixtieth are a note, not silence (red, both).

**The browser (M4, M5, M6, M7, L1, L3, L11, L13).** The first command is `Browser.setDownloadBehavior {deny}`: red `FAIL: a page-started download was saved: …/home/Downloads/dk-planted.txt` (HOME pointed at the harness's temp dir). A `Page.javascriptDialogOpening` is accepted in `read()` (`call()` now matches its own id, since the answer to the dialog is sent from inside a read): red `FAIL: m6-alert: wanted exit 0 and [], got exit 1 and [E1.no-report 375]` after 10 s. Only the events E1 reads are kept, at most 400 per page with the rest counted, request URLs in a separate map, a closed page's events dropped; browser findings stop at 10 per id, text 200 and detail 300 characters, the rest a `dropped` note: red `FAIL: a console flood: 300 lines, longest 4127, dropped []`. One absolute deadline goes into every read (close calls excepted): timed by hand on a page that spends 9 s before `load` and 14 s after, 69.9 s before, 60.1 s after with "not checked: the 60 s limit ran out" for the last width; `CHECK_S` now covers world, axe and check together (a separate 10 s on `createIsolatedWorld` read a busy page as a failed browser). The profile goes when `Popen` raises: red `FAIL: a browser that cannot start: want exit 4 and no profile left`. The sandbox hint is printed only when the browser never answered a command, worded as a question for the user; red on both fake browsers. Turning the sandbox off is said on stderr: red. WebRTC: `--force-webrtc-ip-handling-policy` had no effect on Chrome 157 (4 STUN packets reached a loopback listener with it), `--webrtc-ip-handling-policy=disable_non_proxied_udp` stopped them (0); red `FAIL: WebRTC: 1 UDP packet(s) reached a STUN address the page named`.

**Results (L2, L9).** The stored mtime is the one `fstat` gives with the bytes read: red `FAIL: a page edited during its check reads as unchanged`. Shots folders and `results.json` entries of pages no longer under the docroot are removed at each run: red `FAIL: a deleted page's shots or result were kept`. A symlinked `.checks` exits 4, nothing written (was a traceback, exit 1).

**The artifact shell in dark mode (N1).** Measured: ok, warn and bad on `#151514` / `#1f1f1d` were 3.44/3.10, 3.29/2.97 and 2.80/2.53:1. Dark values `#5fc48f`, `#e0a43c`, `#f2847c` give 8.51/7.69, 8.31/7.50 and 7.28/6.58. The harness builds a page from the shell with its dark block forced on and runs `dk check`: red `FAIL: n1-dark: wanted exit 0 and [], got exit 1 and [E3.color-contrast 375`.

**What a hostile page can still do.** Its script runs while it is measured: change the DOM it is measured on, detect a headless browser, keep the main thread busy (a width reads not checked), log errors, open dialogs, and reach any loopback service, `POST /_note` and `/_decision` of this server included. It can no longer read, replace or answer for the check, nor write a result.

## plugins/design-kit/scripts/preview.sh

### Header, moved 2026-11-25 (0.20.0)

Moved verbatim from lines 2-4, with only each comment's `# ` leader removed, when the header was cut again; `--help` still prints lines 2-4.

```text
preview.sh [--lan|--stop] [--port N] [--docroot DIR] — starts serve.py on DIR (default ./.cc-artifacts/design-kit) at 127.0.0.1 once, writing DIR/.preview.{pid,url,bind,port,ver}; a second start reuses it, on whatever port it runs, but first restarts one on its own port and bind when DIR/.preview.ver ("<pid> <serve.py's SERVER_VERSION>") is missing, names another pid or is lower (exit 4 when it does not stop); a higher one is kept as it is. --stop ends it, only when the recorded pid is serve.py on DIR, and deletes those files but .port, and DIR/.preview.key. Port: --port or a non-empty DESIGN_KIT_PORT, or exit 4; else the first of DIR/.preview.port's (1024-65535), 8124, 8125 to DESIGN_KIT_PORT_LAST (8139) whose serve.py is alive after 0.3 s, never 8123 (taskmaster's), or exit 4.
--lan binds 0.0.0.0 (restarting a loopback server) and prints the URL with the ?key= another device needs; a plain start over a LAN server says LAN mode is still on. serve.py ends itself (DESIGN_KIT_LAN_MINUTES, DESIGN_KIT_IDLE_MINUTES) and removes the pid, url, bind and ver files that still name it. Exit 6: the recorded pid is alive and neither ps nor /proc names it; nothing signalled or removed.
Misses: serve.py's own output is discarded, so a start that fails for another reason reads as a busy port, and a serve.py slower than 0.3 s to its bind as started; the LAN host is a guess (en0, else hostname -I's first); two starts at once are not locked (taskmaster's launcher is), so both may run, the first unrecorded. Harness: scripts/__tests__/preview.test.sh.
```

### 0.20.0, 2026-11-24 — a free port, and a server of its own version

A second project could not start a server on the fixed port 8124: page written, no URL, exit 4 (D3 of the scan of 2026-11-23). The order is now the port this project last had, 8124, then 8125 to 8139. A server left running across a plugin update kept serving pages with no isolation, so `.preview.ver` records `<pid> <SERVER_VERSION>`, counts only when its pid equals `.preview.pid`, and a missing, unmatched or lower one restarts the server on its own port and bind; a higher one is kept (another session of a newer plugin). Saved knobs and page data belong to the address, so a start on another port says so. Nine digits of the recorded version are read: `[` fails on a number past the shell's integers, which would read as not lower. Open: two starts at once are not locked; with no port set, any other start failure tries all 16 ports and then says no free port. (A `serve.py` slower than 0.3 s to its bind read as started until the review below.)

### 0.20.0 review, 2026-11-25 — proof that the port is bound

Alive 0.3 s after the start counted as bound. With a python3 that started 0.6 s late and a port another project held, the second project printed and recorded the first one's URL, exit 0, while its own server was dead (reproduced by the review). `.preview.ver` was written only after that wait, so a second `dk` verb in it took the server for an old one, killed it, and the first launcher moved to the next port.

- **The proof is the server's own line.** `serve.py` prints where it listens once it is bound; the launcher reads that for up to 10 s from a temp file with no name, since the line holds the LAN key. A server that ends first is a taken port, and the next candidate is tried; one that says nothing in 10 s is ended, exit 4.
- **`.preview.ver` before the bind** reads `<pid> <version> starting <launcher's pid>`, moved into place so that no reader meets an empty one. It is no version record yet; another launch waits (at most 15 s) while that launcher lives, and then uses its server.
- **Open:** a launch that looks before the other has written that record starts a server of its own, and the first one goes unrecorded.

### Header, moved 2026-11-12 (0.14.0)

Moved verbatim from lines 2-17, with only each comment's `# ` leader removed, when the LAN key and the idle limit were added and the header was cut to three lines and a pointer. `--help` prints the new lines 2-4. Two sentences no longer hold: `--stop` now also deletes `.preview.key`, and the LAN URL it prints carries `?key=`.

```text
preview.sh — launcher for serve.py, design-kit's own preview server.

WHAT IT DOES. Starts serve.py (gallery at /, SSE live reload at /_events,
/_index.json listing) on <docroot> (default ./.design-kit) at 127.0.0.1:<port>
(default 8124 — 8123 is the taskmaster/ui-ux mockup server, reserved), records
the PID in <docroot>/.preview.pid and the URL in <docroot>/.preview.url (dk.sh
reads it — no script assembles a URL from a literal port), prints the URL.
`--stop` kills that PID. `--lan` binds 0.0.0.0 so a phone on the same network can
open it — that is the only path here that lets a page leave the machine, and the
command using it says so first; a pick made on that phone is not recorded (the
decision route is loopback-only). The bind is recorded in <docroot>/.preview.bind:
`--lan` restarts a loopback server, a plain start reuses a LAN one and says it is
still open to the network, and serve.py ends a LAN server after
DESIGN_KIT_LAN_MINUTES (default 60). Standing: scripts/__tests__/preview.test.sh
drives start, idempotent restart, a served body, the URL file, and stop; nothing
proves a browser rendered.
```

### 2026-11-12, review of 0.14.0 — the recorded pid must be this server

`--stop` and the `--lan` restart signalled the recorded pid after `kill -0` only, and since the idle exit a stale pid file is routine. `ours()` now follows taskmaster's launcher: `ps -ww -p <pid> -o args=`, else `/proc/<pid>/cmdline`, must show `serve.py --docroot <dir> --port`, where `<dir>` is the absolute docroot this launcher now passes or the docroot as given, which a server started by the previous launcher shows. Not ours: left running, its state removed, a fresh server started. Alive and named by neither: exit 6, nothing signalled, state kept. Red: `FAIL: --stop killed a recorded pid that is not serve.py`; then, with a `ps`-only `ours()`, `FAIL: with no usable ps a live server was not recognised: preview.sh: server did not start (port 21450 busy?)`. That run left its server running with its pid file deleted, the defect itself; it was killed by pid. The unnamed case uses a zombie (alive to `kill -0`, empty `/proc/<pid>/cmdline`) under a `ps` that exits 1. Not done: no lock, unlike taskmaster's launcher, so two starts at once can both launch and one fail on the port.

## plugins/design-kit/scripts/artifact-bundle.py

Moved verbatim on 2026-10-28: the module docstring (quotes removed; `--help` prints argparse's own description), `dk_dir`'s docstring and two section banners.

### 0.20.0, 2026-11-24 — index pages and sources

The default slug was the file's base name, so every `index.html` became the artifact `index` and two pages shared one history (D2 of the scan of 2026-11-23). An input named `index.html` or `index.htm` now takes its folder's name. The ledger gains `source`, the input's real path: another source for a slug is written and warned about, naming `--name`; a ledger with none (from 0.19.3) adopts the next one silently; a moved project reads as another source. An `artifacts/index.html` left by an earlier bundle is kept and named. `dk bundle` reads `unresolved_links` (it read `unresolved`, so the lines the skill asks to fix never printed: D1).

### Module docstring

```text
artifact-bundle.py — make ONE self-contained HTML artifact, versioned.

    artifact-bundle.py <page.html | page.md | dir> [--name slug]
                       [--out-dir .design-kit/artifacts] [--shell page-shell.html]
                       [--zip] [--json]

WHAT IT DOES (each a gate the harness drives):
  - inlines every LOCAL <link rel=stylesheet>, <script src>, <img src>, <source src>,
    <video/audio src>, and CSS url(...) target (images, fonts) as text or a data URI,
    resolved relative to the file that referenced it;
  - leaves absolute http(s) references in place and REPORTS each one as `network:` —
    an artifact that needs the network says so instead of pretending;
  - reports every relative <a href> to another file as `unresolved-link:` (a single
    page has nothing beside it; use in-page anchors);
  - refuses input that is not strict UTF-8, naming byte offset, line and column;
  - stamps <meta name="design-kit-artifact" content="<slug> v<N> <ISO date>">;
  - writes <out-dir>/<slug>.html, keeps every prior version at
    <out-dir>/.versions/<slug>/v<N>.html, and appends to <out-dir>/<slug>.versions.json;
  - warns (exit 0) when the result is over 16 MiB; `--zip` also writes <slug>.zip.
  A `.md` input is rendered through the shell with a small stdlib converter:
  ATX headings, paragraphs, one-level `-`/`1.` lists, blockquotes, `---` rules,
  fenced code, pipe tables, links, images, inline code, **bold**, *italic*. NOT
  supported: nested lists, reference-style links, footnotes, setext headings,
  task lists; raw HTML passes through untouched.

WHAT IT DOES NOT DO. It does not execute scripts, so a page that loads assets
from JavaScript at runtime keeps those references and they are not reported.
`srcset` attributes are reported as unsupported, not rewritten. A `../` or absolute
local ref that resolves outside the input's directory tree is never read: it is left
in the page as-is and reported as a warning, so nothing outside the tree is inlined.
```

### dk_dir

```text
$DESIGN_KIT_DIR (dk.sh exports it, anchored at the project root), else .design-kit
at the git root — never under a subdirectory the shell had cd'd into, which scattered
a second .design-kit/ (finding 2 of the marketplace's
rationale/2026-09-25-session-plugin-usage-review.md).
```

### Section banners

```text
--- minimal markdown -------------------------------------------------------
--- versioning ---------------------------------------------------------------
```

## plugins/design-kit/scripts/board-build.py

Moved verbatim on 2026-10-28: the module docstring (quotes removed; `--help` prints argparse's own description) and the history in `_color_to_hsl`'s and `dk_dir`'s docstrings.

### 0.20.0 review, 2026-11-25 — a board outside boards/

The viewer takes a pick from a page under `boards/` alone (decision 11 of the spec), so a board built with `--out` elsewhere opened, let the user pick, and sent nothing without a word. The builder warns on stderr and still builds. Both paths are resolved before they are compared. Red: `FAIL: a board written to b8.html should warn that its picks cannot be sent`.

### Two to six artboards (2026-11-15, design-kit 0.18.0)

The gate was "fewer than 2 or more than 4 artboards", as the docstring below records. It is now 2 to 6, in commit `cc8e4365`, so that this board and taskmaster's mockup page state one count rule: 3 by default, up to 5, never more than 6. Before the change the two disagreed (2 to 4 here, 3 there) with no stated reason for either. The reasoning and its sources are in `rationale/derivations/plugin-taskmaster.md` under `plugins/taskmaster/skills/visual-decisions/SKILL.md § count rule`; the numbers are a judgment that matches what other tools ship, not a measured optimum.

What the gate catches: a spec with 1 or 7 artboards (exit 2, the message names the bound and the count). What it does not: whether three was the right number for a given brief, and whether a fourth or fifth artboard is really a different direction; both are agent-graded. The harness cases "six artboards build" and "seven artboards refused" fail on the builder before the change (exit 1, `a board holds 2–4 artboards; spec has 6`). The canvas is a flex row on a pan and zoom surface, so a six-artboard board needed no layout change; no other design-kit script was found to assume four.

### Module docstring

```text
board-build.py — render a design board (2–4 artboards on one canvas) from a spec.

WHAT IT DOES. Reads a JSON or markdown spec (shape: skills/design/references/
spec-format.md), fills skills/design/assets/board-shell.html, writes
.design-kit/boards/YYYY-MM-DD-<slug>.html and prints the path. Theme defaults come
from --tokens (default design-system/tokens.json when it exists): a DTCG file is
walked for an accent colour, a base spacing, a corner radius and a body font
family, each by path-name heuristic, each falling back to the shell's neutral
default when absent; the accent is read from hex, rgb(), hsl() or oklch(), and a token
file that maps no accent says so on stderr. Standing: scripts/__tests__/board-build.test.sh.

WHAT IT GATES (exit 2). Fewer than 2 or more than 4 artboards; an empty body;
"lorem ipsum" anywhere in a body; any external reference in a body (`http(s)://`
in src/href/url()/@import, a <link>, a <script src>) — the board must render with
the network off. WHAT IT DOES NOT CATCH: content that is realistic-looking but
wrong, an artboard that is a palette swap of its neighbour (the skill's rule,
agent-graded), and accessibility of the bodies (the shell's primitives carry the
floor; a hand-written body can undo it).
```

### _color_to_hsl

```text
(h, s, l) from a 6-digit hex, rgb(), hsl() or oklch() — the shapes system-extract.py
passes through from a stylesheet. Until 0.10.0 only hex was read, so a Tailwind v4
@theme in oklch drew the board in the default blue without a word. Residual: oklab(),
lab(), lch(), color() and a `{color.x}` alias read as no colour.
```

### dk_dir

```text
$DESIGN_KIT_DIR (dk.sh exports it, anchored at the project root), else .design-kit
at the git root — never under a subdirectory the shell had cd'd into, which scattered
a second .design-kit/ (finding 2 of the marketplace's
rationale/2026-09-25-session-plugin-usage-review.md).
```

## plugins/design-kit/scripts/deck-build.py

Moved verbatim on 2026-10-28: the module docstring (quotes removed; `--help` prints argparse's own description) and the history in `dk_dir`'s docstring.

### Module docstring

```text
deck-build.py — outline markdown → one self-contained HTML deck.

WHAT IT DOES. Reads an outline (grammar: skills/slides/references/outline-format.md),
renders every slide into skills/slides/assets/deck-shell.html, inlines local images
as data URIs, applies theme tokens from design-system/tokens.json or
design-system/DESIGN-SYSTEM.md when either exists, and writes
.design-kit/decks/YYYY-MM-DD-<slug>.html (or --out) — .design-kit/ at the git root,
or $DESIGN_KIT_DIR when set. Stdlib only.

WHAT IT CHECKS (exit 2 on any): a deck title (`# `) exists; at least one slide;
no slide body over --max-lines (default 6) visible lines — the rule the model
breaks most, so the script holds it rather than the prose; the output contains
no external `src=`/`href=` (self-containment is what makes the PDF and the LAN
path work). `--allow-long` downgrades the line rule to a warning.

WHAT IT DOES NOT CHECK. Whether the headline states a claim, whether numbers
belong in a figure — those stay agent-graded in the skill.
```

### dk_dir

```text
$DESIGN_KIT_DIR (dk.sh exports it, anchored at the project root), else .design-kit
at the git root — never under a subdirectory the shell had cd'd into, which scattered
a second .design-kit/ (finding 2 of the marketplace's
rationale/2026-09-25-session-plugin-usage-review.md).
```

## plugins/design-kit/scripts/scaffold-fill.py

Moved verbatim on 2026-10-28: the module docstring (quotes removed; `--help` prints argparse's own description) and the measurements in `required_fill`'s and `laravel_wrapper`'s docstrings.

### Module docstring

```text
scaffold-fill.py — write a scratch page body from the extracted component inventory.

WHAT IT DOES. Given the detected stack, a slug and design-system/components.json
(written by system-extract.py), prints the full scratch source file to stdout:
  - the ownership marker on line 1 (codebase-scaffold.sh's contract with cleanup);
  - one import per component — a relative path from the scratch directory to the
    component's source, or the alias from tsconfig.json/jsconfig.json `paths`
    (`@/components/Button`) when one covers it; Nuxt uses `~/`;
  - a comment block per component carrying its prop signature verbatim from
    components.json (name, type, default, required);
  - a `<section data-design-kit="strip">` rendering every component × every
    union-typed variant value, children text from --brief (or the component name),
    so the page opens with the real library in every real variant before the
    model composes anything;
  - for every `gaps` entry, a comment naming the file to open before using that
    component — the extractor's blind spot made visible, never guessed around.
Stacks: vite-react (tsx/jsx), next (page.tsx), vite-vue and nuxt (SFC with
<script setup>), laravel (Blade <x-…> tags derived from the view path),
laravel-inertia-react and -vue (an Inertia page that names a bare layout of its own:
a page-level layout outranks createInertiaApp's default `layout`, which in the stock
starter kits wraps every unnamed page in the signed-in AppLayout; React takes it in
an array because Inertia 3 reads a bare arrow there as a layout callback).

WHAT IT DOES NOT DO. It does not compile or type-check the imports — the dev
server's overlay is the check; it does not pass a required prop it cannot fill
(those lines are emitted commented out, naming the prop — a bare render of a
component missing `rows` threw and blanked the page in the simulation), and it does not
resolve barrel re-exports (a component exported only from an index file is
imported from its own source path). Without components.json the caller keeps the
plain template; this script is never on that path.
Standing: scripts/__tests__/codebase.test.sh drives the vite-react path with and
without an alias and the gap comment; the other stacks are exercised for shape only.
```

### required_fill

```text
(attrs, unfillable) for the required props not already set — the strip
renders every component it can without a runtime throw, and comments out the
ones it cannot fake rather than rendering them bare (measured 2026-09-22: a
DataTable with `rows` undefined threw and blanked the whole page).
```

### laravel_wrapper

```text
(open lines, close lines, note): `<x-app-layout>` only when the project defines
it (Breeze/Jetstream: app/View/Components/AppLayout.php or an anonymous
components/app-layout.blade.php); otherwise a standalone page carrying the first
`@vite([...])` directive found in the project's layouts, so the real stylesheet
loads; otherwise a bare page. Measured 2026-09-22: a fixture with only
resources/views/layouts/app.blade.php has no <x-app-layout> and the scratch page
would have thrown "Unable to locate a class or view for component [app-layout]".
```

## plugins/design-kit/scripts/system-extract.py

Moved verbatim on 2026-10-28: the module docstring (quotes removed; `--help` prints argparse's own description and usage) and one `#` block.

### Module docstring

```text
system-extract.py — extract a design system from a repo, a live URL, or a brand
asset directory into design-system/: tokens.json (DTCG-shaped), DESIGN-SYSTEM.md
(the plain `## Design system` block plus a component inventory) and kit.html (a
UI-kit page whose every card carries an `@dsCard` marker).

WHAT IT CATCHES. Every token it emits points back to a source line; nothing is
invented. A value that is not in the source does not appear, which is the rule
the model gets wrong from memory — it "remembers" a palette the repo never had.
Deterministic: same input, byte-identical output, so a diff of design-system/
after a re-run is a real change in the source.

WHAT IT DOES NOT CATCH. Repo mode reads text with regexes — no JS evaluation, so
a Tailwind config built from imports or functions yields only its literal
entries. URL mode fetches HTML and linked stylesheets without running JS, so
styles injected at runtime (CSS-in-JS, Tailwind CDN builds) are invisible; it says
so in the output. Naming (which of two primaries is THE primary) is the
reader's judgment, flagged, never decided here. Component "approximations" in
kit.html are static HTML carrying the real component's name, path and props —
they are not the component.

Standing: scripts/__tests__/system-extract.test.sh drives the three sources on
fixtures and asserts the output shape; the determinism claim is asserted by
running twice and comparing bytes.

Usage:
  system-extract.py <repo-dir | https://url | brand-dir> [--source repo|url|brand]
                    [--out design-system] [--kit-shell path] [--project-name X]
                    [--dry-run]
```

### Rendered source

Added 2026-11-09 (design-kit 0.13.0). `--source rendered` runs `system-render.mjs` with `node` and
takes its tokens as found: each keeps its value as the light mode, its element sources and its
`uses`. Its exit codes pass through (3 a missing Playwright or Chromium, 4 a page that did not
load), so `dk system` fails with the missing piece named instead of writing an empty record. A
`typography.size` token is a dimension: the kit renders it as a size specimen and the markdown as a
`Type sizes:` line, never as a typeface card.

Two review fixes before release (2026-11-09). A rendered run reads no stylesheet, motion, shadow or
component, yet `## Not found` listed "a dark mode (no … `prefers-color-scheme: dark` block …)" on
any page, including one that has a dark mode, and the system skill forbids deriving one. The
extraction now records the sections its mode never reads (`ex.unread`), and the markdown lists
them under `## Not read` and the kit's empty slots say "Not read (rendered mode)". And each token
now carries system-render's `roles` and `merged`, the only role hint a computed colour has.

### Blade class components

```text
A Blade view without @props may be the template of a class component
(app/View/Components/<Name>.php) whose promoted constructor parameters ARE
the props — Laravel's own convention; the Blade-first walk hid it (measured
2026-09-22 on a fixture: Alert.php's type/message/dismissible read as "no props").
```

## plugins/design-kit/scripts/deck-export-pptx.mjs

Moved verbatim on 2026-10-28, with only each line's `// ` leader removed; the script has no `--help`.

### Header

```text
deck-export-pptx.mjs <deck.html> <out.pptx>

WHAT IT DOES. Reads the native content of a design-kit deck — every
<section class="slide"> with its data-title, data-notes, headings, list items,
paragraphs, code blocks, big figures and data-URI images — and writes a PPTX
with real text boxes and pictures via pptxgenjs, so the deck is editable in
PowerPoint/Keynote/Google Slides. Not a screenshot exporter.

WHAT IT DOES NOT DO. Fragments, transitions, nested-list indentation beyond one
level and CSS theme colours are not carried; the theme's accent is read from
--dk-accent when present, everything else is PowerPoint defaults. Driven by
deck-export.sh, which owns the pptxgenjs install consent.
```

## plugins/design-kit/scripts/chromium.mjs

Written 2026-11-09 for design-kit 0.13.0 (roadmap 2026-11-07, Track 5 D6). Standing: `recorded`.

### Why one launcher

`motion-check.mjs` and `system-render.mjs` both drive Playwright, and the design track's rule is that
browser work runs on what the project already has: its own `playwright`, `playwright-core` or
`@playwright/test` (resolved from the project's `package.json` with `createRequire`, so Node's
`NODE_PATH` counts too), never an install. One module keeps the resolution order and the "installs
nothing" message in one place, the way `board-export.sh --which` does for the shell scripts.

### Launch order

An explicit `--browser` / `DESIGN_KIT_BROWSER` (the variable `board-export.sh` already reads), then
Playwright's own Chromium, then `channel: 'chrome'`. Measured 2026-11-09 on the author's machine: the
only Playwright on disk (1.65.0-alpha in the npx cache) wanted `chromium_headless_shell-1252` while
the cache held 1234 and 1248, so its own launch failed with "Executable doesn't exist"; the installed
Google Chrome 156 launched through `channel: 'chrome'`. Without the third step the scripts would have
reported a missing browser on a machine that has one. Every failed step's first error line is
printed with the exit 3, so "missing" is never a guess.

## plugins/design-kit/scripts/motion-check.mjs

Written 2026-11-09 for design-kit 0.13.0 (roadmap D6, dk5). Standing: `recorded`.

### Why it exists

`/design-kit:motion` told the model to write the recorder per project from the snippet in
`references/capture-export.md`; each project got its own copy and none of the skill's motion rules
was checked by anything. The script is that snippet generalised (fake clock, whole-millisecond
steps, `__start` inside the same evaluate as the seek, every animation paused and seeked from the
mark it was created under) plus the checks.

### The rules and their numbers

Taken from `skills/motion/SKILL.md` Part B and `references/motion-system.md`: the cheap set is
transform, opacity, filter and clip-path ("Cheap properties only"); a layout property is a fail and
any other property a warning, because the roadmap item asked for "no layout-shifting properties"
and a colour tween does not re-lay out the page. The duration band 500–1100 ms is the Values table's
span: the 0.5 s dissolve is the shortest CSS motion it names, the 1.1 s slow wipe the longest;
stories, typing and accents run on the JS clock, so a longer CSS animation is either a loop the
capture seek restarts or a value the table does not have. 16 ms or less is exempt so a reset class
and the common `0.01ms !important` reduced-motion override do not fail. Blur 14 px is "animated blur
≤ 14 px". Reduced motion: the skill renders the still frame, so the second pass, under
`reducedMotion: 'reduce'`, fails on anything but opacity still moving.

### JS-driven motion

A `MutationObserver` on `style` attributes, installed before any page script, records each changed
inline property per element; three changes is the threshold, so a style set once at start-up is
not "animated". Durations are not checked there: an inline tween has no declared duration.

### Exit codes

0 held, 1 broke, 2 usage, 3 missing Playwright or Chromium, 4 not measured (page did not load,
recording failed, or nothing animated). Nothing animated is 4, not 0: a check that saw no motion has
not cleared any.

### Review fixes before release (2026-11-09)

Each reproduced on the ff1d37fd build and now a harness case.

- **Page-paused animations.** Every animation was paused and seeked from first sight, so
  `@media (prefers-reduced-motion: reduce) { .orb { animation-play-state: paused } }` was played
  and failed reduced-motion. A CSS animation's computed `animation-play-state` is now read each
  frame, and any animation already paused when first seen is left alone until the page plays it.
  One that never ran is not judged. Residual: a JavaScript `pause()` after the recorder took the
  animation over is indistinguishable from the recorder's own.
- **`.finished` chains.** A paused animation never resolves `finished`, so a page chaining a
  second animation on it stalled. An animation whose seek time reaches its `endTime` is now
  `finish()`ed once and left alone.
- **Inline motion** is limited to properties that move something when rewritten: layout, the
  cheap set and a list of paint properties (colours, shadows, radii, positions). A `display` or
  `z-index` swap written 3+ times had drawn paint warnings and a reduced-motion fail.
- **Names in the table.** Element ids, classes and animation names are page-controlled; they are
  reduced to `[\w#.:()-]` and capped (80, and 40 for a name) before they reach the markdown table.
- **--static times.** A shorthand with no literal time is 0s, and an item at or under 16 ms is
  now dropped, not judged: `.snap { transition: height 0s }` had failed layout-property and
  reduced-motion. A time held in `var()`/`calc()` is unknown, so its duration is `null` and one
  note counts them; a whole-`var()` transition no longer falls back to `all`.
- **--static reduce path.** It is an `@media` prelude naming `prefers-reduced-motion`, or a script
  with a `matchMedia(` call and the query, both with comments stripped; the bare words anywhere had
  counted. A branch under `not (…: reduce)` or `(…: no-preference)` is the motion branch, judged.

## plugins/design-kit/scripts/system-render.mjs

Written 2026-11-09 for design-kit 0.13.0 (roadmap D6, "the dembrandt idea"). Standing: `recorded`.

### Why it exists

`system-extract.py`'s url mode fetches HTML and stylesheets and runs no JavaScript, and says so: an
SPA or a CSS-in-JS site yields next to nothing. The rendered source reads what the browser computed
instead. The idea of extracting tokens from a rendered page's computed styles is dembrandt's, as the
roadmap names it; this was written from that one-line description, without reading its code.

### Names are values

A computed style carries no role, so the names are the values (`color.1f2937`, `spacing.16px`;
`.` in a value becomes `_` because DTCG names cannot hold a dot and `flat()` splits paths on it).
Naming one of them "primary" would be the invented token the system skill forbids; the skill sends
the naming back to the source.

### Clustering

Colours: opaque sRGB within RGB distance 8 of a more-used colour of the same alpha merge into it (the
more-used one names the cluster); alpha 0 is dropped; `oklch()` and `color(srgb …)` convert, any
other space is kept as written under a slug name. Font family: the first family of the computed
stack, generic families dropped (a system stack is not a family). Dimensions: px rounded to 0.5,
zero and negative dropped, the first value of an elliptical radius. Anything used once is dropped
(`--min-uses 2`). The same samples give byte-identical output; `--dump-samples` / `--samples` exist
so a read can be re-clustered and so the harness can test clustering with no browser.

### Review fixes before release (2026-11-09)

- **`uses` counts elements.** One `<div style="padding:13px;border:1px solid #e2e8f0;border-radius:7px">`
  produced spacing 13px, colour e2e8f0 and radius 7px at 4 uses each, past `--min-uses 2`. A
  sample now carries its element's index, and a value counts each element once; a dump without
  the index counts samples, as before.
- **Visibility** is `checkVisibility({opacityProperty, visibilityProperty})`, which also sees an
  ancestor at opacity 0; the element's own computed opacity missed a hidden wrapper's children.
- **The page background.** `html` was never sampled and `body`'s background is one sample, so
  `--min-uses 2` always dropped the base colour. `html` is sampled, `html` and `body` are sampled even at
  zero height, and their background is exempt from `--min-uses`.
- **No margins.** A computed margin is a used value: `margin: 0 auto` at 1440 px read as
  `spacing.120px`. Only padding and flex/grid gaps are read; a margin scale is not inferred.
