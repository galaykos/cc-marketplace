---
name: camoufox-docs
description: Use when writing a Camoufox automation — resolve the current Python usage from live docs before coding, and apply Camoufox launch conventions.
---

## Memory is stale here by design

Camoufox is a young project — an open-source patched Firefox for anti-detect
browsing — and its Python launch options move between releases. New toggles
appear, defaults shift, option names get refined. Every import path, launch
option, and default in your output must come from a page fetched THIS session,
not recall. If camoufox.com is unreachable, say so and ask for a docs excerpt —
never fill the gap from memory.

## Resolving the current usage

- Fetch https://camoufox.com/python/usage/ — the canonical import paths, the
  launch pattern, and the full launch-option list live here.
- Fetch https://camoufox.com/python/installation/ — the pip install line and
  the `camoufox fetch` step (the browser binary is downloaded separately, not
  bundled with the pip package).
- Fetch https://camoufox.com/python/config/ when fingerprint injection is in
  scope — the `config` dict format and its caveats live there.
- Grep the codebase for `Camoufox(` / `AsyncCamoufox(` and any pinned
  `camoufox` version in lockfiles; re-verify the options in use against the
  page you just fetched rather than trusting the existing call.

## The doc-link map

Start from the page, not search — fetch and follow from these roots:

| Task smells like | Start here (under camoufox.com) |
|---|---|
| Import, launch, option list | /python/usage/ |
| Install, browser download, CLI | /python/installation/ |
| Overriding fingerprint properties | /python/config/ |
| What is faked, feature list | /features/ |
| Source, issues, discussions | github.com/daijro/camoufox |

## Core API (verify against the live page)

Camoufox ships a thin wrapper that hands you a Playwright Firefox `Browser`:

```python
from camoufox.sync_api import Camoufox      # sync
from camoufox.async_api import AsyncCamoufox # async

with Camoufox() as browser:
    page = browser.new_page()
    page.goto("https://example.com")
```

Async mirrors it under `async with AsyncCamoufox() as browser:` with `await`
on `new_page()` / `goto()`. The returned object keeps full Playwright Firefox
API compatibility — you modify only the launch call; every other Playwright
page/locator method applies unchanged. Do not reach for the camoufox-patterns
skill's Playwright details from memory; that surface is Firefox-flavored
Playwright, cross-referenced via the `cmd-playwright-check` skill.

## Launch-option map (types from the live page)

- `headless` — bool or `'virtual'` (Linux Xvfb); default is headed.
- `humanize` — bool or float (max seconds) — humanizes cursor movement.
- `geoip` — IP string or `True` for auto-detection — matches geolocation,
  timezone, and locale to the (proxy) exit IP. Needs the `[geoip]` extra.
- `os` — `"windows"` / `"macos"` / `"linux"` or a list for random selection.
- `proxy` — Playwright proxy dict (`server`, `username`, `password`).
- `block_images` — bool — drops image requests for speed.
- `block_webrtc` / `block_webgl` — bools — silence those leak surfaces.
- `config` — dict overriding individual generated fingerprint properties.
- `persistent_context` — bool; requires `user_data_dir` for a durable profile.
- `addons` — list of paths to extracted Firefox addons.
- `locale`, `fonts`, `screen`, `webgl_config`, `window`, `enable_cache`,
  `disable_coop`, `main_world_eval`, `exclude_default_addons` — confirm each
  on the page before use; the set grows release to release.
- All standard Playwright Firefox launch options pass through as well.

## Install and fetch

```bash
pip install -U camoufox[geoip]   # [geoip] extra recommended for proxy work
camoufox fetch                    # downloads the patched Firefox binary
```

Other CLI verbs from the install page: `path` (binary location), `remove`,
`server` (Playwright server), `test` (Playwright inspector), `version`.
Skipping `camoufox fetch` leaves no browser to launch — a first-run failure
that looks like a config error but is a missing-binary error.

## Conventions

- Python-first. There is a JS/TS surface via a Playwright fork, but the
  documented, primary API is Python — reach for it unless told otherwise.
- Firefox-only. Camoufox is a Firefox fork; there is no Chromium or CDP
  target, so Chromium recipes and `CDPSession` code do not translate.
- Let Camoufox generate the fingerprint. It produces a consistent OS +
  navigator + fonts + headers + screen + geolocation set on its own. Pair
  `geoip` with the proxy and set `os`; leave the rest generated.
- `config` is an escape hatch, not the default path. The docs warn that
  hand-setting properties Camoufox populates automatically triggers warnings
  and can break internal consistency — use it only for values the library
  does not yet expose (e.g. `webrtc:ipv4`).

## Anti-patterns

- Any import path, option, or default written from memory instead of a fetched
  page — this project's churn is the whole reason this skill exists.
- Hand-mixing fingerprint values through `config` that Camoufox already
  generates — inconsistent combinations are more detectable, not less.
- Expecting Chromium / CDP semantics — this is Firefox; there is no CDP.
- Skipping `camoufox fetch` and blaming the launch code when it fails.
- Setting `proxy` without `geoip` — a mismatched IP-vs-geolocation pair is a
  giveaway the paired options exist to prevent.
