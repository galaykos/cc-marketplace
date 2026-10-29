---
name: steam-release
description: Use when shipping or updating a game on Steam — app_build_*.vdf or depot_build_*.vdf scripts, steamcmd +run_app_build, SetLive or beta branches, the Steamworks store page, Coming Soon, release or build review, the Content Survey's AI disclosure, Steam Cloud quotas, Steam Deck Verified — or a steamcmd error such as "status = 6" or "Failed to get application info".
---

> Last verified: 2026-10-26 — https://partner.steamgames.com/doc/sdk/uploading
<!-- version-tail-ok: Steamworks is a partner portal plus an SDK zip, with no npm/composer/pypi
     package to compare against. Each store rule below was re-read on the stamp date from the
     partner.steamgames.com page named in references/; nothing machine-reads those pages. -->

## Read first

- Read `steam_appid.txt` and every `app_build_*.vdf` / `depot_build_*.vdf` before advising —
  usually under the Steamworks SDK's `tools/ContentBuilder/scripts/`, or written by CI
  (game-ci writes a `manifest.vdf`).
- Ask whether the app is already released: setting the default branch live changes at release.
- The store rules are as of the stamp. When one decides a launch date, re-read its Steamworks page.

## Lint the build script before every upload

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_steam_build.py" tools/ContentBuilder/scripts/app_build_<AppID>.vdf
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_steam_build.py" <app_build.vdf> --json --strict   # CI step
```

It parses the app script and every depot script, resolves `ContentRoot`, `LocalPath` and
`FileExclusion` the way the Uploading page documents, and prints each depot's file count and
size. Exit 0 clean, 1 errors (or warnings under `--strict`), 2 file missing or not an
`AppBuild` script. Fix every ERROR, then read the counts: a depot of 3 files where you expected
400 is the mistake no code flags. `--help` lists every check code. Standard library only; it
never logs in, uploads or writes.

It cannot see Steamworks-side state — an unpublished app config, a depot missing from a package,
the build account's rights. Those are rows in the troubleshooting table of `references/steampipe.md`.

## Rules, and who enforces each

The checker is a **gate** only where a CI step or the user runs it; no hook runs it.

| Rule | Standing |
|---|---|
| `SetLive` can never set `default` live. The customer branch goes live only by hand: Builds page → pick the build → Preview Change → Set Build Live Now | **gate** where run — `setlive-default` warning, `--strict` exits 1; the hand step is **recorded** |
| `SetLive "<beta>"` with `Preview` off puts the build live on that branch the moment the upload finishes | **gate** where run — `setlive-immediate` |
| On a released app, setting `default` live asks for confirmation on the Steam Mobile Authenticator, else by SMS to the account's phone — the account doing it needs one attached | **recorded** — Steam enforces it at the click |
| Set a branch password BEFORE setting any build live on that branch, or its contents are not private | **recorded** |
| Store presence must be submitted before the build can be. Each review takes 3–5 business days: submit the store page ≥7 days before you want it live, and plan ≥7 business days for the build | **recorded** — Steam enforces the order |
| The reviewed build must launch on every OS the store page lists and implement every feature ticked in Basic Info; untick a feature until it ships. After the first approval, updates are not re-reviewed | **agent-graded** — a reader can hold the store page against the build |
| Approval does not publish the page: click Post as Coming Soon. The page must be public ≥2 weeks before release, and an approved title never releases itself — Release App → Publish Now → Release Now | **recorded** |
| First few titles wait 21 days between paying the Steam Direct fee and release — not the 30 days older guides quote. Tax verification can take up to 30 days | **recorded** — dated by the stamp |
| Content Survey, AI section: shipped AI-made content is *pre-generated*; content made while the game runs is *live-generated* and also needs a description of the guardrails against illegal output. AI used only to work faster is not its focus. Some answers lock after approval and change only through Steam Support | **agent-graded** — only a reader of the asset provenance can answer it |

## Where the depth lives

- `references/steampipe.md` — script keys and path rules, CI login without a password, patch
  size (Unreal pak flags), the Steam Deck / Steam Machine compatibility checklist, and the
  troubleshooting table (`status = 6`, `Failed to get application info`, Mac/Linux get no files).
- `references/steam-cloud.md` — the two quota fields that must both be set, when Auto-Cloud
  actually syncs, Root OS, and Dynamic Cloud Sync on a Steam Deck suspend.

## Anti-patterns

- **A password in a committed script.** `+login <account> <password>` in a `.bat` or CI file.
  Use a separate build account and the token flow in `references/steampipe.md`; never commit
  `config.vdf`.
- **The admin login uploading builds.** Give a dedicated account in the partner group only the
  build and publish rights it needs.
- **`BuildOutput` inside `ContentRoot`.** Logs and the chunk cache upload with the game
  (checker: `buildoutput-in-contentroot`). Valve's layout keeps `output/` beside `content/`.
- **A folder as `LocalPath`.** `"LocalPath" "bin"` uploads nothing; use `bin\*` with
  `"Recursive" "1"` (checker: `localpath-is-folder`).
- **Waiting for approval to release the game.** Nothing happens until someone clicks Release App.
