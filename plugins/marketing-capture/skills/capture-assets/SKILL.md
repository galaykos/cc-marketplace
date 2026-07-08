---
name: capture-assets
description: Use when a working app or repo needs marketing screenshots and a demo GIF of the REAL running product — actual screens, not mockups. Auto-detects an available browser backend, gets the app on screen, asks consent up front naming exact artifacts, shoots a user shotlist, frames each screenshot into a marketing image, and records a native-only GIF — all into docs/marketing/.
---

## When to reach for this

The product runs and someone needs to show it off — a launch, a README hero,
a changelog entry. Capture the real screens in their real state, not a mimic.
If the app does not run yet, this skill has nothing to shoot: use a mockup
skill, then come back when there is a live surface. One concern only: real app
on screen → framed image (and maybe a GIF) on disk.

## Backend auto-detect ladder — lock beats assumption

There is no guaranteed browser backend. Probe for what is actually available, in
priority order, use the first present, and state which one before capturing.

| Priority | Backend | Screenshot | Native GIF |
|----------|---------|------------|------------|
| 1 | `claude-in-chrome` | yes | yes (`gif_creator`) |
| 2 | Playwright MCP | yes | no |
| 3 | `Claude_Preview` | yes (`preview_screenshot`) | no |
| 4 | Puppeteer MCP | yes | no |

If a backend's tools are loadable/callable, it is present. If NONE of the four
is, stop and name all four you looked for — never guess a tool exists, never
install one to make detection pass.

## Getting the app on screen

Prefer a running server over starting one:

- A dev server already up? Point the detected backend at it. Never kill a server
  this flow did not start.
- `design-preview` installed AND project is Vite + React? Use it as the driver
  and let it own the server. Opportunistic — absent or wrong stack, fall through.
- Otherwise ask for the URL to shoot and navigate the backend there.

A local server this flow *does* start is background, PID noted, killed at run
end (reuse the shared `python3 -m http.server 8123` convention when serving
local files — including the frame shell below).

## Consent gate — up front, once per session

This flow starts servers and writes image files. Before ANY of that, ask via
`AskUserQuestion`, naming the exact artifacts:

> Capture marketing assets? Writes framed `docs/marketing/shot-01.png …` (one
> per shot) and, on a backend that supports it, `docs/marketing/demo.gif`.
> Starts a preview server only if the app is not already running; stopped at end.

Options: proceed / skip. Ask once per session; the answer holds all session.

<!-- CONSENT PATTERN (reusable): gate = up-front + once-per-session + names exact
     artifact paths + offers a clean skip. The parked visual-decisions
     consent-scope fix should copy THIS shape. -->

## The shotlist — user-specified, no crawling

The user supplies the shots — a route/URL plus an optional caption each:

```
/                 → "Dashboard — everything at a glance"
/projects/42      → "Project view with live activity"
/settings/billing → "Billing, no surprises"
```

No auto-discovery in v1 — a wrong crawl wastes a pass and the user knows their
money shots. Empty list → ask for it; never invent screens.

## Capture → frame → write

For each shotlist entry, in list order:

1. Navigate to the route; let the screen settle (fonts, images, first-paint
   animation); capture a full raw screenshot.
2. **Frame it.** Copy `assets/frame-shell.html` (relative to this skill) to a
   scratch file, fill its slots — `SLOT:SHOT_SRC` with the raw capture (data URI
   or local path), `SLOT:CAPTION` with the entry's caption, `SLOT:BG` optional.
   Serve it, render in the same backend, and re-screenshot the `#mc-capture-target`
   element. This is the framed output — zero image-library dependency, all
   HTML+CSS. Tune `--mc-accent`/the gradient to the brand; do not restyle per shot.
3. Write the framed image to `docs/marketing/shot-01.png`, `shot-02.png`, …
   Keep each shot's caption paired with its file — the `marketing-copy` skill
   consumes those captions. Delete scratch frame files after each write.
4. Report the written paths and which backend produced them.

## Demo GIF — native-only, else skip

A GIF is produced ONLY when the detected backend has a real recorder — today
that is `claude-in-chrome`'s `gif_creator`:

- **Backend has a recorder:** record a walkthrough of the shotlist (navigate the
  routes in order) to `docs/marketing/demo.gif`.
- **Backend has none** (Playwright/Preview/Puppeteer): skip the GIF and emit a
  clear note — `"GIF unavailable on <backend> — screenshots only."` Do NOT
  assemble frames by hand, shell out to ffmpeg, or install anything. Screenshots
  are the guaranteed deliverable; the GIF is a bonus the backend either affords
  or it does not.

## Server lifecycle and cleanup

- Start nothing you can avoid; reuse a live server or `design-preview`'s.
- A server this flow started dies at run end, by noted PID, on success and abort
  alike; verify the port is free afterwards.
- Scratch frame-shell files are deleted after their capture.
- A stray server, leftover scratch file, or half-written `docs/marketing/` is a
  failed run whatever images landed.

## Anti-patterns

- Assuming one backend is present — always detect.
- Installing a browser, MCP server, or system tool to enable capture or GIF.
- Hand-assembling a GIF (frame loop, ffmpeg) when the backend lacks a recorder.
- Crawling for routes instead of taking the user's shotlist.
- Killing or restarting a server this flow did not start.
- Per-shot restyling of the frame shell — equal treatment or it is a sales pitch.
- Shooting a mockup and calling it the real app — this skill is for the running
  product; mockups are a different skill's job.
