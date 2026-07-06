# kameleo

Kameleo Local API navigator. Kameleo is an anti-detect browser whose **Local
API** runs on the machine (default `http://localhost:5050`), served by the
running Kameleo app and wrapped by official SDKs. The Local API and its SDKs
change between releases, so this plugin's rule is: every endpoint, SDK method,
and request field comes from docs fetched in the current session, never from
memory.

Covers the fingerprint → profile → start → connect flow, connecting Playwright
or Puppeteer to a started profile over CDP, and profile/fingerprint
configuration.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install kameleo@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/kameleo:check [automation-goal]` | Resolve the current Local API endpoints / SDK usage, the fingerprint → profile → start flow, and the driver CDP handoff — all from live docs |

## Example

```bash
/kameleo:check open a profile with a Windows/Chrome fingerprint and drive it with Playwright
```

Reports something like: the fingerprint-search, profile-create, and
`POST /profiles/{guid}/start` calls (verified against the live reference), the
base URL `http://localhost:5050`, the `kameleo-local-api-client` SDK for the
caller's language, and the handoff — take the CDP/WebSocket endpoint the started
profile exposes and attach Playwright with `chromium.connectOverCDP(...)`
(or Puppeteer with `browserWSEndpoint`), driving the browser Kameleo launched
rather than a fresh one. Stop the profile when done.

## What the skills enforce

- Current endpoints and SDK method names from the live reference, never memory;
  the reference renders JS-only, so the skill names that gap and asks for the
  `swagger.json` or an excerpt rather than guessing paths
- Base URL `http://localhost:5050` (confirm the port per install) and the
  official SDK (`kameleo-local-api-client`, Python/.NET/Node) preferred over
  raw HTTP
- The fingerprint → profile → start → connect → stop spine, with the CDP
  handoff to Playwright/Puppeteer
- Profile hygiene: the Kameleo app must be running to serve the API, profiles
  are addressed by `guid`, spoofing settings (canvas/WebGL/geolocation/
  timezone) must stay internally consistent, and started profiles must be
  stopped to avoid orphaned browsers

A reminder hook nudges toward `/kameleo:check` when a prompt mentions Kameleo,
the Local API, `localhost:5050`, anti-detect browsing, or fingerprint profiles.

## Pairs well with

- **playwright** — the driver you connect over CDP to a started profile
- **puppeteer** — the alternative driver via `browserWSEndpoint`
- **adspower** — sibling anti-detect browser with its own Local API navigator
- **camoufox** — anti-detect Firefox automation, a related approach
- **automation-builder** — assembles the end-to-end browser automation this
  plugin's flow slots into
- **api-docs-first** — the generic docs-before-code discipline; kameleo is its
  Kameleo-specialized sibling
