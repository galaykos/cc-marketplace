# SteamPipe: scripts, CI login, patch size, Deck review, troubleshooting

> Last verified: 2026-10-26 — https://partner.steamgames.com/doc/sdk/uploading

Depth for `steam-release`. Every section was re-read on the stamp date from
`partner.steamgames.com/doc/sdk/uploading`, `/doc/steamhardware/compat` and
`/doc/api/ISteamInput`.

## 1. Script keys and path rules

The documented keys, and the only ones steamcmd reads (anything else is a typo it ignores —
the checker's `unknown-key`):

- `AppBuild`: `AppID`, `Desc`, `Preview`, `Local`, `SetLive`, `ContentRoot`, `BuildOutput`, `Depots`.
- `DepotBuild`: `DepotID`, `ContentRoot`, `FileMapping` (`LocalPath`, `DepotPath`, `Recursive`),
  `FileExclusion`, `InstallScript`, `FileProperties` (`LocalPath`, `Attributes`).

```text
"AppBuild"
{
    "AppID"       "1000"
    "Desc"        "1.2.0 (commit abc123)"   // shows on the Builds page
    "ContentRoot" "..\content\"             // relative to THIS script's folder
    "BuildOutput" "..\output\"              // logs + chunk cache; keep it outside ContentRoot
    "Depots"
    {
        "1001" "depot_build_1001.vdf"       // relative to this script's folder
        "1002" "depot_build_1002.vdf"
    }
}

"DepotBuild"
{
    "DepotID" "1002"
    "FileMapping"
    {
        "LocalPath" "bin\*"                  // relative to the content root; a bare folder maps nothing
        "DepotPath" "executables\"
        "Recursive" "1"
    }
    "FileExclusion" "*.pdb"                  // matches in every folder
    "FileProperties"
    {
        "LocalPath"  "settings.cfg"
        "Attributes" "userconfig"            // the player edits it: updates never overwrite it
    }
}
```

- A depot's own `ContentRoot` overrides the app's. `ContentRoot` may be absolute.
- `Attributes "versionedconfig"` is the other value: the player's copy is overwritten when the
  game updates. Use it only for a format change or a bug fix in that file.
- `"Preview" "1"` writes the manifest and logs to `BuildOutput` and uploads nothing.
- `"Local" "<path>"` builds to a Local Content Server; nothing reaches Steam (checker:
  `local-content-server`).
- Read the `*.log` files in `BuildOutput`, not the console, for the authoritative error.

## 2. CI login without a password

steamcmd stores a login token in `config/config.vdf` (under the folder steamcmd installed
itself into) after an interactive login that passed Steam Guard. CI restores that file and logs
in with the username alone.

1. Once, on a trusted machine: `steamcmd +login <build_account>`, give the password and the
   Steam Guard code, then `quit`.
2. Store the file base64-encoded as a CI secret; decode it into the same path before the build.
3. `steamcmd +login <build_account> +run_app_build "$PWD/<dir>/app_build_<AppID>.vdf" +quit` —
   an absolute path, so the working directory does not matter.

- A later login WITH the password issues a new token; re-export `config.vdf` after it.
- `Account Login Denied`: run `set_steam_guard_code <code>` in steamcmd, then log in again.
- Never print or commit `config.vdf`; treat a leaked one as a compromised account.

## 3. Patch size

- SteamPipe splits files into roughly 1 MB chunks and uploads only the chunks that changed.
- A pack file compressed or encrypted as one blob rewrites itself on any change, so the patch
  is the whole file. Keep asset order stable, group packs by level or feature, and add a new
  pack for new content instead of rewriting a large one.
- Unreal: build paks with `-patchpaddingalign=1048576 -blocksize=1048576` so shifts land on
  SteamPipe's chunk boundaries.

## 4. Steam Deck and Steam Machine compatibility review

- Separate from the release review: it never blocks release, and the rating it sets
  (Verified, Playable, Unsupported, Unknown) is shown per device. Verified on Steam Deck
  guarantees Verified on Steam Machine.
- It requires a completed standard build review first. Results publish about a week after
  they arrive unless you act; uploading a fixed build before then delays publication and
  triggers a retest.
- The default settings must reach a playable framerate: 30 fps at 800p on Deck, 30 fps at
  1080p on Machine.
- Deck only: run at a resolution Deck supports (1280x800 preferred, 1280x720 accepted), and no
  character under 9 px tall at 1280x800 (12 px recommended). Machine gets no display tests.
- The default controller configuration reaches all content.
- On-screen glyphs must match the active controller. With Steam Input, ask Steam rather than
  hard-coding: `GetInputTypeForHandle` returns the device model, `GetGlyphPNGForActionOrigin`
  a local PNG path for an origin's glyph, and `TranslateActionOrigin` maps an origin to its
  equivalent on another controller type.
- Text entry opens the on-screen keyboard through a Steamworks API, or offers its own
  controller-usable entry. A launcher, if any, meets the same rules, fully controller-navigable.
- Never tell the player their OS or GPU is unsupported.

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Failed to get application info for app NNN` | Wrong AppID, the account does not own the app, or the app's Steamworks config was never published | Check the AppID in the script; publish the config in App Admin; confirm ownership |
| `ERROR! Failed 'DepotBuild for …' - status = 6` | The build account lacks permission for the app, or `ContentRoot`/`LocalPath` finds no files | Grant the account the app's build rights; run the checker and fix the paths |
| Upload succeeded, players get the old build | The build was never set live, or only on a beta branch | Set it live on `default` by hand on the Builds page |
| Windows installs; Mac/Linux install no files | The OS depots are not in the package being deployed | Add them under the package's Depots Included (Add/Remove Depots) |
| Your own account downloads nothing | The depot is missing from the Developer Comp package | Add it under Associated Packages & DLC |
| "Invalid content configuration" at launch | No build live on the selected branch, a bad launch option, or depots you do not own | Set a build live; check the Installation launch options; fix the package |
| A steamcmd command's syntax | — | At the `Steam>` prompt, `find <partial>` prints matching commands and arguments |
