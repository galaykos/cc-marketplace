# camoufox

Camoufox navigator and patterns. Camoufox is an open-source patched Firefox for
anti-detect browsing — it launches a browser you drive with Playwright
(Firefox), primarily via its Python API. The project is young and its launch
options change between releases, so this plugin's rule is: every import path,
launch option, and default comes from a page fetched in the current session on
camoufox.com, never from memory.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install camoufox@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/camoufox:check [automation-goal]` | Resolve the current Python usage from the live docs — import path, context-manager launch pattern, and the launch options your goal needs (`humanize`, `geoip`, `os`, `proxy`, `block_images`, `config`, `persistent_context`, `addons`) with doc-verified types — plus the Playwright-Firefox surface it exposes |

## Example

```bash
/camoufox:check scrape a paginated listing behind a residential proxy
```

Reports something like: `pip install -U camoufox[geoip]` then `camoufox fetch`;
`from camoufox.sync_api import Camoufox`; a launch with `os="windows"`,
`humanize=True`, `geoip=True`, a `proxy={...}` dict, and `block_images=True`;
that the returned object is a Playwright Firefox `Browser` so `page.locator(...)`
and auto-waiting apply unchanged; and the reminder to let Camoufox generate the
fingerprint rather than hand-setting values via `config`.

```python
from camoufox.sync_api import Camoufox

with Camoufox(os="windows", humanize=True, geoip=True,
              proxy={"server": "http://proxy.example.com:8000",
                     "username": "u", "password": "p"},
              block_images=True) as browser:
    page = browser.new_page()
    page.goto("https://example.com/list")
    for row in page.locator(".item").all():
        print(row.locator(".title").inner_text())
```

## What the skills enforce

- Current import path, launch pattern, and options from camoufox.com, never
  memory; existing `Camoufox(...)` calls re-verified against the fetched page
- The doc-link map: usage / installation / config pages, plus the GitHub source
- `camoufox fetch` downloads the browser binary separately from the pip package
  — skipping it is a missing-binary failure, not a config error
- Firefox-only: no Chromium or CDP target, so Chromium/CDP recipes do not
  translate; the driver surface is Playwright Firefox
- Pair `geoip` with the `proxy` and set `os`; let Camoufox generate the rest of
  the fingerprint — `config` is an escape hatch for unexposed values only
- Playwright locators and auto-wait over fixed `sleep`s; persistent context and
  separate browsers per identity for session isolation

A reminder hook nudges toward `/camoufox:check` when a prompt mentions Camoufox,
`humanize`, `geoip`, anti-detect, or fingerprint.

## Pairs well with

- **playwright** — Camoufox exposes a Playwright Firefox surface; the driver
  API vocabulary lives there (`/playwright:check`)
- **puppeteer** — the other browser-driver reference when weighing engines
- **adspower** / **kameleo** — endpoint-based anti-detect tools to compare
  against Camoufox's self-contained (browser + driver) shape
- **automation-builder** — assembles the end-to-end automation this navigator
  feeds
- **api-docs-first** — the generic docs-before-code discipline; camoufox is its
  Camoufox-specialized sibling
