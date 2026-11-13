# Changelog — design-kit

Consumer-facing changes only. Newest first.

## 0.16.0 — 2026-11-13

- **`dk check <page>` looks at a page in a real browser before you do.** A deck, board or artifact was written and shown with nothing looking at the rendered result first. `dk check <page> [--widths 375,768,1280]` now loads it in the Chromium-family browser the plugin already finds, at each width (a board: each artboard at its own frame size; a deck: every slide), and prints one escaped JSON object per line: each finding, notes (`change`, `not checked`, `skipped`, `dropped`, `capped`), and a summary naming the PNGs it saved under `.design-kit/.checks/shots/`, so no page text reads as the tool's own words. Exit 0 clean, 1 findings, 2 bad arguments, 4 not checked. It reports: a blank page, failed or off-machine requests, console errors and uncaught exceptions (E1); sideways overflow, content cut off past the viewport, slide or artboard, text cut by `overflow: hidden`, overlapping text, targets under 24×24 px, a missing viewport meta at phone widths (E2); axe-core's serious and critical violations (E3); lorem ipsum, TODO, "your name here" and the like, "Item 1"-style labels, three identical sibling rows, empty tables and lists, two identical artboards (E4); and how much of the widest shot changed since the last check, or since an artifact's previous version, and where (E6, the share and box need Pillow). A plain page takes under a second for three widths; a run stops at 60 s, every wait included. Nothing leaves the machine during a check (a dead proxy that wins over the environment's, no DNS, no WebRTC UDP), downloads are refused and dialogs accepted. `dk check` with no page is still the design-system line. The `artifact`, `design` and `slides` skills run it before presenting, fix what it shows, run it once more and name what is left.
- **The check runs where the page's script cannot reach it.** axe-core and `scripts/check.js` are evaluated in an isolated world of the page over DevTools, and the findings come back the same way: no route serves the check or takes findings, so a script on the page cannot preset its answer, post forged findings or hide real ones, and a server started before this version checks as well. Results and shots live in `.design-kit/.checks/`, a dot folder: never served, never a reload; those of deleted pages are dropped. `GET /_checks?page=` (loopback) feeds a line in the Notes panel: "Checked … UTC: N findings" or "Not checked". The reload client is unchanged at 758 bytes.
- **Fewer false findings, bounded output.** A one-line ellipsis that fits, an off-canvas drawer, a fixed bar over scrolling text, copy such as "Track your order here" and a TODO inside `pre` or `code` are no longer reported. Browser-event findings stop at ten per id with a `dropped` count; past 4000 elements, 8 artboards or 60 slides a note names what was not checked; a board's sizes and ids and an artifact's version slug are bounded before use; the sandbox hint appears only when the browser never answered, as a question for the user.
- **axe-core 4.14.0 is vendored** under `vendor/axe-core/` (Deque Systems, MPL-2.0, 652 KB, unmodified, with its licence files), used only by a check.
- The artifact shell's `--warn` colour moved from `#a86400` to `#975a00`: on a card it measured 4.1:1, under the 4.5:1 body-text minimum, and the new check flagged every warn pill. In dark mode the ok, warn and bad pills measured 2.5 to 3.4:1; they now have dark values (`#5fc48f`, `#e0a43c`, `#f2847c`, 6.6:1 or more on both surfaces).
- What is not closed: a check finds what it measures, not what a reviewer would; it renders light mode at first paint, so dark mode, hover and focus states go unchecked; E6 and the PNGs show a deck's first slide; a page's own script still runs while it is measured and can change what is measured (hide a defect, keep the browser busy, reach loopback services such as `POST /_note`), so a clean check is not proof; a page that needs a CDN font or image is checked without it.

Standing: gate — `scripts/__tests__/check.test.sh` (a clean page with no finding, one fixture per check id tripping that id alone at the widths it should, a deck, a board, a hung page, E6 with and without Pillow, JSON-only escaped output, a preset answer and a forged post, hostile metas, dialogs, downloads, WebRTC, a console flood, the caps, pruning, an older server, the removed routes, never-served results, the vendored file's sha256; the browser half skips without a browser). That a skill runs the check and acts on it is agent-graded.

## 0.15.0 — 2026-11-12

- **Leave a note on any element of a served page, and the session reads it.** Feedback on a deck or artifact had to be typed into the chat, describing the element in words. Every page the preview server serves live (decks, boards, artifacts, previews; not the gallery) now has a small **Notes** button, bottom right, and **Alt+N**: point at an element (it is outlined), click it, or Tab to it and press Enter, and type a note; "Note on this page" leaves one on no element; Escape cancels. The panel lists the page's notes with status and reply. A note lands in `.design-kit/notes.jsonl` through a new `POST /_note` with `/_decision`'s guards (loopback only even in LAN mode, loopback `Host` and `Origin`, an `X-Design-Kit-Note` header, at most 8 KiB of JSON) with a CSS selector, tag, text and box for the element, the viewport, the page's colour scheme and the last five console errors, every field clamped. On a board, Pick works as before. The reload client grew from 702 to 758 bytes to import the script from the server's own origin; a headless browser, `?static=1`, a file, another server and a phone on the LAN get no widget.
- **`dk notes`** prints unread notes as one JSON object per line and marks them handed out (`--all` lists all). `dk notes --wait` blocks until a note or an unconsumed board pick arrives (exit 3 after `--timeout`, default 600 s), so run in the background it brings the session back when you click Send. `dk notes --reply ID --status addressed|dismissed --text "…"` answers a note, and the page shows the answer on its next load. `dk notes --shot ID` saves a PNG of the page with the element outlined into `.design-kit/.notes/`, through the Chromium-family browser `board-export.sh` already finds; with none it says so and exits 4. The `design`, `artifact` and `slides` skills start the wait after giving the URL and reply to each note they handle.
- **The unread-pick hook counts unread notes** and names `dk.sh notes`; it never prints note text, a selector or a page path. A pick's board name, which a page also posts, is now printed only when it is a plain file name.
- **Review fixes before release.** `dk notes --wait` printed a pick's page-posted prompt raw after the rows, where newlines and escape codes could forge a row; it now prints the pick as one escaped JSON line, and the next wait waits past a pick it already printed instead of returning it forever. Note rows now escape what taskmaster's reader escapes (controls, bidi and zero-width characters, line separators, variation selectors, Hangul fillers, the blank Braille cell). A note is marked handed out only after it is printed, and a note handed out 15 minutes ago that is still open is unread again, so a killed reader no longer swallows it (the hook counts the same way). `--shot` takes the id it checked, refuses `--shot` mixed with any other option or given twice (exit 2: `--shot ../../x --shot <id>` used to write outside `.notes/`), runs Chrome with its sandbox on (off as root or with `DESIGN_KIT_BROWSER_NO_SANDBOX=1`), in a throwaway profile instead of yours, for at most 30 s, and reports a browser that fails. The server refuses a note with no text (400), stores a lone surrogate as `?` instead of dropping the connection, clamps numbers to ±10,000,000, answers 507 once `notes.jsonl` or `decisions.jsonl` would pass 2 MiB and a JSON 500 when a write fails, and never follows `notes.jsonl` through a symlink; `dk notes` rewrites through a fresh temp file and keeps lines it cannot parse. The hook names a pick's board only when the name is plain ASCII, at most 64 characters and a file in `.design-kit/boards/`, and the artboard only from 1 to 99; otherwise it gives a count. In the widget, Alt+N typed in a text field is the field's (macOS Option+N types ñ), turning the widget off keeps the draft, a console object with no `toString` no longer throws into the page, text is cut by code point, the `--shot` outline follows a late layout shift, and the outline script imports from the page's own origin.
- What is not closed: a page carrying third-party script can post a note from the same origin; note text is what someone typed, not verified; a selector built on element order goes stale when the page changes; notes do not travel with an exported, zipped or published page.

Standing: gate — `serve.test.sh` (the route's accept, six rejects and clamps, `/_notes`, `/_note.js`, the injected import and its size, `?_outline=`, `notes.jsonl` never served, a LAN peer with the key refused), `dk.test.sh` (every `dk notes` mode, a real `--shot` where a browser exists) and `unread-pick.test.sh` (a count, and none of an instruction-shaped note's text, selector or page). The widget in a browser was run in Chromium on 2026-11-13, before and after the review fixes (recorded); no harness drives it. That the model acts on a note is agent-graded.

## 0.14.0 — 2026-11-12

- **A LAN server asks other devices for a key.** `--lan` let anyone on the network who found the port read every page under `.design-kit/`. A LAN server now keeps a random key in `.design-kit/.preview.key` (mode 0600, never served), and `preview.sh`, `serve.py` and every `dk` verb that prints a URL while LAN mode is on print it with `?key=…`. Any device but this machine's loopback needs that key once, then an `HttpOnly`, `SameSite=Strict` cookie; with neither it gets 403, `/_events` and `/_index.json` included. `/_decision` still refuses every other device, key or not. A restart keeps the key; `dk serve --stop` deletes it, so the next LAN start prints a new URL. The first keyed visit is a small page that sets the cookie and refreshes to the clean URL, not a 303: in Chrome a 303 left a link followed from another site on 403, reload included. What you lose: a LAN URL without its key no longer opens, so a phone needs the whole printed URL. Not closed: the server speaks plain HTTP, so the key crosses your network in clear, and it sits in the phone's history and anywhere the URL is pasted.
- **Every server exits after 4 hours idle.** A server started in one session kept its port, and the files under it readable, for as long as the machine stayed up. It now exits after `DESIGN_KIT_IDLE_MINUTES` (default 240; `0` turns it off) with no request and no open page, LAN or not; an open tab counts as open, since its reload client holds a stream. The pid and URL files stay behind, as after a LAN expiry, and the next `dk` verb starts a fresh server. What you lose: a server left running with no tab open for longer than that, unless you set `0`.
- **An open page says when the server is gone, and comes back with it.** The page gave no sign that the server had stopped. The injected reload client now shows a small "Preview server stopped; retrying" bar (`role="status"`, no animation), retries after 1, 2, 4 … 30 seconds, and reloads once the server answers, so a change written meanwhile shows. It grew from 170 to 702 bytes on every served page. A headless browser and `?static=1` still get no client.
- `serve.py`'s header no longer names a restore script; none exists.
- **Review fixes before release.** A request written in absolute form (`GET http://x//auth/walk.json`) was checked as one path and served as another, so `auth/walk.json`, `.preview.key` and `decisions.jsonl` came back 200; `HEAD` skipped the check entirely. One parse of the request target now feeds the check and the open, for `GET` and `HEAD`. Any other malformed cookie in the same header (`theme=dark mode`, a valueless cookie) used to void the key cookie and leave a phone on 403; cookies are now split by hand. `--stop` and a `--lan` restart killed whatever process held the recorded pid; they now act only when `ps` (else `/proc`) shows `serve.py` on this docroot, and a live pid neither can name stops the launcher with exit 6, signalling nothing. A server that ends itself removes its pid, URL and bind files, and `dk status` no longer prints the URL of a dead server. A request refused for want of the key no longer keeps an idle server up, and `POST` now meets the key gate first. A symlink at `.preview.key` was followed for the read, the `chmod` and the write; it is now replaced, never followed. Standing: gate — `serve.test.sh` and `preview.test.sh`, each case red before its fix.

Standing: gate — `scripts/__tests__/serve.test.sh` (the key as a unit, and end to end from this machine's network address, which skips on a machine without one; the reload client's injected text and size) and `preview.test.sh` (the idle limit in both modes, and `0`). Not measured by any harness: the bar's behaviour in a browser and a keyed link followed from another site; both were run once in Chrome on 2026-11-12 (recorded). A second physical device was not tried.

## 0.13.2 — 2026-11-12

- **`unread-pick.sh` reads only this session's phase sentinel** (`.claude/cc-phase/<session>.json`, written by taskmaster 0.56.0's `phase-sentinel.sh`). A build phase declared by another session in the same repo no longer silences the unread-pick line. Its pasted phase-file and phase-guard blocks are now held byte-for-byte to the shared blocks by a gate. Standing: gate; `scripts/__tests__/unread-pick.test.sh`.

## 0.13.1 — 2026-11-11

- **The preview server no longer hands out session and state files.** `scripts/serve.py` returned every file under `.design-kit/`, so the saved login session the README keeps at `.design-kit/auth/walk.json`, `workshop.json`, `usage.jsonl`, old artifact versions and directory listings were readable by any local client, and by the whole network under `--lan`. It now answers 404 for a dot-prefixed file or folder, `auth/`, those state files, `*.versions.json` and any directory listing. Pages, images and other assets are served as before, so a signed-in screenshot under `.design-kit/` is still readable by whoever can reach the port.
- **LAN mode ends, and says when it is on.** After one `--lan`, every later command reused the network-wide server with no word about it, in later sessions too. A LAN server now exits after 60 minutes (`DESIGN_KIT_LAN_MINUTES`, `0` for no limit), and a command that reuses one prints that LAN mode is still on. `dk share <page> --lan` while a loopback server was running printed a `127.0.0.1` URL no other device could open; it now restarts the server on the network address.
- **`/_decision` refuses a page that is not this machine's own.** It checked the client address and a header only, so a site whose DNS name was rebound to `127.0.0.1` could plant a pick and its prompt text. It now also requires a loopback `Host` and, when the browser sends one, a loopback `Origin`. Not closed: a page served by this server (a bundled artifact carrying third-party script) can still post.
- **An open gallery no longer blocks picks.** Each gallery thumbnail held a live-reload connection; with six or more pages the browser's per-host limit was reached and a board's pick in another tab was never recorded. Thumbnails now load without live reload.

Standing: gate — `scripts/__tests__/serve.test.sh` and `preview.test.sh`; the LAN half skips on a machine with no network address.

## 0.13.0 — 2026-11-09

- **`scripts/motion-check.mjs` — the motion recorder, shipped, with the motion skill's rules as checks.** It drives the project's own Playwright (or `NODE_PATH`'s) on a stepped fake clock, seeks every CSS and Web Animations animation per frame (one the page pauses stays paused; one past its end is finished, so a `.finished` chain runs), drives a page's `__start`/`__tick`, and with `--frames` writes the PNGs, plus `loop-time.json` when the page defines `__start`/`__tick`, so `/design-kit:motion` no longer writes a recorder per project. It exits 1 on an animated layout property (an inline visual property changed 3+ times by JavaScript counts; a `display` or `z-index` swap does not), a CSS animation or transition outside 500–1100 ms (`--min-ms`/`--max-ms`; 16 ms or less is a reset), blur above 14 px (`--max-blur`), or anything but opacity moving under `prefers-reduced-motion: reduce`; paint properties and `transition: all` warn. `--static <file.html>` checks the CSS rules, local stylesheets and scripts with no browser: a 0s time moves nothing, a `var()`/`calc()` time is noted and not judged, `@media not (prefers-reduced-motion: reduce)` is the motion branch, and the reduce path is an `@media` query or a `matchMedia()` test, never the words in a comment. Exit 3 names a missing Playwright or a Chromium it can launch (its own, `--browser`/`DESIGN_KIT_BROWSER`, then the installed Chrome) and installs nothing; exit 4 is a page that did not load or did not animate. Standing: gate where run — `scripts/__tests__/motion-check.test.sh`. Not checked: duration of JavaScript-driven motion, a custom property feeding a transform, a JavaScript `pause()` after the recorder took an animation over, motion started by hover or click; seam, overflow, empty-beat and rest stay agent-graded.
- **`dk drift --print-hook`** prints a `PostToolUse` hook for `.claude/settings.json` that runs `handoff-drift.py --scan --ci` on each edited file and hands Claude the drift table (exit 2) on a hit; a clean or unscanned file, a project with no tokens and a malformed payload stay silent. It prints, installs nothing and writes nothing into the project; the snippet names this version's path, so re-run it after an update. Standing: gate — `drift.test.sh` runs the printed command against those payloads.
- **`/design-kit:system` gains a rendered source** (`--source rendered`, `scripts/system-render.mjs`): the page loaded in the project's own Playwright Chromium after its JavaScript ran, computed colours, font families and sizes, padding, gaps and radii of every visible element and of `html` read (an element under an `opacity: 0` ancestor is not visible; margins are not read, since a computed `margin: auto` is a viewport width), colours within RGB distance 8 merged, values on fewer than two elements dropped except the `html`/`body` background, written in `tokens.json`'s shape with `uses` (elements), the colour's `roles` and the elements as sources, plus a new `typography.size` group. `DESIGN-SYSTEM.md` lists dark mode, motion, shadows and components under `## Not read`, never as not found, and `dk system --source rendered` renders once and passes exit 3 and 4 through. Token names are the values (`color.1f2937`), never roles. `--dump-samples` / `--samples` re-cluster a saved read with no browser. The idea is dembrandt's (computed styles to DTCG tokens); no code was copied. Standing: gate where run — `scripts/__tests__/system-render.test.sh`. `dk check` still re-reads the repo, so after a rendered or url run its lines are not drift.

## 0.12.5 — 2026-10-31

- **DTCG Format Module 2025.10 is named as the final report it is.** The README, the `system` skill and `references/tokens-format.md` called 2025.10 a draft carrying "Do not attempt to implement this version". 2025.10 is a Final Community Group Report of 28 October 2025 that says it is intended for implementation. The warning is on the later editor's draft at designtokens.org/tr/drafts/format/. The places `tokens.json` diverges from 2025.10 are unchanged and now complete: colour, dimension and duration values, named easings and shadows stay the strings the source wrote. The README had said "exactly two places", which left out duration, easings and shadows. No change to what the script writes.

## 0.12.4 — 2026-10-28

- **The `system` skill's description now reads in short, plain sentences.** Same sources and outputs; it keeps the words the model matches it on.

## 0.12.3 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `scripts/artifact-bundle.py`, `scripts/board-build.py`, `scripts/codebase-scaffold.sh`, `scripts/deck-build.py`, `scripts/deck-export-pptx.mjs`, `scripts/dk.sh`, `scripts/handoff-drift.py`, `scripts/scaffold-fill.py`, `scripts/serve.py`, `scripts/snapshot.sh`, `scripts/system-extract.py`; `hooks/unread-pick.sh` (shared-block comments): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain. `--help` of `scripts/snapshot.sh` no longer prints the history prose; usage, flags and exit codes are unchanged.

## 0.12.2 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/unread-pick.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-design-kit.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).

## 0.12.1 — 2026-10-26

- **`film.py sheet` tiles start at 0 and the index carries each tile's real time.** It sampled with ffmpeg's `fps=` filter, which picks a frame mid-interval (the first tile of a 16-frame sheet over 6 s was 0.167 s, not 0) and re-stamps frames onto its own grid, so the index's times did not match the pictures a reviewer cites. It now selects the first frame of each interval, frame 0 included, and `index.json` lists `tile_times_s` read from the selected frames. Standing: gate — `film.test.sh`; a mutation back to `fps=` fails it.
- **The five ffmpeg cases now run, with positive cases.** First run with ffmpeg 8.0.1 on 2026-10-26: all pass. `pops` now has to find a one-frame white flash at frame 45, and `cuts` a real cut at 2.0 s in a two-source concat, besides passing a clean clip. CI still has no ffmpeg, so there they skip as before.

## 0.12.0 — 2026-10-26

- **`/design-kit:film` — a product film from a brief.** Demo, launch film, explainer or beat-synced reel rendered from code (HyperFrames by default, Remotion, or hand-rolled `seek(t)` HTML), with music, sound effects or voice, for X, 16:9 or 9:16. The order is the skill: brief with every blank decided and logged, tools checked, facts pulled into `facts.json`, the UI captured at 2x, a 3-second draft render, sound first, three storyboard directions, a style lock from three stills, a build where every value is computed from the frame, review rounds by a fresh blind subagent each round, a muted-viewer test, then delivery with a ledger. Remotion's company licence (for-profit organisations over 3 employees) is asked about before it is chosen; HyperFrames' and Remotion's own agent skills are offered, not restated. Adapted from a "Motion Studio" brief the user supplied, plus pipeline facts from the 703 prompts in [yihui-dev/awesome-opus5-5-videos](https://github.com/yihui-dev/awesome-opus5-5-videos) @92aee2f (MIT list; each prompt belongs to its creator, so none is reproduced).
- **`scripts/film.py`** carries the measurable steps: `doctor` (exit 3 names a missing tool), `music` (a seeded, beat-gridded 48 kHz WAV that writes its grid into `timing.json`), `beats` (tempo, beats and drop of a track; `--verify` holds a grid to within a frame), `peak` (where an effect's peak sits after its file start), `cuts`, `sheet`, `loudness` (two-pass loudnorm to −14 LUFS under −1 dBTP, re-measured after the AAC encode), `pops`, and `check` (every on-screen line traced to `facts.json` with no stray number, holds, cuts and actions on the beat, 4.5:1 text pairs, six colours, the bottom 8%, overlaps, and with `--video` duration, fps, size, H.264/yuv420p, AAC 48 kHz and moov-before-mdat). Standing: gate — `scripts/__tests__/film.test.sh` (19 cases). The five ffmpeg cases skip where ffmpeg is absent and were NOT run where this was written; the beat detector held ten tempos from 60 to 190 BPM within 0.23 frames of the synthesized grid, and without `--bpm-hint` reads a 174 BPM track as half-time.
- **`/design-kit:motion`'s X MP4 opens on the loaded frame.** X shows frame 0 as the thumbnail, so the empty first frame posted a blank card; the seamless loop's window now starts at the rest frame for that file, and the GIFs keep the empty start. Standing: agent-graded.

## 0.11.0 — 2026-10-26

- **`/design-kit:motion` — a static design, alive.** A new skill rebuilds a Figma frame, dashboard, card set or screenshot as an exact stage under `.design-kit/motion/<slug>/`, animates it from the empty state with a story per visual, and exports `<name>-x.mp4`, `<name>-loop.gif` and `<name>-800x500.gif` from a fake-clock Playwright capture through `ffmpeg`; on a website it runs the same stories on bento and feature cards. Frames go in the dot directory `.frames/`, which the preview server neither lists nor watches, and the capture loads `?capture&static=1` so the live-reload stream is not injected. Needs Node with Playwright's Chromium, `ffmpeg`, and a Figma token for a Figma source. Standing: agent-graded — the PSNR, overflow, seam, empty-beat and rest checks are the model's to run; no script captures or encodes yet. Credit: adapted from `design-to-motion` in [elayadesign/ai-design-skills](https://github.com/elayadesign/ai-design-skills) @a2735a3 (MIT, © 2026 Elaya), restructured; unmeasured.
- **Copy that explains the layout is a layout defect.** The design skill's rules now say to cut taglines, helper text and secondary labels and fix the artboard's hierarchy or grouping instead; an input's label, a field's required format, error text and units stay. Standing: agent-graded.

## 0.10.1 — 2026-10-15

- **Runnable `${CLAUDE_PLUGIN_ROOT}` paths are quoted.** The artifact, design, in-codebase and slides skills' `dk.sh`, `handoff-drift.py` and `deck-build.py` lines passed `${CLAUDE_PLUGIN_ROOT}/…` to `bash`, `node` or `python3` unquoted, so an install path holding a space (a `HOME` or `CLAUDE_CONFIG_DIR` with one) split it and the script never ran. Each is now `"${CLAUDE_PLUGIN_ROOT}/…"`. Standing: gate — the marketplace's `validate.sh` fails an unquoted path on a runnable line of a command or skill.

## 0.10.0 — 2026-10-15

- **The board reads oklch, hsl() and rgb() tokens, and says when it maps no colour.** `board-build.py` read a hex accent only, so a Tailwind v4 `@theme` in oklch, which `/design-kit:system` passes through to `tokens.json` as written, drew the board in the default blue without a word, as it did in a real session. The accent now comes from a hex, `rgb()`, `hsl()` or `oklch()` value, and a token file that maps no accent prints `tokens: no colour mapped from <file>` on stderr. The stock Laravel starter kit also needed a `/design-kit:system` fix. Its `@theme inline` sets `--color-primary: var(--primary)` and `:root` sets `--primary` itself; both name the path `color.primary`, so the token came out as the alias `{color.primary}`, pointing at itself. The `:root` value now replaces that self-reference, and `.dark`'s value stays in the token's dark mode. A reference that loops or names an undeclared property is dropped with a `system-extract: … alias dropped` line on stderr, never written as a cycle. Residual: `oklab()`, `lab()`, `lch()`, `color()` and an alias to another token, such as `{color.clay-500}`, still read as no colour on the board. Standing: gate — `board-build.test.sh` runs an oklch `@theme` and a stock-kit-shaped `app.css` through `system-extract.py` into the board, checks sRGB red, green and blue written four ways, and checks the warning. `system-extract.test.sh` checks the dark mode, the dropped cycle and the dropped undefined reference. The oklch and stock-shaped cases fail against 0.9.4.
- **in-codebase renders a Laravel + Inertia app as Inertia.** Every Laravel app got a Blade view and a `Route::view`, which cannot render a React or Vue component. With composer's `inertiajs/inertia-laravel` plus `@inertiajs/react` or `@inertiajs/vue3` installed, `--detect` now prints `stack=laravel-inertia-react|vue`, and `--create` writes `resources/js/pages/__design-kit__/<slug>.tsx` (`.jsx`, `.vue`) and a marked `Route::inertia` line. The page names its own bare layout, because a page-level layout outranks `createInertiaApp`'s default `layout`, which in the starter kits wraps every unnamed page in the signed-in shell. React takes that layout in an array, because Inertia 3 reads a bare arrow there as a layout callback. Laravel's `dev_url` is `.env`'s `APP_URL`, the only key read; it fell back to `127.0.0.1:8000`, which a Herd- or lerd-served site does not answer. A cloned repo's `.env` is untrusted, so the value is assigned and never re-parsed by a shell, and one carrying a quote, `;`, `#`, `$` or a space is refused for `127.0.0.1:8000`. Plain Laravel keeps the Blade path. Residual: the Svelte adapter stays Blade, and an `APP_URL` the app is not served on is printed as is. Standing: gate — `codebase.test.sh` drives React and Vue Inertia fixtures and checks that no other `.env` value reaches the output and that an `APP_URL` carrying `';id>…;#` runs nothing and is refused; that case fails against the pre-fix scaffold, which ran the command.
- **The scratch page's Tailwind classes compile.** dk.sh gitignores `__design-kit__/`, and Tailwind v4's automatic source detection skips gitignored paths, so the page rendered with only the classes used elsewhere in the app. When the entry stylesheet imports Tailwind v4, `--create` now appends one marked `@source` line naming the scratch dir, once; cleanup strips it and `--verify` lists it while it remains. Every appended line keeps the file's own final-newline state. Before this fix, a `routes/web.php` with no final newline had the route joined to its last real line, and cleanup then deleted that route. Residual: Nuxt's stylesheet, and a Laravel entry stylesheet other than `resources/css/app.css`, get no line. Standing: gate — `codebase.test.sh` scaffolds then cleans up and `cmp`s the stylesheet and routes file against the originals, with and without a final newline; a Tailwind v3 stylesheet stays untouched, including one that imports `tailwindcss/utilities` (that case failed against the first cut of this fix). The no-newline routes case fails against 0.9.4.
- design's next-step offer passes the board ref, `/design-kit:in-codebase <board>#board=N`. The pick is consumed by then, so a bare entry found none. The offer marks in-codebase "(Recommended)" only when drift is plausible: no `tokens.json`, a handoff bundle, or a board on the neutral defaults. Otherwise "Build it now" is recommended, because a render that finds no drift is thrown away when the real build starts. Standing: agent-graded.
- **`dk decision --record` dates a line once.** It put today's date in front of whatever it was given, so a line written in the file's own `YYYY-MM-DD — …` shape landed in `design-system/DECISIONS.md` as `- <date> — <date> — board …`, as it did in a real session. A leading `YYYY-MM-DD` followed by a spaced em dash, en dash or hyphen is now dropped and today's date stands. Residual: a leading date with no dash after it stays in the text, and so does a date-named slug such as `2001-02-03-hero.html`. Standing: gate — `dk.test.sh` records a dated line and a date-named slug; the first fails against 0.9.3.

## 0.9.3 — 2026-10-03

- in-codebase says where the scaffold's comments belong: the prop signatures, `gap:` lines and commented-out renders live only on the throwaway `__design-kit__/` page that cleanup removes, and none is copied into the real component. With code-review installed, a full rewrite of that page can be denied for its comment volume (mostly the prop-signature blocks), so the skill tells the model to change it with Edit around them. The scaffold itself is unchanged.
- **Shared-block comments cut to contract and limits; behaviour unchanged.** The shared blocks in `hooks/unread-pick.sh` and `scripts/dk.sh` keep each function's contract and limits in a few lines; the derivations and history moved to the marketplace repository's `rationale/`. Both scripts parse to the same code as before, compared by bash's own parser with comments ignored.

## 0.9.2 — 2026-10-01

- Test harnesses only; nothing an installer runs changed. The local server the system-extract harness starts is now stopped when the harness ends, and the snapshot harness's two server-start failures name a crashed server where they blamed a busy port. The background-server one prints that server's last stderr lines; the review one cannot, because `preview.sh` discards its server's stderr.

## 0.9.1 — 2026-10-01

- The plugin description calls the five entries skills, as the README has since 0.9.0. No behaviour change.

## 0.9.0 — 2026-09-30

- **Off-switches are now `/config` options:** `cc_design_kit_pick`, `cc_remind`, under `/config` (or `/plugin configure design-kit`), each with today's default. The environment variable (`CC_DESIGN_KIT_PICK`, `CC_REMIND`) still overrides its option, and `CC_REMIND` / `CC_BOOST` set in the shell still mute every plugin at once. An interactive `/plugin install` now shows a Configure dialog for these options; it is optional — Esc keeps the defaults.

## 0.8.0 — 2026-09-29

### Changed
- **The five slash entries are now the skills themselves.** `slides`, `design`,
  `in-codebase`, `system` and `artifact` each shipped as a command and a skill of one name,
  and the command hid the skill: `claude plugin details` listed ten skills, and a session
  asked to quote its listing returned the commands' descriptions, never the skills' "Use
  when" lines. The five command files are gone. Each skill now carries the command's
  `argument-hint` and its entry steps as a first `## Entry: /design-kit:<name>` section, so
  `/design-kit:<name> <args>` works unchanged and the listing shows each skill's own "Use
  when" description. Standing: **gate** — validate.sh's `pc_cmd_skill_shadow` fails a
  same-name `commands/<n>.md` + `skills/<n>/SKILL.md` pair (escape `<!-- shadow-ok: <why> -->`).
- **An Entry section runs only when a new deck, board, render, extraction or artifact
  starts.** The model and routing rules now load these skills mid-task with no arguments;
  a mid-task load skips to the next section instead of consuming an unread pick or opening
  a question. Standing: **recorded** — prose the model follows; nothing checks it.
- The design command's "Local twin of the host's `/design`" line was not carried: the
  skill's opening paragraph already said it and now adds "needs no sign-in". That paragraph
  keeps the `<!-- host-ok -->` marker it already had; the command's own marker is gone.
  `design` is not a name the host-overlap check knows, so neither marker silenced anything.

## 0.7.1 — 2026-09-29

### Fixed
- **The snapshot harness no longer fails on a busy port.** Its first review silently used the
  default preview port 8124, so a running design-kit preview or a second copy of the test made
  it exit with `server did not start (port 8124 busy?)`; a port picked free could also be taken
  before the server bound it. Every server start now takes a fresh port and retries up to five
  times. Test-only: nothing users run changed. Standing: **recorded** — 10/10 by hand with 8124
  held and a second copy running; CI runs the harness but never collides a port.

## 0.7.0 — 2026-09-26

### Fixed
- **A `dk-dialog` no longer escapes its artboard.** `.dk-frame` had no `position`, so the
  dialog's `position:absolute; inset:0` resolved against the canvas and the overlay landed
  outside the frame. Found by a headless `/design-kit:design` run on a game brief, which
  patched it in the spec's `css` and reported it (`rationale/2026-09-26-design-kit-game-sim/`).
  The frame is now `position:relative`; `board-build.test.sh` asserts it. Standing: **gate**.

### Added
- **Play primitives and a second accent.** `dk-cells` (a grid of square 44px-floor buttons on
  the radius and spacing knobs), `dk-note` (a designer's annotation inside the frame, for a
  duration, a runtime, a face the board cannot load) and `--dk-accent-2`, 170° from the first
  accent so both follow the hue knob and a colour-blind reader can still tell two sides apart.
  Two headless runs on a tic-tac-toe brief hand-wrote all three; the shell now carries them.
  `board-build.test.sh` asserts they render. Standing: **gate** for presence, **recorded** for use.
- **The design skill says what a game brief diverges on.** First screen (board or pick), where
  turn and result feedback lives (banner, the pieces, the surface), how a result is announced;
  a nav, sidebar, stat tile or data table on such a brief is the primitive set leaking in. Four
  rules the raw-brief run got wrong: a sprite is a character with states, not a glyph; motion
  must read on a still frame (`dk-note` beside a frozen element; Lottie/Rive cannot load); a
  game's real content is names, score, round, winning line and who starts next, not an invented
  timer or lobby; the board cannot show a display face, so name it in a note and decide it in
  the token file. `/design-kit:design` reads "game" and "play" as `phone`. Standing:
  **agent-graded**. Measured n=1 per arm: with the raw ten-word brief the drafter produced a
  CRM with a board in it; with a research-derived brief it produced two drawn characters with
  states on phone frames — and so did the base model with no plugin at all. The brief carried
  the design; the plugin carries the mechanism (knobs, pick channel, gates) and, now, the
  brief-shaped rules a user would otherwise have to type. Re-run once with these rules in a
  clean fixture, the raw brief drew two characters with states on phone frames using the new
  primitives — one run, so a landing, not a delta.

## 0.6.1 — 2026-09-26

- The four meta-bundles (core-, frontend-, craft-, workflow-suite) were retired on 2026-09-26; install through `all-plugins` or `/stack-scan:suggest`. The `system` skill's install hint names design-kit directly instead of the retired `craft-suite`.

## 0.6.0 — 2026-09-25

- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

### Fixed
- **The unread-pick nudge reads the phase sentinel and the board at the project root, not
  wherever the shell had `cd`'d to.** The hook's payload `cwd` follows the model's `cd`
  (finding 2 of `rationale/2026-09-25-session-plugin-usage-review.md`, in the marketplace
  repository), so a `build` phase declared at the root was invisible from `app/Models` and
  the nudge spoke through it, and a board built at the root went unannounced after a `cd`.
  It now resolves the git root (outside git, `CLAUDE_PROJECT_DIR` when the cwd is under
  it) and reads `.claude/cc-phase.json` and `.design-kit/decisions.jsonl` there, and only
  there. A stray `<subdir>/.design-kit/` left by an older `dk.sh` is no longer announced:
  `dk decision --consume` could never clear it, so the line would repeat on every prompt.
  The harness gained the subdirectory-cwd cases.
- **`.design-kit/` lives at the project root, whichever directory the shell is in.**
  `dk.sh` wrote `./.design-kit`, so a verb run after the model had `cd`'d into `src/` built
  a second one there, with its own board, decisions and usage log. The unread-pick hook
  never saw it, and `dk decision` run from the root never saw it either. `dk.sh` now
  resolves the root with the same shared state-root block the hook uses, and exports
  `DESIGN_KIT_DIR` so every script it runs writes there. Run on their own, `deck-build.py`,
  `board-build.py`, `artifact-bundle.py`, `deck-export.sh` and `snapshot.sh` fall back to
  `.design-kit/` at the git toplevel. At the root every printed path is unchanged; from a
  subdirectory it is absolute. An explicit `DESIGN_KIT_DIR` is still used exactly as given.
  The `.gitignore` block stays root-relative. `dk review --base <git-ref>` now reads the
  committed shots from the toplevel: `git archive` refuses a path outside the cwd, so from
  a subdirectory it found none. `dk --help` no longer writes the `.gitignore` block before
  printing. `design-system/` is not anchored: `dk check` and `dk decision --record` still
  read the shell's directory. Standing: **gate**. `dk.test.sh` runs board, slides,
  decision, a standalone `deck-build.py` and an explicit override from a subdirectory.
  `snapshot.test.sh` runs a review from one, with a directory base and with a git-ref base.
  `unread-pick.test.sh` checks that the stray board stays silent.

### Added
- **`dk snapshot --storage-state <file>`: before/after behind a login.** Until now a route
  behind a login shot the login page, so none of the authenticated apps in the measured
  sessions could get a before/after. The file is a Playwright `storageState` JSON (cookies,
  plus localStorage per origin), saved once from the walk user's sign-in and never from the
  user's own account. The README's "Behind a login" gives a one-call save for the
  Playwright MCP browser. That call keeps only the app's cookies: a plain `storageState()`
  from a browser attached to a real profile saved 48 cookies of the user's own sessions
  beside the app's one. The CLI screenshot cannot take a cookie, so this path drives the
  same Chromium browser over the DevTools protocol on a pipe (python3 stdlib only). It
  settles in real time: the load event, then 500 ms of network quiet, at most 3 s. A route
  that ends on another URL (a sign-in redirect, an expired session) is still shot, with a
  `WARN` naming where it landed. A file holding cookies for other hosts draws a `WARN` too.
  **A state file inside a git work tree that git does not ignore is refused with exit 1**,
  and a tracked file never counts as ignored: it holds a live session token. Keep it under
  `.design-kit/` or outside the repo. Standing: **gate** for the refusals (missing,
  malformed, empty, un-ignored, tracked). With a browser installed, the harness shoots a
  cookie-guarded route where the server logs the cookie and the seeded localStorage, and an
  expired session that must `WARN`. Run by hand once on 2026-09-25 (Chrome 153, Playwright
  MCP): signed in through a form on a throwaway app, saved with the README call (2 cookies
  plus localStorage), then `dk snapshot` from `app/Models` shot the signed-in dashboard at
  1440 and 390. Not carried: sessionStorage, IndexedDB, HTTP auth headers.

## 0.5.0 — 2026-09-22

### Added
- **`dk snapshot` and `dk review` — the before/after this plugin could not show.** Every
  surface here produced a picture of a design and none of them could show what a change
  did to a screen: the only shots taken anywhere were the current-state ones a craft gate
  writes, with nothing to compare them to. `scripts/snapshot.sh` adds
  `dk snapshot [--routes …] [--device desktop|mobile|both] [--base-url …] [--out …]`,
  which loads each route in the Chromium-family browser `board-export.sh` already locates
  (asked for as `board-export.sh --which`, so the discovery and its install hint stay in
  one place) and writes `<out>/<device>/<route-slug>.png` under
  `.design-kit/shots/<git short sha, else a UTC timestamp>/`; and
  `dk review --base <dir|git-ref>`, which pairs the newest shot set against that base and
  writes `.design-kit/reviews/<pair>.html` — before | after | a pixel-diff heatmap per
  route — served on the same preview URL, with one table row per route carrying the
  changed-pixel percentage. A second shoot at the same commit writes `<sha>-2` rather than
  over the set you are about to compare against. The heatmap and the percentage need
  `python3` with Pillow; without it the page shows the pair alone and every row reads
  `no diff engine: install Pillow`. No hook, no command, no threshold.
  Standing: **gate** for the exit codes and the pairing — `0` shot/rendered, `1` bad
  arguments, `2` browser or server unreachable, printed as `NOT MEASURED` and never as
  "no change"; `scripts/__tests__/snapshot.test.sh` drives the argument errors, that
  exit, both diff-engine branches, the pairing over fixture PNG dirs, and one real shoot
  when a browser is installed, saying so when there is none. Reading the pair is
  **agent-graded**: nothing here asserts a pixel. Not covered: auth flows, per-component
  crops, settling past one 3 s budget, device emulation beyond the viewport size.

## 0.4.0 — 2026-09-22

### Added
- **`dk drift` — the literal-colour check on the project's own components.** Until now the
  only drift reader ran on an imported handoff bundle; `dk check` compared `tokens.json` to
  its own re-extraction, and the palette nag fired once a session on nine hexes. A component
  hardcoding `#6366f1`, or reaching a colour through `bg-indigo-500`, went unseen by all
  three — the named palette utility never reaches a stylesheet, so every token-reading check
  stays green over it. `handoff-drift.py` gained a `--scan` mode over
  `.tsx/.jsx/.vue/.blade.php/.css/.scss` sharing the bundle mode's token reader, and
  `dk drift [PATHS|--staged|--diff <base>] [--ci]` drives it. `--ci` exits 1 on any hit; no
  token source anywhere exits 2 (`not measured`), never a green; an empty `--staged`/`--diff`
  selection scans nothing rather than the whole tree. `bg-primary` and `var(--primary)` are
  clean by construction, a `--name:` declaration line is the token being defined and never a
  hit, and `href`/`to` values are blanked so a `#dad` anchor is not read as a colour.
  Standing: **gate where you wire it** — nothing in this plugin runs it for you, so not run
  is not clean; `scripts/__tests__/drift.test.sh` drives hit, clean, both exits and the git
  selectors, and CI runs it with every other plugin harness.

### Fixed
- **`hooks/unread-pick.sh` starts `#!/bin/bash`.** A hook that promises to fail open cannot
  depend on `/usr/bin/env` resolving: on a stripped PATH the kernel returns 127 before the
  fail-open code runs.

## 0.3.0 — 2026-09-22

### Fixed
- **`hooks/unread-pick.sh` could fail on every prompt, and could be muted forever by a run
  that died.** It was the only hook in the marketplace carrying `set -euo pipefail` and it
  called `python3` unguarded, so a machine without `python3` on PATH got rc=127 on each
  prompt. It also hand-rolled the phase-sentinel read: no TTL, no `session_id` check, and a
  hardcoded `build|verify|review|ship` list that let it speak through `plan` while its own
  `lane.tsv` row claims `decide`. It now guards `python3` like `jq`, drops `set -e`, and runs
  the marketplace's shared phase guard against its OWN `lane.tsv` row, so the phase list
  cannot drift from the declaration. `unread-pick.test.sh` gained the two probes:
  python3 off PATH → exit 0, silent; a dead session's sentinel aged past the 120-minute TTL
  → the hook speaks again and the stale file is unlinked.

### Added
- **design-kit is in a bundle.** It joined `craft-suite` (0.8.0) alongside craft-layer and <!-- removed-ok -->
  ui-ux, which had zero references to it between them, and craft-layer's Reuse map now names
  the two moves it owns: pre-build artboards, and the extracted `design-system/` record.
- **A DTCG interop paragraph in the README.** Names the Format Module 2025.10 draft, the two
  places `tokens.json` deviates from it (colour and dimension stay the strings the source
  wrote), and Tokens Studio and Style Dictionary as the consumers that read this structure
  and need those two forms converted. The "Figma import or export: not in this release" line
  now points at it instead of reading as a dead end.
- The `system` skill says in one line that it RECORDS values and `/ui-ux:theme` GENERATES
  them, which is the next move when the `## Not found` list says the source has no palette.

### Changed
- `/design-kit:in-codebase` glosses what the "scratch entry" consent actually buys at the
  point of the ask, rather than offering an undecodable label.
- Two more steps route through `dk.sh` (`scratch --detect`, `export`). The README's claim of
  "one permission rule" is corrected rather than repeated: four steps deliberately call a
  script directly because `dk` has no verb that does only what they need, and the README now
  names all four and the second rule they draw.

## 0.2.0 — 2026-09-22

The experience pass after the simulation (`rationale/design-kit-experience-ideas-2026-09-22.md` ideas 1–4, 6).

### Added
- `scripts/dk.sh`: one entry point for every surface (one permission rule); `.design-kit/workshop.json` state so commands default their next step; `.design-kit/usage.jsonl` per verb; `dk status`; `dk check` before every command.
- Decision channel: the board posts picks, knobs and text edits to the server's loopback-only `/_decision` route; `dk decision --latest --consume` reads them back as the copy-as-prompt prose; `dk decision --record` appends to tracked `design-system/DECISIONS.md`; a UserPromptSubmit hook names an unread pick in one line (`CC_DESIGN_KIT_PICK=off`).
- Gallery: flow strip and a per-page token badge (green current / amber moved) from the `design-kit-tokens` stamp; `_index.json` carries it.
- `/design-kit:system`: writes `design-system/components.json` (typed props, defaults, required flags, variants, stories, honest `gaps`); `--check` compares a fresh extraction against the committed tokens and exits 1 with one `check:` line per moved token.
- `/design-kit:in-codebase`: the scratch page is pre-filled from components.json — stylesheet, alias-aware imports, prop signatures, a variant strip with required props filled or commented out, a `gap:` comment per extractor blind spot.
- Every deck, board and artifact is stamped `design-kit-tokens` (tokens sha12 + git revision).
- Measured: skill-router rows for every surface and `scripts/dk-usage.sh` (created / revisited / picked / rendered / exported / shared / followed-by-commit per project); the README states the kill trigger as a number — 30 days after 0.2.0, ≥3 projects, followed-by-commit = 0 and shared = 0 → retire.

### Fixed (second simulation, a Laravel Blade fixture)
- `/design-kit:system`: a Blade view without `@props` that is the template of a class component now takes its props from `app/View/Components/<Name>.php`'s promoted constructor parameters, with types.
- `/design-kit:in-codebase`: a required Blade prop with no declared type is filled from the brief instead of commenting the component out; the scratch page wraps in `<x-app-layout>` only when the project defines one, otherwise it is a standalone page carrying the layout's `@vite` directive.

### Added (scratch hygiene)
- The first `dk` verb inside a git repo appends a managed `.gitignore` block for `.design-kit/` and `__design-kit__/`; never for a path with tracked files; `DESIGN_KIT_IGNORE=off` skips it.

### Changed
- The server's contract: "no write route" became one loopback-only, header-gated, append-only route; export and publish stay scripts.

## 0.1.0 — 2026-09-22

### Added
- First release: five commands mirroring the Claude Desktop design picker as local
  files — `/design-kit:slides`, `/design-kit:design`, `/design-kit:in-codebase`,
  `/design-kit:system`, `/design-kit:artifact` — plus the plugin's own preview server
  (`scripts/serve.py`: gallery, live reload, `--lan`) and a harness per script.
- `/design-kit:slides`: outline → self-contained HTML deck with notes, overview and print CSS; PDF via a local Chromium-family browser, editable PPTX via consent-gated pptxgenjs; the builder gates the 6-line rule and self-containment.
- `/design-kit:in-codebase`: render a design with the project's own components on its dev server (Vite React/Vue, Next, Nuxt, Laravel) behind a consent gate, with marked scratch files a verify-gated cleanup removes; Claude Design handoff bundles get a colour/font drift table against the repo's tokens first.
- `/design-kit:artifact`: one self-contained HTML artifact from a page, markdown, folder or brief — bundled and versioned by script into a local gallery; LAN, pages-branch (dry run, then `--push` on a second yes) and zip sharing, each behind a question.
- `/design-kit:design`: local artboard board (2–4 directions, editable text, adjustment knobs, pick-and-copy prompt) with `board-build.py` gates and `board-export.sh` PNG/PDF.
- `/design-kit:system`: extract tokens, typefaces and a component inventory from a repo, URL or brand folder into `design-system/` (DTCG-shaped `tokens.json` with sources and dark modes, `DESIGN-SYSTEM.md` with the host-readable block, an `@dsCard` UI-kit page); deterministic, harness-gated.
