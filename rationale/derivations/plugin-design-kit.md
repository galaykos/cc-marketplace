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

## plugins/design-kit/scripts/note.js

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

## plugins/design-kit/scripts/preview.sh

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
