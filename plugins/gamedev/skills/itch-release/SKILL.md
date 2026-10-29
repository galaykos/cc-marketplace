---
name: itch-release
description: Use when publishing or updating a game on itch.io — butler push or butler login, BUTLER_API_KEY in CI, channel names, --userversion, an HTML5 or WebGL build that shows as a download, loads blank or returns 403 on itch.io, or a game jam entry hosted on itch.io.
---

> Last verified: 2026-10-26 — https://itch.io/docs/butler/pushing.html
<!-- version-tail-ok: butler is served from itch.io's own broth server, not npm/composer/pypi. The
     stamp points at the butler manual; the HTML5 limits were re-read from
     https://itch.io/docs/creators/html5 and the broth URL from the butler install page that day. -->

## Read first

- Read how the project already pushes — a CI workflow, a `push.sh`, a `.itch.toml` — and the
  page address `https://<user>.itch.io/<game>`. The target is `<user>/<game>:<channel>`, all
  lowercase, and the page must already exist: butler cannot create it, and a mismatch fails as
  `invalid target (bad user)` or `(bad game)`.

## Rules, and who enforces each

| Rule | Standing |
|---|---|
| A browser build needs the page's Kind of project set to HTML AND the upload marked as played in the browser on Edit game. The channel name sets neither | **recorded** |
| The HTML5 zip has `index.html` at its root and stays within ≤1,000 files, ≤500 MB extracted, ≤200 MB per file, ≤240 characters per path; names are case-sensitive UTF-8 | **recorded** — itch.io enforces it at upload or play time |
| The game is served from a subfolder of itch's CDN: a path starting with `/` breaks, use relative paths. A folder URL returns 403, not 404. Requests to another domain must be HTTPS | **recorded** |
| HTML5 pages take payment only as donations. To sell a web game, set Kind to Downloadable | **recorded** |
| The channel name sets the platform tag by substring — `win`/`windows`, `mac`/`osx`, `linux`, `android` — several may share one name. There is no architecture tag: put `arm64` in the name to ship two | **recorded** — only the first guess; correct it on Edit game |
| `--hidden` works only on the push that creates a channel; on an existing channel it errors | **recorded** — butler enforces it |
| Builds over 30 GB uncompressed are rejected | **recorded** — itch's backend enforces it |
| A folder holding exactly one `.zip` (and nothing else) is unzipped and its contents pushed; `--no-auto-unzip` uploads the zip as one file | **recorded** |
| Push the portable folder, never an installer or a pre-compressed archive: patches diff files, and a compressed blob changes whole on any edit | **agent-graded** |

## Jam entries

- An itch.io jam entry is a separate submission made from the jam's page. A published game page
  is not entered by existing; after submitting, confirm it shows in the jam's entries.
- Many jams lock uploads from the deadline until rating ends, so the build there at the
  deadline is the one rated. Push a working build early; take what may change after the
  deadline from that jam's own rules page, never from memory.

## Push from CI

```bash
# BUTLER_API_KEY (itch.io/user/settings/api-keys) in the environment; butler reads it, no login step.
curl -L -o butler.zip https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default
unzip butler.zip && chmod +x butler && ./butler -V
./butler push build/windows "<user>/<game>:windows" --userversion "$VERSION" --if-changed
```

- Use broth, not the `itchio.itch.io/butler` download: those links expire. Swap `linux-amd64`
  for the runner's channel; `-head` channels are bleeding-edge, the rest stable.
- `--userversion-file <f>` reads the version from a one-line UTF-8 file with no BOM; without
  either flag itch numbers builds itself.
- `--if-changed` skips a push identical to the latest build; `--dry-run` lists what would be
  sent and uploads nothing.
- Never echo the key. One printed in a public log is compromised: revoke it on the API keys page.

## Anti-patterns

- **Channel drift.** `windows` one release and `win-final` the next are two channels and two
  downloads on the page. Fix the names once and reuse them.
