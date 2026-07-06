---
name: kameleo-docs
description: Use when integrating the Kameleo Local API or SDK — resolve current endpoints from live docs before coding, and apply the Local API conventions.
---

## Memory is stale here by design

Kameleo ships the Local API and its language SDKs on its own release cadence;
endpoint shapes, request bodies, and SDK method names drift between versions,
and answering a fingerprint or profile question from recall recommends a route
that may no longer exist. Every endpoint path, SDK call, and request field in
your output must come from a page fetched THIS session, not from memory. If the
reference is unreachable, say so and ask for a docs excerpt — never fill the
gap from memory.

## Resolving the current API

- Reference (may render JS-only):
  https://developer.kameleo.io/reference/api-reference/ (the "Kameleo Local
  API"). Two sources that fetch cleanly when the reference does not:
  - The running Engine's own Swagger UI at `http://localhost:5050/swagger` —
    the authoritative live endpoint list for the installed version.
  - The examples repo: https://github.com/kameleo-io/local-api-examples —
    real fingerprint→profile→start→connect flows per language.
  If none is reachable, name the gap and ask for an excerpt; never assume paths.
- The Local API is served locally by the running Kameleo app. The default base
  URL is `http://localhost:5050`. Confirm the port against the current docs and
  the user's install — it is configurable, not guaranteed.
- Prefer the official SDK over raw HTTP whenever a language SDK exists. The
  Local API client packages (verify names and current versions against the
  registry each session):
  - Python: `kameleo-local-api-client` (PyPI)
  - Node/TypeScript: `@kameleo/local-api-client` (npm)
  - .NET / C#: `Kameleo.LocalApiClient` (NuGet)
- The SDK wraps the same Local API, so its methods map onto the endpoints
  below; use the SDK's typed models rather than hand-building JSON bodies.

## The endpoint / SDK map

Treat this as a routing map to verify against live docs, NOT as verbatim
contract — confirm each path, method, and body against the fetched reference
before writing code.

| Task smells like | Local API area (verify) |
|---|---|
| Find a base fingerprint | search **fingerprints** — `GET /fingerprints` with filter query |
| Create a profile from a fingerprint | create **profile** — `POST /profiles` |
| Launch a profile's browser | **start** — `POST /profiles/{guid}/start` |
| Shut a profile's browser | **stop** — the profile stop endpoint |
| Change spoofing settings | **update profile** — canvas / WebGL / geolocation / timezone |
| List / read existing profiles | the profiles collection / by-guid read |

- Fingerprint search returns fingerprint records; you pick one and pass its id
  when creating a profile. A profile is BUILT FROM a fingerprint — you do not
  configure raw device values directly, you select a fingerprint and then
  override specific spoofing options on the profile.
- Starting a profile launches its browser and exposes a driver endpoint
  (CDP/WebSocket) you connect an automation library to; see kameleo-patterns
  for the handoff. Stopping the profile tears that browser down.

## Local API conventions

- The Kameleo desktop app or CLI MUST be running to serve the Local API — the
  endpoints are a local control plane over that app, not a remote cloud API.
  If `localhost:5050` refuses the connection, the app is not running (or the
  port differs); that is the first thing to check, not a code bug.
- Profiles are addressed by a `guid` returned at creation; keep it to start,
  stop, update, or reconnect the profile later.
- Spoofing settings (canvas, WebGL, geolocation, timezone, and the rest) live
  on the profile and must stay internally consistent — a timezone that
  contradicts the geolocation is itself a detectable signal. Read the current
  reference for which options each fingerprint supports before setting them.
- Start is not idempotent in the way a GET is: starting an already-started
  profile, or starting many profiles without stopping them, leaks browser
  processes. Track what you started.
- The Local API's job is the browser lifecycle and its fingerprint/spoofing
  config — it is NOT the automation surface. Once a profile is started you
  drive the page through a normal automation library (Playwright, Puppeteer,
  Selenium) attached to the exposed endpoint, not through Kameleo calls.

## When to reach for the SDK vs raw HTTP

- Use the language SDK for anything a caller writes in Python, Node, or .NET:
  it ships typed request/response models, keeps up with the current Local API
  shape, and exposes a helper to obtain the driver connection string after a
  start — hand-rolling that string from the raw start response is fragile.
- Fall back to raw HTTP only for languages with no SDK, or for a one-off
  diagnostic against a single endpoint. Even then, resolve the exact path and
  body from the fetched reference first.
- When the user already has an SDK version pinned, read that version's docs /
  changelog rather than the latest — method names and models can differ across
  SDK releases just as the API does.

## Doc-fetch protocol

1. Fetch the reference root and locate the exact endpoint for the task.
2. If it renders JS-only or 404s, fetch the linked `swagger.json`, or ask the
   user to paste the endpoint's request/response schema — then proceed.
3. Confirm the base URL/port and the SDK package + version for the caller's
   language before writing any call.
4. Report the concrete endpoints/SDK methods, the request fields that matter,
   and the flow — each traceable to a page read this session.

## Anti-patterns

- Assuming endpoint paths or SDK method names from memory instead of the
  fetched reference — this API's version drift is the whole reason for this
  skill.
- Writing raw HTTP against `localhost:5050` when an official language SDK
  exists — the SDK carries the current models and connection helpers.
- Starting automation without the Kameleo app running, then debugging a
  connection-refused error as if it were a code fault.
- Leaving profiles started after a run — orphaned browser processes and leaked
  fingerprints across sessions.
- Setting spoofing options (timezone, geolocation, WebGL) that contradict each
  other or the chosen fingerprint, defeating the profile's purpose.
- Hardcoding `http://localhost:5050` without confirming the port against the
  user's install and the current docs.
