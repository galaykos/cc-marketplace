---
name: adspower-patterns
description: Use when building an AdsPower automation — the profile lifecycle, the CDP handoff to a driver, rate limiting, and robust start/stop hygiene.
---

## The lifecycle is the whole job

An AdsPower automation is a fixed sequence: resolve a profile, start its
browser, connect a driver to the endpoint AdsPower hands back, do the work, then
stop the browser. The AdsPower side owns profile control and the browser
endpoint; a driver (Puppeteer or Playwright) owns the page. Keep that boundary —
this skill controls profiles, the driver skills drive pages.

```
list/create profile (user_id)
  -> GET /api/v1/browser/start?user_id=...
     -> read data.ws.puppeteer  (CDP WebSocket URL)
        -> connect a driver, do the work
  -> GET /api/v1/browser/stop?user_id=...   (always, even on failure)
```

Confirm the current paths with the adspower-docs skill each session before
coding — ports and paths drift across AdsPower versions.

## The CDP handoff — the payoff

`browser/start` returns the connection endpoints; you attach a driver to one of
them rather than launching a browser yourself:

- **Puppeteer:** pass the WebSocket endpoint straight through —
  `puppeteer.connect({ browserWSEndpoint: data.ws.puppeteer })`.
- **Playwright:** connect over CDP with the same ws URL —
  `chromium.connectOverCDP(data.ws.puppeteer)`.
- **Selenium:** set Chrome option `debuggerAddress` to `data.ws.selenium`
  (a `host:port` like `127.0.0.1:9333`).

Either way you `connect`, never `launch` — AdsPower already launched the browser
with the profile's fingerprint and proxy. Launching your own browser throws away
the anti-detect profile entirely. See the `cmd-puppeteer-check` skill and the `cmd-playwright-check` skill for
the driver-side details; this skill owns getting the endpoint to hand over.

## Handle `code != 0` before connecting

Never read `data.ws` until you have checked `code === 0`.
On a non-zero code the `data` may be empty or stale, and connecting to a missing
endpoint fails with a confusing driver error far from the real cause.

```
const r = await startBrowser(userId);
if (r.code !== 0) throw new Error('adspower start failed: ' + r.msg);
const ws = r.data.ws.puppeteer;   // safe only after the code check
```

Branch on the numeric `code`, not on `msg` text — `msg` wording is not a stable
contract across versions.

## Rate limiting and backoff

The Local API tolerates roughly one request per second. Space every call — a
serialized queue with a ~1s minimum gap is simpler and more reliable than firing
in parallel and retrying the rejections.

- Put all API calls behind one throttle, not per-call sleeps scattered around.
- On a rate-related failure, back off (e.g. wait, then retry once) rather than
  immediately re-firing; a retry-storm just extends the throttled window.
- Batching many profiles? Start them one at a time through the same throttle,
  not in a `Promise.all` fan-out that violates the limit on the first tick.

## Concurrency: many profiles, one throttle

Running N profiles means N started browsers, but still one shared API pacer:

- Iterate profiles, start each through the throttle, collect its endpoint.
- Cap how many browsers run at once to what the machine can hold — each is a
  full browser process with its own memory footprint.
- Track every started `user_id` so the cleanup step can stop all of them, even
  the ones started before a mid-run failure.

## Session and proxy live in the profile

Each profile carries its own fingerprint, cookies, storage, and proxy — that is
the point of AdsPower. Do not set a proxy or user-agent on the driver side; it
would fight the profile's configuration. Configure the proxy on the profile
(via the profile CRUD endpoints or the app) and let `browser/start` apply it.
The driver should treat the connected browser as already-configured.

## Cleanup on failure — always stop

The single most common leak is a browser started and never stopped. Guarantee
the stop:

```
const started = [];
try {
  for (const id of ids) { await start(id); started.push(id); /* work */ }
} finally {
  for (const id of started) { try { await stop(id); } catch {} }
}
```

- Put `browser/stop` in a `finally`, not only on the happy path.
- Stop only what you actually started — track ids, don't blind-stop a range.
- If a stop itself fails, log and continue; one failed stop must not strand the
  rest still running.

## Anti-patterns

- Reading `data.ws` before checking `code === 0`.
- `launch`-ing your own browser instead of `connect`-ing — discards the profile.
- Setting proxy or fingerprint on the driver, duplicating the profile's config.
- Parallel `browser/start` fan-out that blows past the ~1 req/s limit.
- Starting browsers with no `finally` stop, leaking processes on any error.
- Hardcoding paths or the `50325` port from memory instead of resolving them
  from the live docs via adspower-docs this session.
