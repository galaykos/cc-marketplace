# design-kit

The Claude Desktop design picker, as five local plugin skills whose files you own. They
are **Slides, Design, Design in codebase, Design System, Artifacts**, plus two the picker
lacks, **Motion** and **Film**. Every surface is
a plain HTML file under `.cc-artifacts/design-kit/` in your project. This plugin's own preview server
serves it on one localhost URL, and scripts you can read export it. Nothing leaves the
machine unless a skill names the path and you say yes; what a page's own script can still leak is
listed under "What a page can and cannot do".

## What it does

| Desktop option | Skill | Produces |
|---|---|---|
| Slides | `/design-kit:slides` | a self-contained HTML deck with speaker notes; PDF and PPTX by script |
| Design | `/design-kit:design` | an artboard canvas of 3 directions by default (up to 5, never more than 6) with editable text, adjustment knobs, PNG/PDF export, and a pick you send back from the viewer |
| Design in codebase | `/design-kit:in-codebase` | the design rendered with the project's OWN components on its dev server, cleaned up once the pick is final; intake of a Claude Design handoff bundle with a token-drift table |
| Design System | `/design-kit:system` | `.cc-artifacts/design-kit/design-system/`: DTCG `tokens.json`, `DESIGN-SYSTEM.md` in the format the host's artifact skill reads, and a UI-kit page with `@dsCard`-marked cards |
| Artifacts | `/design-kit:artifact` | one self-contained, versioned HTML page in a local gallery; LAN, pages-branch or zip sharing on explicit consent |
| — (not in the picker) | `/design-kit:motion` | a static design — Figma frame, dashboard, card set, screenshot — rebuilt exactly and animated from empty to loaded with a story per visual, as a looping page plus an MP4 and two GIFs; or the same choreography on a site's bento and feature sections |
| — (not in the picker) | `/design-kit:film` | a product demo, launch film or explainer made from a brief: facts traced, UI captured, sound first, a blind review each round, one MP4 per format with a music-only track and a ledger |

Why a plugin when the host has `/design`, `/design-sync` and the `Artifact` tool: those
need a claude.ai-backed login, a paid plan, and Anthropic's servers, and the design
system they build lives at claude.ai/design. This plugin keeps the same five moves on
disk, in the repo, reviewable in a diff. The study that sized this is
`rationale/claude-desktop-design-parity-2026-09-22.md`; the retirement of the previous
design plugin on usage evidence (`rationale/marketplace-endgame-review-2026-09-14.md`
§6) is why the **Measured** section below exists.

## Install

```bash
claude plugin install design-kit@cc-plugins-marketplace
```

Needs `python3` (stdlib only) for every script. PDF and PNG export need a Chrome,
Chromium or Edge binary on a common path, or Playwright's chromium; PPTX export
needs Node and installs `pptxgenjs` into `.cc-artifacts/design-kit/.cache/` after asking.

## The preview server

`scripts/serve.py` (launched by `scripts/preview.sh`) serves `.cc-artifacts/design-kit/` on
`127.0.0.1`. The gallery of every deck, board, preview and artifact is at `/_gallery`, and at `/`
while that folder holds no `index.html`; `/_index.json` is the same list for scripts; a page opens
at its own path, `/artifacts/x.html`, in the viewer (next section).

**Port.** With `DESIGN_KIT_PORT` or `--port`: that port, or exit 4. With neither: this project's
last port, then 8124, then 8125 to 8139, the first that is free; none free is exit 4. A server of
this project that already runs is reused, on whatever port, and the launcher says which. Port 8123
is the taskmaster/ui-ux mockup server's and is never used here. A start on another port than the
last one prints `preview: moved from port <old>; saved knobs and page data stay on the old
address`. A running server whose own version number (`SERVER_VERSION` in `serve.py`, not the
plugin's version) is lower than the installed one's is restarted on its own port and bind; one
whose number is higher is kept. The launcher prints a URL once the server has said that it is
bound, and ends one that has not within 10 s (exit 4).

**When the server goes away** under an open page, the viewer shows "Preview server stopped;
retrying", retries after 1, 2, 4 … 30 seconds and frames the page again once the server answers; a
half-typed note stays. The gallery shows the same words in a small bar (`role="status"`, no
animation) and reloads. A headless browser and a `?static=1` URL get a gallery with no such client,
and on this machine a page with no viewer, so nothing that retries.

`--lan` binds every interface so a phone on your network can open it — that is the only way a page
leaves the machine through the server, and every skill says so before using it. A LAN server asks
every device but this machine's loopback for a key: the URL it prints carries `?key=…`, the first
visit trades it for an `HttpOnly`, `SameSite=Strict` cookie and drops it from the address bar, and
a request with neither gets 403. The one exception is a page's content URL (`/_c/…`, what its
frame loads), since the frame never carries the cookie: whoever holds that URL reads that page and
its files with no key, until the server stops. The key lives in
`.cc-artifacts/design-kit/.preview.key` (mode 0600, never served). A restart keeps it, so a
phone's link keeps working; `dk serve --stop` deletes it, so the next LAN start prints a new URL.
A phone sees the gallery, and each page under Gallery, the title and a line naming the address to
open on this computer. Picks, notes and host approvals stay loopback-only: the three write routes
refuse a phone even with the key. A LAN server ends itself after 60 minutes
(`DESIGN_KIT_LAN_MINUTES`; `0` means no limit), and while one runs every later command says LAN
mode is still on and prints its URLs with the key. `dk serve --lan` and `dk share <page> --lan` fail
with exit 4 when nothing was opened to the network, as when a server with a higher version number
keeps running on this machine's address alone.

Every server, LAN or not, exits after 4 hours with no request and no open page
(`DESIGN_KIT_IDLE_MINUTES`, default 240; `0` turns it off). An open tab counts, since its viewer,
or the gallery, holds a stream; a request refused for want of the key does not. A server that ends
itself removes its pid, URL, bind and version files, `dk status` prints no URL for a dead server,
and the next `dk` verb starts a fresh one. `--stop` and a `--lan` restart signal the recorded pid
only when it is this docroot's `serve.py` (by `ps`, else `/proc`; a live pid neither can name
stops the launcher with exit 6 and is left alone).

The server never returns a dot-prefixed file or folder (`.checks/`, `.notes/` and `.allow.json`
among them), `auth/`, its own state files (`workshop.json`, `decisions.jsonl`, `notes.jsonl`,
`usage.jsonl`, `*.versions.json`), a directory listing, or a path or link that resolves outside
the folder or to one of these. Every other file under `.cc-artifacts/design-kit/` is readable by
any program on this machine (on the LAN, by whoever holds the keyed URL), signed-in screenshots
included; not by a page (next section), and not by another website: a `Host` that is neither
`localhost` nor an IP address gets 403, and every answer outside `/_c/` carries
`Cross-Origin-Resource-Policy: same-origin`. The key does not make the LAN private: the server
speaks plain HTTP, so the key crosses your network in the clear, and it sits in a URL, so it lands
in the phone's history and anywhere you paste it. Three write routes exist, `/_decision`, `/_note`
and `/_allow` — loopback only, header-gated, from the preview's own address (see the next
sections); export and publish stay scripts.

Standing: `scripts/__tests__/serve.test.sh` and `preview.test.sh` drive start, the port choice,
the version restart, serving, the viewer's and the gallery's documents and headers, the listing,
path traversal, links, the `Host` rule and stop — **gate** (CI runs every
`plugins/*/scripts/__tests__/*.test.sh`). The key is a **gate** twice: every peer, key and cookie
case as a unit, and end to end from this machine's own network address, which the server sees as a
non-loopback peer (that half skips on a machine without one). The idle limit is a **gate**: a
3-second limit, held off by requests and by an open stream, in both modes, and not by 403s. The
never-served list is a **gate** for GET and HEAD, with origin- and absolute-form request targets.
The retry of an open viewer is a **gate** where a browser is found (`viewer.test.sh`); the
gallery's bar is one for its text only, and it, and a keyed link followed from another site, were
run once in Chrome on 2026-11-12 — **recorded**. Two starts at once are not locked: one that meets
the other's record waits for that server, one that comes before it may run beside it, the first
unrecorded. A page is rendered in a real browser and checked only when `dk check <page>` runs
(below; **gate** for its own fixtures); nothing checks a page on its own, so a page nobody ran it
on is unchecked.

### What a page can and cannot do

A page URL answers the **viewer**, a document the plugin owns: a bar (Gallery, the title, the last
check, Network, Notes), strips under it, and the page in a frame. The page's own code runs in that
frame with an origin of its own (`null`), in a sandbox, under a policy header the server sets.
Only the viewer, and only on your click or key, records a pick, a note or a host approval or opens
another site; those buttons do nothing for 600 ms after anything around them appears, moves or
changes.

From inside its frame a page cannot:

- read or change the viewer, the gallery, another page, the notes, the check results, or the
  preview address's cookies, storage and databases;
- post a pick, a note or an approval;
- send a request to another host; files loaded from a host you allowed (below) are the one
  exception;
- leave: a frame that tries is replaced with "Page stopped: it tried to open another site." and
  Reload page;
- open a tab on your plain click (in Firefox it can, see below), or go fullscreen;
- load a server file that is not its own: a page with a folder of its own, such as
  `motion/<slug>/` or `film/<slug>/`, loads the other files there (never another page), a review
  its images in `reviews/diff/` and `shots/`, any other page none.

**Own files in a canvas.** To a page with an origin of its own its files come from another one:
reading back a canvas an image or a video of its folder was drawn into, or loading one as a WebGL
texture, throws `SecurityError` unless the file was loaded through CORS. An image whose `src` a
script sets is; write `crossorigin="anonymous"` on an `<img>` in the markup, on one filled by
`srcset` or `setAttribute`, and on a `<video>`.

**Hosts.** Each of the first 10 `https` hosts a load is refused a file from draws a strip with its
name and what was asked for: Allow for this page, or Keep blocked (for this tab). An `http` address,
or one with a port, is refused with no strip; `dk check` names it. An approval covers `https`
scripts, styles, images, fonts and media from that host, for that one page, never fetch, WebSocket
or forms. It is kept in `.allow.json` across restarts, listed under Network with Remove, and granted
on this machine only. An IP address, a port, a wildcard, `localhost`, `.local`, `.internal` and
`.home.arpa` are refused.

**Storage.** A page's `localStorage` is a stand-in the viewer keeps in this browser, per project
and page, up to 256 KB of keys plus values; board state that 0.19.3 saved at the same address is
read once. `sessionStorage` lasts as long as the frame; cookies, IndexedDB and service workers are
unavailable.

**Links, address, reload.** A link to another site draws a strip with the full address: Open or
Dismiss. A link to another page here opens in the viewer, without its query. `#board=2`, `#/3` and
`?still=1` reach the page, and its hash comes back to the address bar. A save reloads the frame of
that page alone (for a page with a folder of its own, also a save of a file there); the bar, the
drawer and a half-typed note stay.

**Raw.** `?static=1` typed on this machine, or a headless browser, is sent to the page itself at
its signed address, for captures: the same policy, no viewer, no reload. Nothing then stops the
page from navigating itself to another site. `dk check` and `dk notes --shot` open it with no
network but this machine; a motion or film recording has the network open.

What can still get out, or mislead you:

- A host name the page chose can leak through preconnect, WebRTC or DNS, and through a blocked
  navigation, which opens the connection and sends no request.
- An approved host receives whatever the page writes into a request's address, and the approval
  stays when the page is rewritten.
- In a page that undid the in-frame script, your Ctrl, Shift or middle click on a link opens a
  real tab and Alt+click starts a download, one request each. Click plainly, or use the link
  strip.
- In Firefox (Playwright's build) a page that undid the in-frame script opens a real tab, its text
  in the address, on your plain click or a key you press in it (one request; Chrome opens none).
  Open a page you do not trust in Chrome.
- A page you clicked in can take the keyboard focus from the viewer, and with it what you type in
  a note. The viewer gives it back at once: of 26 characters, in Chrome, a page that tries every
  100 ms got 0 or 1, one that tries every 5 ms 0 to 3, one that never pauses 24 to 26; in that
  Firefox the first got 1 or 2, the second 21 or 22 of 26. Where the note is on the page itself,
  the pointer rests on the page or the viewer was last touched by a finger, and nothing was typed
  for 500 ms, a page gets all 26. Type a note with the pointer off the page, and none on a page you
  do not trust.
- A page can draw anything inside its own frame, a second bar included. The real bar and its
  strips are above it.
- `dk export` opens the file in a headless browser with no browser sandbox and an open network:
  export only a page whose script you trust.
- The sandbox and the policy are this server's headers, and headers do not travel: a zip, a pages
  branch and a PDF carry none of this, so a shared copy's script runs as any web page's does.
- A page opened under 0.19.3 or earlier could leave a service worker behind that fakes the viewer.
  After the update to 0.20.0, clear site data for the preview address once (knobs and page data
  saved there go with it).

The harnesses drive headless Chrome. In Playwright's Firefox build only hand runs were made; what
was run and what failed is dated in `rationale/derivations/plugin-design-kit.md` of the
marketplace repository. In that build, Tab from Notes stays on Notes: click in the page to reach
it. Safari and stock Firefox are untested, and so are screen readers, WebRTC, a link's context menu
and a real second device on the LAN.

Every threat, its disposition, its standing and what you can do about each thing left open:
`rationale/design-kit-threat-model.md` in the same repository. Standing: `isolate.test.sh`
(tokens, policies, files, hosts), `serve.test.sh` (routes and headers), `frame.test.sh`,
`viewer.test.sh` and `attack.test.sh` (a hostile page tries every way out, in and through, beside
an unguarded control that must succeed) — **gate**, the last three's browser checks only where a
Chromium-family browser is found (`DESIGN_KIT_REQUIRE_BROWSER=1` makes a missing one a failure).
What you do with a strip, and what a page shows you, is **unenforceable**.

## One entry point: dk

Every skill's MAIN path runs through `bash ${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh <verb>`,
so `Bash(bash */design-kit/scripts/dk.sh*)` is the one rule that covers ordinary use.
**It is not the only rule you will be asked for.** Three steps deliberately call a script
directly, because `dk` has no verb that does only what they need: the deck build alone
(`deck-build.py`, so a long-slide exit 2 can be fixed before anything is served), the
handoff-drift table
(`handoff-drift.py`), and the system extraction's dry run (`system-extract.py --dry-run`,
which `dk system` only ever runs as the first half of a full extraction). Those draw a
second prompt, or a second rule — `Bash(python3 */design-kit/scripts/*)` — and saying
"one permission rule" full stop was wrong.
`dk` keeps `.cc-artifacts/design-kit/workshop.json` (brief, device, theme, the last system stamp, board,
scratch, artifacts, deck) so a skill with no argument offers the natural next step, and
appends one line per verb to `.cc-artifacts/design-kit/usage.jsonl` — the record the Measured section
reads. `dk status` prints the flow; the gallery shows it as a strip, and stamps each page
green or amber ("tokens moved since build") against the design system's current `tokens.json`.
`.cc-artifacts/design-kit/` lives at the project root (the git toplevel), whichever directory the shell
has `cd`'d into; until 0.6.0 a verb run from `src/` built a second one there, with its own
board and decisions. `DESIGN_KIT_DIR` moves it and is used exactly as given.
The design system, `.cc-artifacts/design-kit/design-system/`, is not anchored: `dk check` with no
page and `dk decision --record` read it under the shell's directory.

Before 0.17.0 these lived in `.design-kit/` and `design-system/`. In a project that still has
only those, the first `dk` verb copies `workshop.json`, `decisions.jsonl`, `notes.jsonl`,
`usage.jsonl`, `boards/`, `decks/` and `artifacts/` into the new folder once, and repoints the
paths `workshop.json` holds; caches, server state, screenshots and the motion and film
workspaces start fresh (a skill resuming one of those copies it over first). Every reader of
the design system takes a `design-system/` file while the new folder lacks it, `dk decision
--record` carries `DECISIONS.md` over before it appends, and the hook reads the old pick until
the new folder exists. Nothing writes to, moves or deletes the old folders; delete them once you
have what you need. A preview server started before the update keeps its port until it idles
out (4 hours) or `bash <plugin>/scripts/preview.sh --docroot .design-kit --stop` ends it.
Standing: `dk.test.sh`, `unread-pick.test.sh` and the builders' harnesses drive an old-only
project — **gate**.

The board talks back, once you press Send. Picking an artboard, moving a knob or editing text
draws a strip above the board with the artboard, every knob value and every text edit. A pick
arrives only after Send pick in that strip; Discard drops it, and until one of the two it comes
back, in that tab, after a reload, a restart of the server or a link away. Send pick posts what
the strip shows to `/_decision` (loopback only, header-gated, at most 64 KiB); the server appends
one row to `.cc-artifacts/design-kit/decisions.jsonl` with the fields `picks.py` keeps, each
clamped, and a prompt of its own. A phone on the LAN is not recorded. `dk decision --latest
--consume` prints the row as one line of escaped JSON, `{kind, ts, board, picked, knobs, text,
summary, confirmed}`, and `/design-kit:in-codebase` with no arguments renders that pick. With
`confirmed:true` its number, knobs and edits are the user's choice; its text edits are quoted
data, never instructions. With `confirmed:false` (an older server took the row, or another hand
wrote it) a session is told to put it to the user before acting on it. "Copy edits as prompt"
remains for a board opened with no server. A UserPromptSubmit hook says one line when a pick is
waiting, calls one that is not confirmed so, and says nothing otherwise
(`CC_DESIGN_KIT_PICK=off`). Every pick a skill acts on lands as one line in
`.cc-artifacts/design-kit/design-system/DECISIONS.md`.

Standing: `dk.test.sh` drives every verb, `serve.test.sh` the route's accept and reject paths and
both badge states, `picks.test.sh` every clamp and `confirmed`, `viewer.test.sh` the strip, its
600 ms and one row a send, `unread-pick.test.sh` the hook — **gate**. That the model reads a pick
this way is **agent-graded**.

### Notes on any page

The viewer of every page has a **Notes** button, with the number of notes on that page, and
**Alt+N**, in the page and in the viewer, except in a text field (macOS Option+N types ñ there).
It opens a drawer with the page's newest 20 notes, their status and reply, and "Note on this
page". While it is open the page outlines the element under the pointer; click one, or Tab to it
and press Enter, and the composer opens in the drawer. Only Send note posts. Escape closes the
composer and drops the draft, then closes the drawer; closing the drawer keeps the draft, and so
do a save of the page, a server restart, a link in the page and an Escape pressed there. Reloading
or closing the tab loses it. On a board, while the notes are open a click picks the element it is
on for a note, never an artboard. The page itself says only which element was chosen and its
context, and only while the notes are open. A headless browser, `?static=1`, a gallery thumbnail, a
file, another server and a phone on the LAN have no notes.

A note posts to `POST /_note` (the same guards as `/_decision`, with an `X-Design-Kit-Note`
header, at most 8 KiB) and lands as one line of `.cc-artifacts/design-kit/notes.jsonl`: `{id, ts,
cid, page, kind: "note", anchor: {selector, tag, text, rect} | null, text, context: {viewport,
theme, console}, status: "open", reply: ""}`, every field clamped (text 2000 characters, selector
512, the last five console errors, 300 characters each, numbers to ±10,000,000) and every other
key dropped. A note with no text is refused (400), and so is a note or a pick whose `cid` is not 16
hex digits; a lone surrogate is stored as `?`, and once `notes.jsonl` or `decisions.jsonl` would
pass 2 MiB a post gets 507 until you move the file aside.
A send repeated after a lost answer carries the same `cid` and writes no second row while the
first is among the file's last 50. `GET /_notes?page=` returns one page's rows to the viewer,
loopback only, those filed under the folder of an index page too. `dk notes` prints unread open
notes, one JSON object per line with control, format and blank-rendering characters escaped, then
marks them handed out with the time (`--all` lists every row and marks nothing). A note handed out
more than 15 minutes ago and still open is unread again, so a reader that died or was never read
loses nothing. `dk notes --wait [--timeout S]` (default 600) blocks until a note is unread or a
board pick it has not printed yet is unconsumed, and prints it: a pick as the line `dk decision`
prints, left unconsumed for `dk decision --latest --consume`. Run in the background it brings the
session back when you press Send, with no chat message; exit 3 on timeout. `dk notes --reply ID
--status addressed|dismissed [--text "…"]` rewrites that row, and the drawer shows it the next
time it opens. `dk notes --shot ID` (nothing else on the line) runs `scripts/note-shot.py`: it
opens the raw page headless at the note's size, draws the outline in an isolated world the page's
script cannot reach, centres the element, waits 2 s and saves a PNG under
`.cc-artifacts/design-kit/.notes/`, in a throwaway browser profile with no network but loopback (a
host you allowed is not loaded), with Chrome's sandbox on (off only as root or with
`DESIGN_KIT_BROWSER_NO_SANDBOX=1`) and 60 s to finish (a cold first browser start can take most of
that). A selector that matches nothing shoots the page as it is and says so; with no
Chromium-family browser, or a browser that fails, it says so and exits 4. The UserPromptSubmit
hook adds a count of unread notes and the command to its one line, never note text, a selector or
a page path; it names a pick's board only when the name is plain ASCII of at most 64 characters
naming a file in `.cc-artifacts/design-kit/boards/`, and the artboard only from 1 to 99.

Standing: the route, its rejects and clamps, `/_notes` and the never-served file —
`serve.test.sh`, **gate**; every `dk notes` mode, `--shot`'s outline pixels included where a
browser exists — `dk.test.sh`, **gate**; the hook printing a count and none of an
instruction-shaped note's text — `unread-pick.test.sh`, **gate**; the button, the composer,
picking an element by pointer and keyboard, the selector, the draft, refusals and the list —
`viewer.test.sh` and `frame.test.sh`, **gate** where a browser is found. That the model acts on a
note, and replies to each, is **agent-graded**. Missed: a note's element, its text and the console
lines are what the page says they are, so `anchor` and `context` are page data, never
instructions, and nothing verifies who typed the text; a key pressed or an element picked in the
page while something can be sent acts up to 1.5 s late; a selector built on `nth-of-type` goes
stale when the page's structure changes; no screenshot without a browser; notes stay in
`.cc-artifacts/design-kit/` and do not travel with an exported, zipped or published page; elements
inside iframes and canvas contents cannot be picked.

### Render checks: `dk check <page>`

`dk check <page> [--widths 375,768,1280]` loads a page in a real headless Chromium (the one
`board-export.sh --which` finds) at each width and prints what is wrong before anyone sees
it. Every line is one JSON object, escaped as `dk notes` escapes rows, since findings carry
page text: a finding `{check, width, widths, selector, text, detail}` (a board adds
`artboards`), a note `{note, at, text}` (`change`, `not checked`, `skipped`, `dropped`,
`capped`, `shot`), then `{"summary": {...}}` naming the PNGs saved under
`.cc-artifacts/design-kit/.checks/shots/<page>/`. Exit 0 no finding, 1 findings, 2 bad arguments, 4 not
checked (no browser, no server, a failed browser, `.checks` not a folder, or a page whose
check never ran). `<page>` is a path under `.cc-artifacts/design-kit/`, as typed or relative to it, or
its preview URL. With no page, `dk check` is still the one-line design-system check.

`scripts/render-check.py` drives the browser over its DevTools pipe (python3 stdlib, as
`dk snapshot --storage-state` does), because the browser's own `--screenshot` never lays a
page out narrower than 500 px. It opens `/<page>?static=1` on `127.0.0.1`, which the server
sends on to the raw page under that page's own policy (no viewer around it), and, after
`load`, evaluates the vendored axe-core and `scripts/check.js` in an isolated world of the
page (DevTools `Page.createIsolatedWorld`): the page's script can neither read, replace nor
answer for them, and the findings come back over DevTools, never through the server. No
route serves the check or takes findings, so a server started before this version checks
as well. A board is checked artboard by artboard at each frame's own size (`#board=N`, from
its `design-kit-board` metas: ids of up to 3 digits, widths held to 240-3840 px, the first
8), so its fixed stage is never overflow; a deck (its `design-kit slides` generator meta)
slide by slide with every fragment shown, the first 60. The browser keeps its sandbox (off
only as root or with `DESIGN_KIT_BROWSER_NO_SANDBOX=1`, said on stderr), uses a throwaway
profile, a dead proxy that wins over any proxy in the environment, no name resolution, no
WebRTC UDP past that proxy, and refuses downloads, so a check sends nothing off the
machine; a dialog the page opens is accepted. A run stops at 60 s, every wait included; a
page that hangs is reported once and its other widths are skipped. A plain page takes under
a second for three widths.

| Check | Ids | Reports | Threshold |
| --- | --- | --- | --- |
| E1 load | `E1.blank` `.resource` `.external` `.console` `.exception` `.no-report` | nothing visible; a request answered 400+, failed or refused by the page's policy (`.resource`); the same for an off-machine URL, not fetched, whatever asked for it: an image, a fetch, media, a frame, a WebSocket, a form (`.external`); `console.error`/`assert` and browser errors that name no refused load; uncaught exceptions from the first script on, placed in the file on disk; a page that never finished loading or checking | any; ten per id, the rest counted in a `dropped` note |
| E2 layout | `E2.overflow` `.wide` `.clipped` `.overlap` `.target` `.viewport` | the page scrolls sideways, or content past the viewport, slide or artboard is cut off (a box wholly past the right edge, such as an off-canvas drawer, is not); text an `overflow: hidden/clip` box cuts through (an ellipsis passes only with a `title` or `aria-label`); two text blocks whose lines cover each other (not inside a fixed or sticky box, nor where something else is drawn on top); targets under 24×24 px (axe's `target-size`, WCAG 2.5.8, its spacing and inline exceptions included); no `<meta name="viewport">` below 600 px | 1 px past an edge, vertically the line's 0.8 em band; overlap of 35% of the smaller line's 0.8 em band, 4 px each way |
| E3 accessibility | `E3.<axe rule>` | axe-core violations of impact serious or critical, up to 3 elements each, with axe's message | serious |
| E4 placeholder | `E4.lorem` `.todo` `.placeholder` `.generic` `.repeat` `.empty` `.identical` | lorem ipsum; `TODO`/`FIXME`; "placeholder", "your (company) name here", "insert text here" and the other template nouns (name, title, text, content, copy, heading, message, logo, image, label …), "sample text"; two or more "Item 1"-style labels; three or more same-tag siblings with the same text (8+ characters); a table with no filled data cell, an empty list; two artboards that render the same; never text inside `pre`, `code`, `kbd` or `samp` | as listed |
| E6 change | the `change` note | the widest width (each artboard on a board) against the last `dk check` of the page when the file changed since, else, for an artifact never checked, its previous version from its own `.versions/<slug>/` (a slug that leaves that folder is ignored), drawn under the page's policy with no service of this machine in reach: the share of pixels that moved and the box around them | a channel moving more than 10, `dk review`'s rule; Pillow for share and box, else changed or same |

The viewer's bar shows the last check, "Checked, 2 problems" (with "; page changed since" after an
edit) or "Not checked", in the notes drawer on a narrow window and not at all on the LAN, from
`GET /_checks?page=` (loopback only), which reads `.checks/results.json`; only
render-check.py writes it, with the page's mtime as it read the bytes, and drops the results
and shots of pages deleted since. The axe engine is vendored, unmodified:
`vendor/axe-core/axe.min.js` is axe-core 4.14.0 by Deque Systems, MPL-2.0, 652 KB, with its
`LICENSE`, `LICENSE-3RD-PARTY.txt` and a `VERSION` line holding its sha256; render-check.py
reads it from disk, and no route serves it.

Standing: each check against its own fixture (a clean page with no finding, one page per id
tripping that id alone at the widths it should), the page's own policy (a null origin, its
storage, its own folder's files, what is refused, no content URL printed), the result in the
viewer's bar, a deck, a board, a hung page, E6 in both diff branches, a previous version that
reaches no service of this machine, JSON-only escaped output, a preset answer, a forged post,
a replaced `Math.max`, hostile board and version metas, dialogs, downloads, WebRTC, a console
flood, the caps, pruning, a server with no check route, recorded as newer, the removed routes,
never-served results and the vendored file's sha256 —
`scripts/__tests__/check.test.sh`, **gate** (the browser half skips, saying so, without a
browser); the 60 s bound was timed by hand (69.9 s before, 60.1 s after, 2026-11-13). That a
skill runs `dk check` before presenting and fixes what it shows is **agent-graded**. Missed:
a check finds what it measures, not what a reviewer would; dark mode, hover, focus and other
states after interaction (light mode, first paint after load only); E6 and the PNGs show a
deck's first slide; iframes, closed shadow roots, canvas and image text; overlap of text
with images, and the drawn-on-top test outside the viewport; contrast over a background
image (axe calls it incomplete, not a violation); past 4000 elements, 8 artboards or 60
slides, the rest (a note says so); nothing comes from the network during a check, so a page
that needs a CDN font or image, from a host you allowed too, is checked without it (and says
so as `E1.external`); the page is not in the viewer's frame. What a hostile page can still
do: its script runs while it is measured, so it can change the DOM it is measured on (hide a
defect, show different content to a headless browser), keep the browser busy so a width
reads not checked, log errors or open dialogs, and reach a service on 127.0.0.1 by navigating
itself there (a GET), by preconnect (an empty connection) and by TURN over TCP. Its policy
refuses every other request to one, this server's write routes included, and it cannot read,
replace or answer for the check, nor write a result. A clean check is not proof the page is
fine.

## Skills

### `/design-kit:slides` — a deck you own

`/design-kit:slides <brief | outline.md> [--theme <tokens>] [--pdf] [--pptx]` writes an
outline (`.cc-artifacts/design-kit/decks/<slug>.outline.md`; grammar in the skill's
`references/outline-format.md`) and builds it into one self-contained HTML deck with
`scripts/deck-build.py`: keyboard/touch navigation, `S` speaker notes, `O` overview,
`P` print, `#/n` per slide, theme tokens from the design system when present. It opens
on the preview URL and reloads on every rebuild.

Exports on request: `scripts/deck-export.sh <deck> --pdf` prints one 1280×720 page per
slide with a Chromium-family browser found on the machine (exit 3 names what to
install; pressing `P` in any browser is the same output); `--pptx` writes native text
boxes, notes and pictures with pptxgenjs, which the script downloads into
`.cc-artifacts/design-kit/.cache/` only after the skill asked you (`DESIGN_KIT_PPTX_INSTALL=1`).

What has teeth: the builder FAILS a slide over 6 visible lines, an outline without a
title or slides, and any external `src`/`href` — **gate**. Headline-states-a-claim,
one-number-gets-a-figure, prose-lives-in-notes — **agent-graded**. Limits: the PDF is
the browser's print; the PPTX is an editable 16:9 grid, not a pixel match, and drops
fragments, transitions and nesting past one level. Not a `.pptx` reader — an existing
PowerPoint is the host `pptx` skill's job.

### `/design-kit:design` — directions as artboards on one local canvas

`/design-kit:design <brief> [--screens 2-6] [--device phone|tablet|desktop] [--theme tokens.json]`
drafts 3 UI directions by default (up to 5, never more than 6; `--screens` is clamped to 2-6) as artboards on one canvas, `.cc-artifacts/design-kit/boards/<date>-<slug>.html`,
served at the plugin's preview URL. Directions differ on structure (navigation, hierarchy, density,
first screen), not colour — the knobs do colour. On the board: edit any text in place, move
spacing/radius/hue/type/density/scheme knobs globally or per artboard (kept by the viewer in that
browser), pick an artboard and press Send pick in the viewer; with no server, "Copy edits as prompt"
pastes the same decision into the session. `scripts/board-export.sh` writes a PNG per artboard or one PDF
through a headless Chromium-family browser (exit 3 with the install hint when none is found; no
browser sandbox, see "What a page can and cannot do").

What has teeth: `board-build.py` exits 2 on fewer than 2 or more than 6 artboards, an empty body,
lorem ipsum, or any external asset — a board renders offline — **gate**. A board written outside
`boards/` (`--out`) gets a warning: the viewer takes no pick from it. That the directions
diverge structurally, that content is real, and the accessibility floor of a hand-written body
are **agent-graded**. Text contrast is measured only where `dk check <board>` runs (axe's
`E3.color-contrast`; standing under "Render checks"), not over a background image.

Limits: the artboard HTML is a decision aid, never a starting point for implementation (the pick
goes to `/design-kit:in-codebase` or the project's UI build command); knobs restyle the shell's
primitives only; the hue knob rotates the accent and its 170° partner `--dk-accent-2` together
and cannot express a near-neutral brand accent (use the design system's `tokens.json`); no font loads
through the offline gate, so a display face is named in a note and decided in the token file;
the viewer keeps edits in one browser at one address, so they do not travel to another browser or port.
Claude Code's own `/design` publishes artboards to claude.ai and needs a signed-in session; this
one stays on disk.

### `/design-kit:in-codebase` — the design, built from the real components

`/design-kit:in-codebase <brief | board.html#board=N | handoff-dir>` renders a design with the
project's OWN components on its OWN dev server. `codebase-scaffold.sh --detect` reads the stack
from disk (Vite React/Vue, Next.js App Router, Nuxt, Laravel Blade, Laravel + Inertia React/Vue)
and `--create <slug>` writes a
scratch entry under `__design-kit__/` paths, every file marked on line 1; the model fills it by
importing real components and providers, opens it on the dev URL, and once the user confirms the pick is final
`codebase-cleanup.sh` removes every trace — `--verify` exits 1 if anything is left. An Inertia
app gets a page that names its own bare layout (the starter kits' default `layout` would wrap it
in the signed-in shell) and a `Route::inertia` line; Laravel's dev URL is `.env`'s `APP_URL`, the
one key read there. Where the entry stylesheet imports Tailwind v4, one marked `@source` line
points it at the scratch dir, because `__design-kit__/` is gitignored and v4 skips gitignored
paths; cleanup restores the stylesheet and `routes/web.php` byte for byte.

A Claude Design handoff bundle (a folder of exported .html plus a README) goes through
`handoff-drift.py` first: every colour and font in the export against the repo's tokens
(`--*` custom properties incl. Tailwind v4 `@theme`, `tailwind.config.*`, the design system's `tokens.json`),
one row per value — `match`, `near (Δ)`, `no token` — and each `no token` row is a question, never a
literal in the tree. The export is a reference; its HTML and class names never land in the project.

Since 0.4.0 the same reader asks that question of the project's OWN components:

```
dk drift [PATHS | --staged | --diff <base>] [--ci]
```

It reads `.tsx/.jsx/.vue/.blade.php/.css/.scss` and reports two kinds of hit — a literal
hex/rgb/hsl/oklch colour that resolves to no declared token, and a NAMED TAILWIND PALETTE
utility (`bg-indigo-500`, `text-slate-700/50`) whose scale is not a declared token name. That
second kind is the gap that made this exist: it never reaches a stylesheet, so `dk check` and
the bundle table above both stay green while the components drift. `bg-primary` and
`var(--primary)` are clean by construction, which is the whole test. Without `--ci` the table
is the output and the exit is 0; with `--ci` any hit exits 1. No token source anywhere exits 2
(`not measured`) — a drift check that cannot find the tokens has not cleared anything, and an
empty `--staged`/`--diff` selection scans nothing rather than the whole tree.

**Standing: `gate` only where you wire it.** Nothing in this plugin runs `dk drift` over your
components — no hook, and `/design-kit:in-codebase` runs it only on the scratch files it adds.
It is a script with a harness (`scripts/__tests__/drift.test.sh`, run by CI's plugin-harness
step), and `--ci` is what makes it block, in a CI step or a
pre-commit hook you add. Not run is not clean. What it does NOT catch: spacing, radius, shadow
and font drift; a colour computed at runtime; the right token used in the wrong role. The
script's own header carries the full residual list.

Since 0.13.0, `dk drift --print-hook` prints a `PostToolUse` hook for `.claude/settings.json`
(stdout is the JSON, stderr says where it goes) and writes nothing. Pasted, it runs
`handoff-drift.py --scan --ci` on each file Claude edits: a hit hands Claude the table (exit 2), and
a clean file, a file it does not scan, a project with no tokens or a malformed payload stay
silent. It names this version's absolute path, so re-run it after a plugin update. Standing:
**gate** for the snippet — `drift.test.sh` runs the printed command against those payloads;
whether you paste it is yours.

What has teeth: the scratch-file cleanup (`--verify`, run from the project root whatever the
shell's directory), the bundle drift table and `dk drift`'s scan are **gates** — scripts under `scripts/__tests__/` drive all three. Consent before the first write is an AskUserQuestion, once
per session. Finding the right component, passing only real props, rendering all four states, and
never touching a real file are **agent-graded**; `git status` after cleanup is the check.

Limits: stacks it does not detect (Angular, SvelteKit, Rails) fall back to `/design-kit:design`;
a Laravel + separate Vite SPA repo resolves to Laravel unless `--stack` overrides; the bundle
format is undocumented by Anthropic, so detection is lenient and says which files it read; nothing
here proves the page rendered — the browser does. Spacing/radius/shadow drift is read by eye.

Since 0.2.0, `--create <slug> --brief "<line>"` reads the design system's `components.json` when
`/design-kit:system` has written it: the scratch page opens with the app's stylesheet, every
component imported (alias-aware), its prop signature as a comment, and a strip rendering each
union variant with the brief as content. Required props get type-shaped values; one the strip
cannot fake is commented out naming the prop; each extractor blind spot (a generic, an
`extends`, an intersection) is a `gap:` comment naming the file to open. Without
components.json the plain template is written, as before. That the imports resolve is the
dev server's overlay, not a script — **agent-graded**; the filled shape is **gate**.

### `/design-kit:system` — the design system as a record, not a proposal

`/design-kit:system [repo | https://url | brand-dir]` runs `scripts/system-extract.py`
and writes `.cc-artifacts/design-kit/design-system/`: `tokens.json` (DTCG-shaped: `$type`, `$value`, `{alias}`,
dark values under `$extensions.design-kit.modes`, every token with a `path:line` source),
`DESIGN-SYSTEM.md` (the plain `## Design system` block Claude Code's artifact skill reads,
a component inventory with props and variants, and a `## Not found` list), and `kit.html`
(a UI-kit page whose every card carries an `@dsCard` marker, shown on the preview URL).

What it reads: `:root`/dark-selector custom properties, `@theme {}`, SCSS `$vars`,
Tailwind `theme.extend` literals, `components.json`, `@font-face`/`font-family`, and
component files (TS Props, `defineProps`, cva variants, Blade `@props`, PHP view
components, stories). URL mode fetches the page and its stylesheets without JavaScript
and says so in the output. Brand mode reads `.css`, `.svg` fills and `.md` hex lines.
Rendered mode (`--source rendered`, since 0.13.0) loads the page in the project's own Playwright
Chromium after its JavaScript ran (`scripts/system-render.mjs`): computed colours, font families
and sizes, padding, gaps and radii of every visible element, near colours merged, values on one
element only dropped (the page background excepted). Dark mode, motion, shadows and components
are listed as not read. Its token names are the values (`color.1f2937`) and its sources are elements, because a
computed style carries no role; exit 3 names a missing Playwright or Chromium.

What has teeth: nothing enters the record without a source, and the same source
gives byte-identical files — **gate**, `scripts/__tests__/system-extract.test.sh` runs
it twice and compares. Which of two primaries is canonical is asked, not decided —
**agent-graded**. Appending the block to CLAUDE.md is an explicit yes; default is no.

Not this: it does not evaluate JS (a Tailwind config built from functions yields only
its literal entries), does not render real components (`kit.html` cards are static
stand-ins that name the component and its props — `/design-kit:in-codebase` renders
the real thing), and does not conform to the DTCG 2025.10 object forms for colour,
dimension and duration — values stay as the source wrote them; `references/tokens-format.md` says why.

**Where these tokens can go.** The target is the DTCG **Format Module 2025.10**
(designtokens.org, Final Community Group Report of 28 October 2025, which says it is
intended for implementation; the "do not attempt to implement this version" warning is on
the later editor's draft, not on 2025.10). The structure matches it: one object
per token with `$type` and `$value`, plain nested groups, `{group.token}` aliases,
`$extensions` for tool data. It diverges in the value forms, all written down in
`skills/system/references/tokens-format.md`: a `color` `$value` stays the string the
source wrote — a hex, an `oklch()` call, a shadcn HSL triplet — rather than the report's
`{colorSpace, components}` object (`alpha` and `hex` optional), a `dimension` stays
`0.5rem` or `24px` rather than `{value, unit}`, and a `duration` stays `200ms` likewise.
Named easings and shadows stay strings too. The reason: the form the source used is
evidence, and `%`/`em` have no conforming object form to convert into. What that costs a consumer:
**Tokens Studio** (the Figma plugin that reads and writes DTCG) and **Style Dictionary**
(which compiles DTCG into CSS, iOS and Android output) both read this structure, and both
need those value forms converted on their side. This plugin ships neither converter —
standing: **recorded**, nothing here has been run against either tool.

Since 0.2.0 it also writes `components.json` (props with types, defaults, required flags;
variants; stories; honest `gaps`) and gains `--check`: against the committed `tokens.json` it
prints one `check:` line per moved token and exits 1, writing nothing — the other four skills
run it first through `dk check`. Every deck, board and artifact carries
`<meta name="design-kit-tokens">`,
the sha of the tokens file it read (or `none`) plus the git revision, which the gallery badge
reads. Determinism, `--check` and the stamps are **gate** (harness-driven).

### `/design-kit:artifact` — one self-contained page, versioned, shared on a question

`/design-kit:artifact [file.html | file.md | dir | brief] [--name slug] [--zip]` — every
stylesheet, script, image and font inlined by `scripts/artifact-bundle.py` — written to
`.cc-artifacts/design-kit/artifacts/<slug>.html`, versioned (`.versions/<slug>/vN.html` +
`<slug>.versions.json`), and served on the plugin's preview URL with live reload. Without `--name`
the artifact takes the file's name, an `index.html` or `index.htm` its folder's; a slug that
already holds versions of another source is written all the same, with a warning that names
`--name`. A `.md` source renders through the page shell (ATX headings, one-level lists, pipe
tables, fenced code, links; no nested lists, footnotes or reference links). A brief means the
model writes the page from one of five patterns (walkthrough, compare, dashboard, checklist,
bring-back) with data from this session.

Sharing is a question every time, default "keep it local": LAN (`preview.sh --lan`, a URL carrying its key),
a pages branch (`scripts/artifact-publish.sh`, dry run first, pushed only on a second
yes, never enables Pages, never force-pushes), or a zip. There is no other network path.

What has teeth: the bundler's inlining, UTF-8 refusal, stamp, version ledger, network and
unresolved-link reports, and the publisher's worktree isolation are **gates** —
`scripts/__tests__/artifact-*.test.sh` drive each. Page quality is **agent-graded**. Notes on the
served page: see "Notes on any page". A shared copy has no viewer, no sandbox and no policy: see
"What a page can and cannot do". Not here: refresh from live data, runtime asset loads (a page
that fetches assets from JavaScript keeps those references unreported), `srcset` rewriting.

### `/design-kit:film` — a product film from a brief

`/design-kit:film [brief.md | product URL] [--run-to-end]` makes a demo, launch film, explainer or
beat-synced reel in `.cc-artifacts/design-kit/film/<slug>/`, rendered by HyperFrames (default), Remotion, or a
hand-rolled `seek(t)` page. The skill is an order: brief (every blank decided and logged in
`brief.txt`) → `film.py doctor` → facts into `facts.json` → the UI captured at 2x, logo as SVG, fonts
copied → a 3-second draft MP4 → sound first (`film.py music` writes the beat grid, or
`film.py beats` reads a supplied track) → three storyboard directions ⏸ → style lock from three
stills ⏸ → one component per scene, every value from the frame number → review rounds by a fresh
subagent given only the MP4 → muted test → delivery: one MP4 per format, a music-only track, a
contact sheet, `facts.json`, `timing.json`, `ledger.txt`, and the seconds still worth watching
yourself. ⏸ stops ask; `--run-to-end` decides and logs why.

Needs Node (22+ for HyperFrames), `ffmpeg` with libx264, AAC and loudnorm, and a headless Chromium.
Voice needs a TTS key in an environment variable; without one the skill stops and says so.
Remotion requires a paid company licence for a for-profit organisation over 3 employees, so the
skill asks before choosing it.

What has teeth: `scripts/film.py check` fails an on-screen line `timing.json` declares without a
`facts.json` source or with a number its source lacks, a line held under 0.7 s or 0.3 s a word, a
hard cut or action more than one frame off the beat, a text pair under 4.5:1, more than six
colours, text in the bottom 8% or overlapping, and with `--video` a wrong duration, fps, size,
codec, sample rate or a moov atom after mdat; `film.py loudness` fails off −14 LUFS / −1 dBTP;
`film.py pops` fails a single-frame pop — **gate**, driven by `scripts/__tests__/film.test.sh`,
whose five ffmpeg cases skip where ffmpeg is absent. That every line is declared, that the
reviewer stayed blind, that frame 0 is a finished picture and the film reads muted — **agent-graded**.
Whether a fact is true — **unenforceable** here. Adapted from a "Motion Studio" brief the user
supplied, with pipeline facts from [yihui-dev/awesome-opus5-5-videos](https://github.com/yihui-dev/awesome-opus5-5-videos)
@92aee2f; no creator's prompt is reproduced. Unmeasured: no control arm.

### `/design-kit:motion` — a static design, alive

`/design-kit:motion [figma-url | image] [--website] [--no-export]` rebuilds the design as a
fixed-size stage in `.cc-artifacts/design-kit/motion/<slug>/index.html` — every moving layer exported from
Figma's REST API at 3x and placed by the rules in `references/figma-export.md`, the background
kept byte-for-byte — then animates it: the empty state first, a staggered rise-and-resolve intro,
a story per visual (a list receiving an item, a chart being read, a prompt being typed), a
dissolve and a seamless repeat. A capture steps Playwright's fake clock frame by frame into the
dot directory `.frames/` (the preview server neither lists nor watches it) and `ffmpeg` writes
`<name>-x.mp4`, `<name>-loop.gif` and `<name>-800x500.gif` into `out/`. On a website the same
stories run on bento and feature cards, started once on scroll, with live HTML text.

Needs Node with Playwright's Chromium for capture, `ffmpeg` for export, and a Figma personal
access token in the environment for a Figma source; the skill names what is missing before it
builds.

What has teeth: since 0.13.0, `scripts/motion-check.mjs` is the recorder — the project's own
Playwright on a stepped fake clock, PNG frames with `--frames`, the page's `__start`/`__tick` driven
— and a **gate where run**: it exits 1 on an animated layout property, a CSS animation or
transition outside 500–1100 ms, blur above 14 px, or motion left under
`prefers-reduced-motion: reduce`; `--static` checks the CSS rules with no browser. Exit 3 is a
missing Playwright or Chromium, named and never installed; 4 is a page that did not load or did
not animate. `scripts/__tests__/motion-check.test.sh` drives both modes, and skips the browser half
where no Playwright launches (CI). The still-versus-reference PSNR floor and the overflow, seam,
empty-beat and rest checks stay **agent-graded**, and encoding stays `ffmpeg` by hand.
Credit: adapted from `design-to-motion` in
[elayadesign/ai-design-skills](https://github.com/elayadesign/ai-design-skills) @a2735a3 (MIT,
© 2026 Elaya), restructured here; the licence text is in `references/motion-system.md`. Its
effect on what the model builds is unmeasured.

## Snapshots and review

Two `dk` verbs, no command and no hook — a UI change is easier to judge beside the screen
it replaced than from a diff:

```bash
dk snapshot --routes /,/pricing --device both        # one PNG per route per device
# …change the UI…
dk snapshot --routes /,/pricing --device both
dk review --base .cc-artifacts/design-kit/shots/<the first set>   # or a git ref whose shots were committed
```

`snapshot` loads each route in the same Chromium-family browser `board-export.sh` finds
(it asks that script, so one install hint serves both) and writes
`<out>/<device>/<route-slug>.png` — `<out>` defaults to
`.cc-artifacts/design-kit/shots/<git short sha, else a UTC timestamp>/`, desktop is 1440x900, mobile
390x844, and `--base-url` defaults to the dev URL `dk scratch --detect` reports. A second
shoot at the same commit writes `<sha>-2` rather than over the set you are about to
compare against. `review` pairs the newest set (or `--current`) against `--base`, writes
`.cc-artifacts/design-kit/reviews/<pair>.html` with **before | after | a pixel-diff heatmap** per
route (a shot that lies outside `shots/` as a copy under `reviews/diff/<pair>/`, since a review
page loads images from those two folders only), serves it on the same preview URL as everything
else, and prints one table row per route with the changed-pixel percentage. The heatmap and the
percentage need `python3` with Pillow; without it the page shows the pair alone and every row
reads `no diff engine: install Pillow`.

**Exit codes are the contract** — **gate**, `scripts/__tests__/snapshot.test.sh` drives
each: `0` shot or rendered, `1` bad arguments, `2` the browser or the server was
unreachable, printed as `NOT MEASURED` and never as "no change" — a shot nobody took is
not a screen that did not change. Reading the pair is **agent-graded**: nothing here
asserts a pixel, so there is no threshold and no failing build. Also not here: signing in
(a route behind a login shoots the login page unless `--storage-state` replays a session,
below), per-component crops, scroll or animation settling past one 3 s budget, and device
emulation beyond the viewport size — no touch, no mobile UA, no DPR change. Two machines'
antialiasing counts as changed pixels.

### Behind a login

```bash
dk snapshot --routes /dashboard --device both --storage-state .cc-artifacts/design-kit/auth/walk.json
```

The file is a Playwright `storageState` JSON: cookies, plus localStorage per origin. Sign in
once through the project's walk access, meaning a self-registered or seeded test user with a
password the agent set, or an env-guarded local-only login. **Never use the user's own
account.** Then save the state from that same Playwright MCP browser in one
`browser_run_code_unsafe` call:

```js
async (page) => {
  const file = '/ABSOLUTE/PATH/TO/REPO/.cc-artifacts/design-kit/auth/walk.json';
  const { origin, localStorage } = await page.evaluate(() => ({ origin: location.origin,
    localStorage: Object.entries(window.localStorage).map(([name, value]) => ({ name, value })) }));
  const state = { cookies: await page.context().cookies(page.url()), origins: [{ origin, localStorage }] };
  const browser = page.context().browser();
  if (!browser) { await page.context().storageState({ path: file }); return 'saved (whole context)'; }
  const ctx = await browser.newContext({ storageState: state });
  await ctx.storageState({ path: file }); await ctx.close(); return 'saved';
}
```

Why not a plain `page.context().storageState({ path })`? A Playwright MCP attached to a real
Chrome profile saves every site's cookies. Measured 2026-09-25: 48 of 49 cookies were the
user's own (Google, LinkedIn, YouTube and others) and one was the app's. The call above keeps
only the cookies the browser would send to the app's URL. It writes through Playwright because
the tool's sandbox has no `fs`, `require` or `URL`. `browser()` is null when the MCP launched its
own profile, which holds only what the agent browsed; then the whole context is saved. A project
with its own Playwright setup can write the same file with `context.storageState({ path })` from
an isolated context.

**The file holds a live session token.** Inside a git work tree `snapshot` refuses it with
exit 1 unless git ignores it, and a tracked file never counts as ignored. Keep it under
`.cc-artifacts/design-kit/`, which `dk` keeps ignored, or outside the repo. Delete it when the walk user goes.

What it carries: cookies and localStorage. It does not carry sessionStorage, IndexedDB or an HTTP
auth header. The browser's `--screenshot` CLI cannot take a cookie, so this path drives the same
browser over the DevTools protocol (python3 stdlib, no Node). It settles in real time: the load
event, then 500 ms without a request in flight, at most 3 s. The plain path uses a 3 s
virtual-time budget instead, so do not pair a signed-in set with a plain one. A route that ends
on another URL (a sign-in redirect, an expired session) is still shot, with a `WARN` naming
where it landed. A file that holds cookies for other hosts draws a `WARN` too. Nothing tells a
signed-in page from a login page that keeps its URL, so read the shot.

Standing: **gate** for the refusals. `snapshot.test.sh` drives a missing, a malformed, an
un-ignored and a tracked file. When a browser is installed it also shoots a cookie-guarded route
where the server logs the cookie and a localStorage beacon, plus an expired session that must
`WARN`. That the save call above produces a file which replays here was run by hand once
(CHANGELOG 0.6.0), not in CI.

## Boundary with the host

- `/design`, `/design sync|import|export`, `/design-sync` and the `Artifact` tool are
  Claude Code built-ins. This plugin never calls them and never blocks them. When they
  are available, `/design-kit:system`'s `DESIGN-SYSTEM.md` is the record the host's own
  artifact design skill reads first, and its `@dsCard`-marked kit cards are the shape the
  host's design-system sync indexes.
- The `pptx`, `theme-factory` and `web-artifacts-builder` skills synced from claude.ai
  are Anthropic's. `/design-kit:slides` exports through its own script so a deck exists
  without them; when the `pptx` skill is present it is the better editor of a `.pptx`.

## Measured

A design plugin with one real invocation across ten projects was retired from this
marketplace on 2026-09-14. This one starts from zero and says now what would retire it.

**How it is measured.** `bash scripts/dk-usage.sh --projects <dir>...` (in this plugin) prints one
row per surface per project — created, revisited, picked, rendered, exported, shared,
followed-by-commit — from `.cc-artifacts/design-kit/usage.jsonl` (one line per `dk` verb),
`.cc-artifacts/design-kit/decisions.jsonl` (one line per pick sent: only its time and whether it
was read), file mtimes, and `git log` over the seven days after each decision, restricted to the
component paths `DECISIONS.md` names. `followed-by-commit` reads `n/a`, never 0, when that file
names no path. The router side: skill-router carries a `**/dir/**` row per surface, so
`turn-cost.sh --skills` at the marketplace root can count offers; without those rows it read zero
by construction.

**The kill trigger, as a number.** Thirty days after 0.2.0, with at least three projects
that have a design-kit folder (`.cc-artifacts/design-kit/`, or an older `.design-kit/`): `followed-by-commit = 0` across all of them AND
`shared = 0` → retire the plugin on the same evidence that retired its predecessor. The
script prints the verdict inputs; the decision is a human's. A non-zero count proves a
surface fired, not that it helped — the only column that means "a design decision changed
code" is `followed-by-commit`.

**Blind spots, stated.** Subagent turns are invisible. A pick pasted from the clipboard is
prose in a transcript, not a decision row, so it counts as nothing. A deck opened in a
browser leaves no record. A project not passed to the script is not measured.

Standing: the script and its harness (`scripts/__tests__/dk-usage.test.sh`) — **gate**;
the thirty-day reading and the retirement call — **recorded**, a human reads the table.

## What gets ignored, and what is yours

The first `dk` verb inside a git repo appends one managed block to `.gitignore` with
`.cc-artifacts/design-kit/` and `__design-kit__/` — previews, exports, decisions, the design
system and scratch never reach a commit by accident. In a project that still has `.design-kit/`
the block keeps naming it, since it may hold a signed-in session under `auth/`. It never adds a
path that already has tracked files, and `DESIGN_KIT_IGNORE=off` skips it. To keep the design
system in git, `git add -f .cc-artifacts/design-kit/design-system/` once; a tracked file stays
tracked. Standing:
`dk.test.sh` drives first run, idempotence, the tracked-path refusal, the kept legacy line and
the off switch — **gate**. A marketplace-wide sweep across
every plugin's scratch paths lives in git-workflow (`scratch-ignore.sh`, run by
`/git-workflow:finish`).

## Disabling

Uninstall the plugin. `DESIGN_KIT_PORT` fixes the server's port. `.cc-artifacts/design-kit/` is safe to
delete at any time except its `design-system/`, which is yours.

## Not in this release

Notes from another device or on a published or zipped page (notes are loopback-only and
stay in `.cc-artifacts/design-kit/`), a version picker in the browser, Figma import or
export beyond `/design-kit:motion`'s read-only REST calls, image generation, a component registry, and any hosted publishing beyond a git
pages branch you push yourself.

No Figma bridge does not mean no route out: the design system's `tokens.json` is DTCG-shaped,
and the paragraph under `/design-kit:system` names the value forms a Tokens Studio or
Style Dictionary consumer has to convert to use it.
