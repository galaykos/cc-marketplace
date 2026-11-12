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
