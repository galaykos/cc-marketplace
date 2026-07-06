---
name: kameleo-patterns
description: Use when building a Kameleo automation — the fingerprint-to-profile flow, connecting a driver over CDP, and profile/session hygiene.
---

## The core flow

Every Kameleo automation is the same spine: pick a fingerprint, build a profile
from it, start the profile, connect a driver to the browser it launches, do the
work, stop the profile. Resolve the exact endpoints/SDK methods for each step
with the kameleo-docs skill first — this skill is the shape, not the contract.

1. **Search fingerprints.** Query with filters (device, OS, browser) — SDK e.g.
   `client.fingerprint.searchFingerprints('desktop', undefined, 'chrome')`. You
   get back fingerprint records; choose one and keep its id.
2. **Create the profile.** Build a profile FROM the chosen fingerprint — SDK
   e.g. `client.profile.createProfile({ fingerprintId })`. Set
   spoofing options (canvas, WebGL, geolocation, timezone) at creation or
   update them after. The create call returns a profile `guid` — hold onto it.
3. **Start the profile.** Starting launches the profile's browser and exposes a
   driver endpoint (a CDP/WebSocket URL). Read that endpoint from the start
   response, or from the SDK's connection helper.
4. **Connect a driver.** Attach an automation library to the exposed endpoint
   (below). From here you drive the page with the library, not with Kameleo.
5. **Stop.** When finished, stop the profile so its browser process is torn
   down. Do this in a `finally` / `try-finally` so a crash mid-run still cleans
   up.

## Connecting a driver over CDP

The Engine exposes per-protocol endpoints on the Local API port, routed by the
profile id. The observed pattern (confirm against the running Swagger / examples
repo, since the port and shape can change across releases):

- **Playwright (Chromium)**:
  `chromium.connectOverCDP('ws://localhost:5050/playwright/' + profile.id)`,
  then take the existing context/page rather than launching a new browser.
- **Puppeteer**:
  `puppeteer.connect({ browserWSEndpoint: 'ws://localhost:5050/puppeteer/' + profile.id })`.
- **Selenium**: point a remote WebDriver at
  `http://localhost:5050/webdriver/' + profile.id`.

Prefer the SDK's connection helper over hand-building these strings — it stays
correct if Kameleo changes the routing.

Defer the driver-side specifics — selectors, waits, connection API surface — to
`/playwright:check` and `/puppeteer:check`; verify the current connect API
against those before writing the glue. Do not launch a fresh browser instance
in the driver — always attach to the one Kameleo started, or the fingerprint
you configured is bypassed entirely.

## Using the language SDK

- For Python, Node, or .NET, drive the whole flow through the official Local API
  client rather than raw HTTP: it carries typed models for fingerprint search,
  profile create/update, and start/stop, plus a helper that returns the driver
  connection string after a start.
- Let the SDK own the base URL / port (default `http://localhost:5050`); pass an
  override only when the user's install uses a different port.
- Keep the SDK version pinned and read that version's docs — method names and
  model fields shift across SDK releases.

## Persisting and reusing profiles

- A profile is durable: once created it keeps its `guid`, fingerprint, and
  spoofing config until deleted. Reuse the same profile across runs to keep a
  stable identity (cookies, storage, and fingerprint together) rather than
  creating a fresh profile every time — churn is itself a signal.
- Store the `guid` (and which fingerprint it was built from) in your own state
  so a later run can start the existing profile instead of rebuilding it.
- Only create a new profile when you deliberately want a new identity; treat
  profile creation as a meaningful act, not a per-run default.

## Fingerprint / spoofing config consistency

The spoofing options on a profile must form a coherent identity, or they defeat
their own purpose:

- **Timezone and geolocation** must agree — a browser reporting one region's
  IP-adjacent geolocation with another region's timezone is a mismatch.
- **Canvas and WebGL** spoofing should match the device class implied by the
  fingerprint; a mobile fingerprint with desktop-GPU WebGL strings is
  inconsistent.
- **Language / locale** should track the fingerprint and the intended region.
- Start from the fingerprint's own values and override narrowly; the fingerprint
  was captured as a consistent set, so the less you change the safer.

## Concurrency

- Each started profile is its own browser process and its own driver endpoint;
  run profiles in parallel by starting several and connecting a driver to each,
  but budget for the memory — every profile is a full browser.
- Do not share one driver connection across profiles, and do not start the same
  profile twice; a `guid` maps to one running browser at a time.
- Bound concurrency to what the host can carry; unbounded profile starts
  exhaust memory and leave orphans when they fail.

## Cleanup

- Always stop profiles you started, in a `finally` block, even on error or
  interrupt — orphaned browsers hold memory and leak across sessions.
- On a crash-recovery path, list running profiles and stop the ones your run
  owns rather than assuming a clean slate.
- Deleting a profile is separate from stopping it — stop ends the browser,
  delete removes the profile and its stored identity. Only delete profiles you
  do not intend to reuse.

## Anti-patterns

- Launching a fresh browser in the driver instead of attaching to Kameleo's —
  silently bypasses the whole fingerprint.
- Building raw HTTP calls when an official SDK exists for the language.
- Creating a new profile every run instead of reusing a persisted one.
- Setting spoofing options that contradict each other or the fingerprint.
- Starting profiles without a guaranteed stop, leaking browser processes.
- Assuming the connection endpoint format from memory instead of the start
  response or the SDK helper.
