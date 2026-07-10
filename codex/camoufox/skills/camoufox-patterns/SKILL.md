---
name: camoufox-patterns
description: Use when building a Camoufox scraper or automation — launch configuration, proxy + geoip pairing, humanized interaction, resource blocking, and using the Playwright API it exposes.
---

## What Camoufox is in the stack

Camoufox is the browser AND the driver surface in one object. Unlike
endpoint-based anti-detect tools, it does not launch a profile and hand a CDP
endpoint to a separate driver — it returns a Playwright Firefox `Browser`
directly. So there is no "connect over CDP" step: you configure the launch,
then drive the returned browser with ordinary Playwright calls. Confirm the
current launch options with the camoufox-docs skill before coding — the set
changes between releases.

## Launch: pair the location signals

The high-value pattern is a coherent identity: a proxy, an IP-matched
geolocation, and a chosen OS, all set at launch so nothing contradicts.

```python
from camoufox.sync_api import Camoufox

with Camoufox(
    headless=True,
    os="windows",
    humanize=True,
    geoip=True,                      # match geolocation/timezone/locale to exit IP
    proxy={"server": "http://proxy.example.com:8000",
           "username": "u", "password": "p"},
    block_images=True,
) as browser:
    page = browser.new_page()
    page.goto("https://example.com/list")
    for row in page.locator(".item").all():
        print(row.locator(".title").inner_text())
```

`geoip=True` auto-detects the exit IP; pass an IP string to pin it. Setting a
`proxy` without `geoip` leaves the geolocation contradicting the IP — the
paired options exist to close exactly that gap.

## Humanized interaction

- `humanize=True` humanizes cursor movement between targets; a float caps the
  time budget (`humanize=1.5` = up to ~1.5s per move). Use it when a target
  scores on pointer behavior; leave it off for pure data pulls where the
  movement cost buys nothing.
- Do not add manual `time.sleep()` "to look human" — it fights auto-wait and
  slows every run. Lean on Playwright's waiting instead (below).

## Speed: block what you don't render

- `block_images=True` drops image requests wholesale — the cheapest win for a
  text scraper.
- `block_webrtc=True` silences a common leak surface when you don't need RTC.
- For finer control, use Playwright routing on the page to abort by resource
  type:

```python
page.route("**/*", lambda r: r.abort()
           if r.request.resource_type in {"image", "media", "font"}
           else r.continue_())
```

Blocking fonts can shift layout and font-fingerprint signals — measure before
committing to it on a detection-sensitive target.

## Drive via Playwright, not sleeps

The returned browser is Playwright Firefox — use its auto-waiting API and skip
fixed delays. This surface is Firefox-flavored Playwright; cross-reference
the `cmd-playwright-check` skill for the full locator/wait vocabulary.

- Locators over one-shot queries: `page.locator("css=.price")` re-resolves and
  auto-waits for actionability.
- `page.wait_for_load_state("networkidle")` or `locator.wait_for()` instead of
  `sleep`. Web-first assertions (`expect(locator).to_be_visible()`) retry.
- Prefer role/text locators for resilience over brittle nth-child chains.

## Persistent context for session reuse

Reuse cookies and logins across runs with a durable profile:

```python
with Camoufox(persistent_context=True,
              user_data_dir="./profiles/acct-a") as browser:
    page = browser.new_page()   # cookies/storage survive between runs
```

Keep one profile per identity — sharing a `user_data_dir` across identities
leaks state between them. `persistent_context` requires `user_data_dir`.

## Targeted fingerprint injection

Let Camoufox generate the fingerprint; use `config` only for values it does
not expose yet. Overriding auto-populated properties triggers warnings and can
break internal consistency.

```python
with Camoufox(config={"webrtc:ipv4": "123.45.67.89"}) as browser:
    page = browser.new_page()
```

Keep every injected value consistent with the rest of the generated identity
(OS, locale, timezone) — a mismatched override is more detectable, not less.

## Addons

Pass extracted Firefox addons by path via `addons=[...]`; use
`exclude_default_addons` to drop Camoufox's bundled ones when they conflict.
Confirm both option names against the live docs before relying on them.

## Concurrency

Run independent identities as separate `Camoufox()` context managers, each
with its own proxy, `os`, and profile — do not share one browser across
identities, which cross-contaminates fingerprint and cookie state. Cap
parallelism to what the target and proxy pool tolerate rather than fanning out
unbounded.

## Comparing to endpoint-based tools

When weighing Camoufox against profile-plus-endpoint anti-detect tools, note
the architectural split: Camoufox is self-contained (browser + driver),
whereas those hand a CDP endpoint to an external driver. Reference
the `cmd-adspower-check` skill and the `cmd-kameleo-check` skill when that comparison is the actual question.

## Anti-patterns

- `proxy` without `geoip` — mismatched IP-vs-geolocation is the exact leak the
  pairing prevents.
- `time.sleep()` in place of Playwright auto-wait — slower and more brittle.
- One shared browser or `user_data_dir` across identities — state bleeds.
- Hand-overriding generated fingerprint properties via `config` — inconsistent
  values raise detection, and Camoufox warns about it.
- Options recalled from memory — verify each against the live docs first.
