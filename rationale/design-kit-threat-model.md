# design-kit's preview server: threat model

For design-kit 0.20.2, written on 2026-11-25, revised twice that day after reviews and again on
2026-11-26, for the people who install the plugin and for whoever changes it next. It says who may
attack, where the boundaries are, what is isolated, what is not, and what you can do about each
thing that is not.

**Standing of this file: recorded.** `dk.test.sh` fails when a row below goes missing, has no single
disposition or standing, or names a harness that is not there. No script checks that a sentence is
true. Each row has a standing of its own: **gate** (a script fails the build; the harness named is in
`plugins/design-kit/scripts/__tests__/`), **agent-graded**, **recorded**, or **unenforceable**.
`attack.test.sh`, `viewer.test.sh`, `frame.test.sh` and the browser halves of `check.test.sh` and
`dk.test.sh` drive a Chromium-family browser; with none they say so and pass, unless
`DESIGN_KIT_REQUIRE_BROWSER=1`.

**Who accepted what.** *accept, owner*: the marketplace's owner accepted it, on 2026-11-24 when the
design was approved or when it was found, or on 2026-11-25, from the list of what was found while
0.20.0 was built and reviewed, or on 2026-11-26 for what the keyboard stop leaves, a page that focuses on hover and a page's own `scrollY`. *accept, run*: it was found later or widens what was accepted; the
release ships with it, and it is **open**.

## What is protected

- **Your words.** A pick, a note and a host approval are read as your choice, by the session or the server.
- **What the pages hold**, and the notes, check results and screenshots beside them; signed-in session
  files under `auth/` (never served).
- **This machine and its network**, which a page's script could otherwise reach from your browser.
- **The viewer**, the one place on the screen that speaks for the plugin.

## The attacker

- **Page content.** A page is written by a model, pasted, or holds a third-party script. It is assumed
  hostile, and assumed to know this file.
- **Another website** open in the same browser, with a DNS name it can point at 127.0.0.1.
- **A device on your network** while `--lan` runs.

Out of the model: malware that runs as you, other users of this machine, and browser bugs. Each can
already do more than anything here could stop: read and write the folder, or post to the loopback
port as the viewer does.

## Boundaries

A page runs in a sandboxed frame with an origin of its own (`null`) under a policy the server sends.
The viewer, on the server's own origin, frames it and takes its messages. Only the viewer posts.

```
page --messages--> viewer --post, on your press--> server --rows--> session (dk decision, dk notes, the hook)
page --requests--> other hosts (none until you allow one)
another website, a phone --HTTP--> server
```

- **frame → viewer**: the messages a page sends, all taken as claims.
- **frame → control origin**: a page's reach to the server's own pages, files, routes and storage.
- **frame → network**: a page's reach to any other machine.
- **frame → user**: what a page shows you, and what you press.
- **frame → session**: what a page could make the session read as yours.
- **web → loopback**: another website's requests to 127.0.0.1.
- **LAN → server**: another device's requests.
- **docroot → server**: the files and links the server opens.
- **disk → session**: rows and names that `dk` and the hook read back.
- **raw page → machine**: a page opened with no viewer (`?static=1`, `dk check`, `dk notes --shot`).
- **file page → machine**: a page opened from a file or from somewhere else (`dk export`, a shared copy).
- **old page → control origin**: what a page of 0.19.3 or earlier left in your browser.
- **our own parts**: the viewer, the launcher, `dk` and the server between themselves. No attacker,
  but what you send can be lost or doubled.
- **out of the model**: see The attacker.

Entry points: the page URL, `/_gallery`, `/_index.json`, `/_page`, `/_events`, `/_notes`, `/_checks`,
`/_c/…`, `POST /_decision`, `/_note` and `/_allow`, the ten message types of the frame, the query and
hash of a page URL, every file in the folder, `.allow.json`, and the ports 8124 to 8139.

## Threats and dispositions

In the order of what they would cost you.

| Threat | Boundary | Disposition | Standing, and what holds it |
|---|---|---|---|
| A page plants a pick, a note or a host approval that the session or the server takes as yours. | frame → session | mitigate | gate: attack.test.sh (21 ways of posting, none reaches a write route, no file is written), viewer.test.sh (only your press sends, one row a send), picks.test.sh and dk.test.sh (a row is clamped, printed as one line of data, confirmed only with `v:2`). |
| A page steals your press on Send pick, Send note, Allow or Open. | frame → user | mitigate | gate: viewer.test.sh (a click, Enter and Space do nothing for 600 ms after a strip, a drawer or a Network row changes, the strips scroll, or the window is resized, shown or focused; a swapped pick is marked Updated and waits again). |
| A page reads or rewrites another page, the gallery, the notes, the checks, or the preview address's cookies, storage and databases. | frame → control origin | mitigate | gate: attack.test.sh (10 ways to storage and the viewer, 21 to another page, a picture or a route; each works with no sandbox), serve.test.sh and isolate.test.sh (a token opens one page in one mode, files by folder). |
| A page sends what it holds to another machine over HTTP. | frame → network | mitigate | gate: attack.test.sh (every kind of load, six self navigations, seven top navigations: 0 requests at a second server, and all of them arrive with no policy). |
| A page gets a host approved that is this machine or its network. | frame → network | mitigate | gate: isolate.test.sh (IP addresses in every notation, ports, wildcards, http, `localhost`, `.local`, `.internal` and `.home.arpa` are refused, again at each read), serve.test.sh (only a loopback post with its own header). |
| Another website reads the preview, embeds its files or posts to it, through a rebound DNS name included. | web → loopback | mitigate | gate: serve.test.sh (`Host`; `Origin` of the write routes, `/_page`, `/_notes` and `/_checks`; `Sec-Fetch-Site` of `/_page` and of a raw page; embedding headers), attack.test.sh (a page on another local origin can load no script or image of it). |
| Another device on the network reads without the key, or records anything. | LAN → server | mitigate | gate: serve.test.sh (key, cookie, the three write routes), viewer.test.sh (no notes, composer, Send or Allow there). Both use this machine's own network address and skip that half without one. |
| A page takes the tab to another site, or opens a tab on your plain click (the second in Chrome only: see Residuals). | frame → user | mitigate | gate: attack.test.sh, viewer.test.sh (the stopped area). |
| A page goes fullscreen and draws over the bar. | frame → user | eliminate | gate: viewer.test.sh (`requestFullscreen` in the frame is refused). |
| A page forges or floods the messages between frame and viewer. | frame → viewer | mitigate | gate: viewer.test.sh (another window, a nested frame or a wrong shape changes nothing; at most 50 a second act; a forged Escape or link leaves your draft), attack.test.sh. |
| An SVG, XHTML or XML file runs script on the server's own origin. | frame → control origin | mitigate | gate: serve.test.sh (its sandbox policy), attack.test.sh (its script does not run). |
| A page leaves a service worker on the preview address. | frame → control origin | eliminate | gate: attack.test.sh (refused in the frame), serve.test.sh (a worker's script is 404), viewer.test.sh (the viewer unregisters one it finds). |
| A path or a symlink leads the server out of the folder, or to a session or state file. | docroot → server | mitigate | gate: serve.test.sh, isolate.test.sh. |
| A pick an older page or server left reads as your choice. | disk → session | mitigate | gate: picks.test.sh, dk.test.sh, unread-pick.test.sh (unconfirmed without `v:2`, its own prompt never printed). That the session then asks you is agent-graded. |
| A board file name, up to 128 characters of prose, reads as words of the plugin in the summary or the fixed prompt. | disk → session | mitigate | gate: picks.test.sh, dk.test.sh, serve.test.sh (one quoted ASCII JSON string). Its words still reach the session, in the quotes: that it treats them as a name is agent-graded. |
| A name planted on disk (system stamp, board, scratch, artifact, deck, preview address, LAN key) imitates a status step of `dk status`, or a line of another verb. | disk → session | mitigate | gate: dk.test.sh (each is one ASCII JSON string; so are an address not of the launcher's form, in `dk status`, `dk serve` and the launcher's own line, and a LAN key not of the server's form, in `dk serve --lan`). |
| A page being checked or shot reaches the network, saves a download or answers for the check. | raw page → machine | mitigate | gate: check.test.sh (refused loads, downloads, WebRTC, a page that replaces `Math.max`, a previous version that reaches no service of this machine), dk.test.sh (a download, a page that answers for the DOM). What it can still reach is below. |
| Posts fill the disk, one send is recorded twice, or a send lands in another project that took the address. | our own parts | mitigate | gate: serve.test.sh (body limits, 2 MiB a file and then 507, one row a send, 409 to a post naming another project), viewer.test.sh (every write names its project; on another project's server nothing is recorded and the strip says so). |
| Malware that runs as you, other users of this machine, browser bugs. | out of the model | accept, owner | unenforceable: nothing here tells such a program from you. |

## Residuals

What is left open, and what you can do about it.

| What is left | Boundary | Disposition | What you can do | Standing |
|---|---|---|---|---|
| `dk export` runs a page's script from a file with no browser sandbox and an open network. | file page → machine | accept, owner | Export only a page whose script you trust, or print it from the viewer (P in a deck, Ctrl+P) and save as PDF. | recorded: both export scripts pass `--no-sandbox`; a later milestone. |
| A service worker left by a page up to 0.19.3 can answer navigations and fake the viewer. | old page → control origin | accept, owner | After the update, clear site data for the preview address once, at each address and port you used; knobs and page data saved there go with it. | recorded: new ones are refused and found ones removed (see above), but one that answers the viewer's own address runs first. |
| An approved host receives whatever the page writes into a request's address, and the approval outlives a rewrite of the page. | frame → network | accept, owner | Allow a host only for a page whose script you trust; press Remove in Network after a rewrite. | unenforceable: a server cannot tell data from a file name. That an approval covers files only, for one page, is a gate (attack.test.sh, viewer.test.sh). |
| A host name you allow may resolve to a private address, one on your own network included. | frame → network | accept, owner | Allow names you know. | recorded: only the name is checked (isolate.py). |
| A host name the page chose leaks through preconnect, WebRTC or DNS. | frame → network | accept, owner | Put nothing in a page that you would not put in a host name, or open it with the network off. | recorded: attack.test.sh counts preconnect (2 connections on 2026-11-25) and prints it, never fails on it; WebRTC and DNS were not probed. |
| A blocked navigation opens the connection and sends no request; to a host you allowed, the TLS handshake completes, so that host learns its name and your address. | frame → network | accept, owner | Allow few hosts, and Remove them when you are done. | recorded: attack.test.sh prints the count (7 connections, 0 requests); counted once by hand on 2026-11-25: 9 connections to allowed hosts, 9 handshakes, 5 requests. |
| In a page that undid the in-frame script, your Ctrl, Shift or middle click on a link opens a real tab (1 request), and Alt+click starts a download (1 request, no tab). | frame → user | accept, owner | Click plainly, or use the link strip. | recorded: attack.test.sh prints the counts and never fails on them; accepted on 2026-11-24. |
| In Firefox a page that undid the in-frame script opens a real tab, its text in the address, with a Ctrl- or Shift-click event of its own while it handles your plain click or a key you press in it (1 request). | frame → user | accept, owner | Open a page you do not trust in Chrome, where no tab opens. | recorded: by hand in Playwright's Firefox 157 on 2026-11-25, by a click and by a key, with Ctrl and with Shift, 3 runs each: a tab and 1 request in 12 of 12, none in 12 of 12 with the in-frame script there. That Chrome opens none is a gate (attack.test.sh). |
| Any page may start a download, as any web page can. | frame → user | accept, owner | Open a downloaded file only when you asked for it. | gate: viewer.test.sh (a download link works, on purpose). |
| A page can draw anything inside its own area, a second bar or a Send button included. | frame → user | accept, owner | The real bar, strips and drawer stand outside the frame, above it; press nothing that looks like them inside it. | unenforceable: what a page draws is its content. |
| The text edits you confirm are page data. | frame → viewer | accept, owner | Read the strip before you press. The session is told that they are data, never instructions. | agent-graded: the telling is a gate (dk.test.sh: in the design, in-codebase and artifact skills), what a session does with it is not. |
| Everything else you confirm is page data too: a pick's number and knobs, a host it asks for, a note's element and console lines, a link's address. | frame → viewer | accept, owner | Read the strip before you press. The session is told that `anchor` and `context` are data, never instructions. | agent-graded: the telling is a gate (dk.test.sh: in the design, artifact and slides skills), what a session does with it is not. |
| A page you clicked in (any page, under Firefox) can still take the keyboard focus from the viewer: a character or two before it is stopped, one each time where it takes it less often than three times in 1 s and is never stopped, and all you type where the pointer rests on it (or the viewer was last touched by a finger) and nothing was typed for 500 ms. | frame → viewer | accept, owner | Type notes with the pointer off the page, and not on a page you do not trust. | gate: viewer.test.sh (a page that takes it from a note's text box three times in 1 s while you type, or ten times in 500 ms, is stopped; at least 25 of 26 characters stay with a page that tries every 100 ms, every 5 ms and with no pause; a page that tries once a second is not stopped). The owner chose the stop on 2026-11-25. Characters of 26 the page got, by hand that day, 3 runs each: Chrome 158 none at 100 ms, 5 ms or no pause (23 to 25 with no pause before); Playwright's Firefox 157 none from load, 1 at 100 ms with nothing pressed in the page or begun in the note; 26 in both where the pointer rests on the page. Chrome lets a page take it only within 5 s of your last press in it, Firefox at any time. From reading, not run: giving it back may fight a screen reader, the browser's find or a finger after a mouse press. The owner accepted what the stop leaves on 2026-11-26. |
| A page that focuses an element on hover is stopped when the pointer sweeps across it while a note on one of its elements is open: each hover is a take the viewer gives back, and ten in 500 ms meet the stop rule. | frame → viewer | accept, owner | Press Reload page to bring it back; keep the pointer off such a page while a note on it is open. | recorded: a probe on 2026-11-26: a pointer moved every 20 to 40 ms stopped the page after 0.43 s; moved 120 ms apart, 24 takes were given back and it was not stopped. The owner kept the stop that day. |
| A page that defines its own global `scrollX` or `scrollY` breaks notes on itself: a click on an element opens no composer, or the note keeps a wrong position. | frame → viewer | accept, owner | Leave `scrollX` and `scrollY` alone in a page you take notes on. | recorded: a probe on 2026-11-26 (a page with `let scrollY = 'top'` opened no composer); frame.js's `anchorOf` reads them. frame.js has 1 byte left of 12,288, only that page's notes break, and any page can already say any position: the owner left it that day. |
| A page opened raw by hand (`?static=1`) has no viewer around it and can navigate itself away with data in the address. | raw page → machine | accept, owner | Do not type `?static=1` on a page you do not trust. | recorded: run once by hand on 2026-11-25 (1 request to a second server; its posts to the write routes wrote nothing). |
| A page under `dk check` or `dk notes --shot` has no viewer around it either; behind a dead proxy it reaches 127.0.0.1 alone, by its own navigation with data in the address (a GET), by preconnect (an empty connection) and by TURN over TCP. | raw page → machine | accept, owner | Check or shoot only a page whose script you trust while a service of yours listens there. | recorded: run once in Chrome 158 on 2026-11-25, under `dk check`. The dead proxy is a browser flag in render-check.py; that WebRTC's UDP does not pass it is a gate (check.test.sh). |
| A motion or film recording opens the page raw in the project's own Playwright, with the network open: the page can navigate itself away with data in the address, and one given as a file has no policy at all. | raw page → machine | accept, owner | Record only a page whose script you trust. | recorded: motion-check.mjs, run once on 2026-11-25 on a page at its `static=1` address: the page's navigation reached a server at this machine's network address (1 request, its text in the address), its fetch did not, and in the check's browser neither did. The file and a film capture are from reading, not run. |
| The sandbox and the policy are headers, and headers do not travel: a zip, a pages branch, a PDF or a saved copy carries none. | file page → machine | accept, owner | Share a page only when you would let its script run as any website's. | recorded: README says so, and dk.test.sh checks that it does. |
| The LAN is plain HTTP: the key, the pages and their content addresses cross it in the clear, and a framed page opened top-level there leaves by the in-frame script, not by a header. | LAN → server | accept, owner | Use `--lan` on a network you trust and only while you need it; it ends itself after 60 minutes. | unenforceable: without TLS. The leaving is a gate (viewer.test.sh), and so is the time limit (preview.test.sh). |
| Whoever holds a content URL (`/_c/…`) reads that page and its files with no key until the server stops. | LAN → server | accept, owner | Do not paste one; `dk serve --stop` ends them all. | gate: serve.test.sh (a valid one is served with no cookie, any other meets the key). |
| A row planted on disk in `decisions.jsonl` with `v:2` reads as confirmed. | disk → session | accept, owner | Treat that folder as you treat your source; check a pick that surprises you against the board. | gate: picks.test.sh (`v:2` is all that confirmed means). |
| A hard link to a never-served file is served. | docroot → server | accept, owner | Make none in the folder. | recorded: 200 on 2026-11-25; a symbolic link to one is refused (gate: serve.test.sh). |
| A symlink swapped between the check and the open is followed. | docroot → server | accept, owner | It takes a program that writes to the folder, which is out of the model. | recorded: isolate.py's header; no harness drives it. |
| A page that never stops computing keeps its Chrome process: Reload page answers only when the loop ends. | frame → viewer | accept, owner | Close the tab, or end the page in the browser's task manager. | recorded: seen while it was built; no harness drives it. |
| A page that opens dialog after dialog keeps Send and Discard shut. | frame → user | accept, owner | Take the dialogs out of the page and save it; the unsent pick stays in the tab. | recorded: seen while it was built; no harness drives it. |
| A key pressed in the page, or an element picked for a note, acts up to 1.5 s late while something can be sent or the Sent line shows. | frame → viewer | accept, owner | Wait, or press the button in the bar. | gate: viewer.test.sh (a page that floods reports changes the strips at most once in 1.5 s). |
| A page that floods the viewer with messages takes its time and the processor's. | frame → viewer | accept, owner | Close the tab. | recorded: at most 50 a second act (gate: viewer.test.sh); reading the rest costs time. |
| No page can go fullscreen, a deck or a game of yours included. | frame → user | accept, owner | Use the browser's own fullscreen (F11). | gate: viewer.test.sh. |
| Print in the browser's menu prints the viewer, not the page. | frame → user | accept, owner | Press Ctrl+P or Cmd+P, or P in a deck: those print the page. | recorded: the keys are a gate (viewer.test.sh), the menu is the browser's. |
| Each tab has its own pick strip, so two tabs of one board can each send a pick. | our own parts | accept, owner | Keep one tab for a board; `dk decision --latest` reads the last one sent. | recorded: no harness sends a pick from two tabs. |
| Saved knobs and page data belong to one address: a project that moves to another port starts empty there. | our own parts | accept, owner | Set `DESIGN_KIT_PORT`. The launcher says when it moved; the old address keeps the data. | gate: preview.test.sh (the line it prints). |
| A 0.19.3 session on the new server marks picks read without the lock and shoots notes without an outline. | our own parts | accept, owner | Update the plugin, then restart every open session. | recorded: read in 0.19.3's `dk.sh` (no lock around the rewrite, `?_outline=`), not run. |
| A half-typed note is lost at a tab reload. | our own parts | accept, owner | Send it first. A save of the page, a server restart and closing the drawer keep it. | recorded: viewer.js's header; what keeps it is a gate (viewer.test.sh). |
| A send repeated late is recorded again: its `cid` is looked for in the file's last 50 rows. | our own parts | accept, owner | Dismiss the second of two equal notes; the last of two equal picks is the one read. | recorded: one row a `cid` within those rows is a gate (serve.test.sh). |
| Writes go unlocked on a host without `fcntl`, or where the lock file cannot be opened: a send and a read at once can lose a row. | our own parts | accept, owner | Send again when a pick or a note does not arrive. | recorded: where the lock works, 20 posts racing a reader lose no row (gate: dk.test.sh). |
| The 50 ms wait that gives Chrome's frame its size is timing, not a guarantee: a page's first script may see 0 by 0. | frame → viewer | accept, owner | Reload the page. | gate: viewer.test.sh (8 loads of 8); 9 of 24 failed without the wait on 2026-11-24. |
| Two launches racing for a port may both run, the first unrecorded, when the second comes before the first has written its record. | our own parts | accept, owner | Run `dk serve --stop`, end the other `serve.py`, start once. | recorded: preview.sh's header. That a launch which meets the other's record waits for its server is a gate (preview.test.sh). |

## After the update to 0.20.0

1. Clear site data once for each address you opened the preview at (`http://127.0.0.1:8124`,
   `http://localhost:8124`, the LAN one). It also drops the knobs, page data and
   unsent picks kept there, so take what you still need first.
2. Restart every open session, so that none runs 0.19.3 against the new server.
3. A page that loads a CDN's script, font or image now asks: press Allow for this page, or inline the file.

## STRIDE

- **Spoofing**: a planted pick, note or approval; a drawn bar; a worker that fakes the viewer.
- **Tampering**: another page, the gallery, `.allow.json`, a row on disk.
- **Repudiation**: a row says when, which send and which board, never who. Nothing proves that you
  pressed Send, and a planted `v:2` row looks the same: that is accepted above.
- **Information disclosure**: HTTP out of a page; preconnect, WebRTC, DNS; an approved host; a tab a
  page opens in Firefox; what you type in a note while a page takes the focus; the LAN key and content
  addresses in the clear; another website.
- **Denial of service**: floods, endless loops, dialogs, full files, a full browser store.
- **Elevation of privilege**: a press stolen for a consent button; a file opened on the control origin;
  an export with no sandbox.

## Not probed

Safari and stock Firefox. A second device on the LAN (this machine's own network address stands in).
WebRTC and DNS lookups. Speculation rules and WebTransport. A link's context menu, a drag, Ctrl+Enter.
Raw `?static=1` as an attack, beyond the runs of 2026-11-25 above. What a screen reader says, and
whether giving the focus back fights it, the browser's find or a finger after a mouse press. In
Playwright's Firefox build, hand runs only: `rationale/derivations/plugin-design-kit.md` says which.

## When to walk this again

Before any new route, message type, stored file or page capability: live updates, versions, threads,
saved state, richer pages and a mod are planned, and each adds an entry point. Why the code is as it
is: `rationale/derivations/plugin-design-kit.md`, the sections of `serve.py`, `isolate.py`, `picks.py`,
`frame.js`, `viewer.js` and `note-shot.py`. The installer's summary: `plugins/design-kit/README.md`,
"What a page can and cannot do".
