# all-plugins

Installs every plugin in this marketplace at one scope, and removes them again. With no
`--scope`, it asks once and nothing else: `/all-plugins:install` offers local or project,
`/all-plugins:uninstall` offers local, project or user. With `--budget`, install also
raises the host's skill-listing budget so every description in the listing reaches the model;
uninstall reverses both. One script does the work, with one exit code; the two commands
only relay it. A "leaf" is any plugin in the marketplace's `marketplace.json`; there are
no bundles to skip. Every leaf includes `all-plugins` itself: `install` covers it (normally a
`skip`), and `uninstall` keeps it unless `--self`. One plugin is left out by
construction: **`prompt-coach`**, which bills a model call per eligible prompt. It installs
only when you name it (`claude plugin install prompt-coach@cc-plugins-marketplace -s local`).
`install` never installs or enables it, and prints it as a
`skip (opt-in: bills a model call per prompt)` row. `uninstall` and `list` treat it like
any other plugin. The six game plugins — `godot`, `unity`, `unreal`, `phaser`, `pixijs` and `gamedev` —
are left out the same way, as
`skip (opt-in: game plugin, /stack-scan:suggest installs it in a game repo)`. Their
descriptions in every project's listing serve no project but a game, and `/stack-scan:suggest`
puts each one where its manifest signal is. Install one by name like prompt-coach.

> **Re-run it after every marketplace update.** `install` installs what the marketplace
> holds **when you run it**. `/plugin marketplace update` updates the plugins you have;
> it installs none that were added since. Run `/all-plugins:install` again after each
> update — installed plugins are skipped, new ones install. `ui-libraries`, split out of
> `ui-ux` on 2026-09-26, is one such plugin: an install from before that date lacks it
> until you re-run.

## The startup line

Installing `all-plugins` alone installs nothing else. While it is the only plugin of its
marketplace enabled, each new session (startup, not a resume or compaction) shows you
one line: run `/all-plugins:install`. It goes to you as a `systemMessage` and never into
the model's context, and it stops the moment any leaf is enabled. `CC_ALL_PLUGINS_HINT=off`
hides it.

"Enabled" is the `enabledPlugins` map merged from the settings files the CLI writes,
later wins: `~/.claude/settings.json` (or under `CLAUDE_CONFIG_DIR`), then the project's
`.claude/settings.json` and `.claude/settings.local.json`. It does not read managed policy
settings, a `--settings` file or a `--plugin-dir` load: when all-plugins itself is enabled
only through one of those it stays silent, and when leaves are, it shows the line wrongly.
**Gate** — `scripts/__tests__/all-plugins.test.sh`, the `hint:` cases.

## Three ways to run it

```bash
# 1. In a session, after installing this one plugin:
/plugin install all-plugins@cc-plugins-marketplace
/all-plugins:install                   # every leaf but opt-in prompt-coach and the game plugins; asks local or project first (not found yet? /reload-plugins first)
/all-plugins:uninstall                 # the inverse; --self removes all-plugins too
/reload-plugins                        # nothing installed this run is active until you do

# 2. Install this plugin from your shell first (the CLI form takes a scope), then the same commands:
claude plugin install all-plugins@cc-plugins-marketplace -s local

# 3. With no plugin installed at all — the marketplace clone already carries the script:
bash ~/.claude/plugins/marketplaces/cc-plugins-marketplace/plugins/all-plugins/scripts/all-plugins.sh install
```

Every path needs `claude plugin marketplace add galaykos/cc-marketplace` first; the
clone path in 3 is where the host keeps every added marketplace, so the script is on
disk before any plugin is installed.

## Flags

| Flag | Meaning |
|---|---|
| `install` / `uninstall` / `list` | the verb; required. `list` prints each leaf's state at the scope (script only — the commands wrap the first two) |
| `--scope local\|project\|user` | where the install records go. Absent, `install` asks local or project and `uninstall` local, project or user, once, and run nothing until answered; the script run directly defaults to `local` (this checkout, not committed) |
| `--dry-run` | print the plan — one `DRY` line per command it would run — and exit 0 without running any |
| `--self` | `uninstall` only: remove `all-plugins` too, last; without it the plugin stays and the script says how to remove it |
| `--budget` | `install` only: raise `skillListingBudgetFraction` to cover the whole listing (see "The listing budget"); off by default since 0.3.0 |
| `--no-budget` | `uninstall` only: leave `skillListingBudgetFraction` alone even when it holds the value `--budget` writes |
| `--marketplace NAME` | read a different added marketplace's manifest instead of this one; still one marketplace per run |

## Exit codes

| Code | Means | What the command does with it |
|---|---|---|
| `0` | every plugin installed or removed (or the dry run printed); the budget step's own failures are stderr lines, never an exit code | relays the `Run /reload-plugins` line when the script printed one — it does so only when something was installed or enabled |
| `1` | at least one plugin failed; the others were still attempted | lists the `FAIL` lines and stops |
| `2` | a precondition is missing — the marketplace is not added, `claude` or `jq` is not on `PATH`, or the arguments are wrong | shows the stderr line, which names the fix |

## What it does not do

- **Does not follow the marketplace.** The list is read when the script runs; a plugin
  added later arrives only when you run `install` again (the notice at the top).
- **Never touches another marketplace.** The plugin list is read from one added
  marketplace's `marketplace.json` (this one unless `--marketplace` says otherwise),
  never from what happens to be installed.
- **Never picks or confirms.** There is no picker and no confirmation; `--dry-run` is the
  preview. The one question is the scope, asked by either command only when you
  typed no `--scope` — a silent `local` default once left every other project bare while
  its user believed the marketplace was on. The script itself never prompts.
- **Does not install the official complements.** Language servers such as `php-lsp` are a
  different marketplace's; `/stack-scan:suggest` matches them to your manifests and prints
  their install commands.
- **Does not reload the session.** The host owns that; the command tells you to run
  `/reload-plugins` and cannot do it for you. The raised budget takes effect on the same
  reload.
- **Does not decide what you need.** That is `/stack-scan:suggest`, which reads your
  manifests and installs a picked set with evidence; its `--sync` mode moves a machine off
  user scope project by project, and prints this script's `uninstall --scope user --self`
  as the last step. This plugin is for the case where
  you have already decided you want everything but prompt-coach and the game plugins.

## What has teeth

| Rule | Standing |
|---|---|
| The exit codes, the every-listed-plugin list, the `prompt-coach` and game-plugin opt-in skips, the scope flag, a script that never prompts | **gate** — a mechanism, not prose: `scripts/all-plugins.sh` returns them, and a shim-driven harness, `scripts/__tests__/all-plugins.test.sh` (CI-globbed with every other plugin harness), fails the build if they drift |
| The commands relay the script instead of running `claude plugin install` themselves | **agent-graded** — it is instruction text in `commands/*.md`; nothing detects a substituted loop |
| Both commands ask for the scope when `--scope` is absent (`user` only typed, for install), and stop rather than defaulting when nobody answers | **agent-graded** — instruction text in `commands/install.md` and `commands/uninstall.md`; no harness drives a command |
| The startup line: shown only while all-plugins is its marketplace's sole enabled plugin, on startup, to the person, off with `CC_ALL_PLUGINS_HINT=off` | **gate** — the same harness's `hint:` cases drive `hooks/hint.sh` against fixture settings files |
| The budget step: nothing written without `--budget`; with it, the fraction written, never lowered, foreign values kept, invalid JSON untouched, removed only when it is the script's own value | **gate** — the same harness drives it against fixture settings files |
| The overflow arithmetic | **recorded** — reproduced by `scripts/context-budget.sh`; the 0.08 figure moves as the marketplace grows, and the script recomputes it on every run |
| The zero-delta firing result | **recorded** — one n=50 measurement; nothing re-runs it in CI (`scripts/smoke/listing-eviction-probe.sh` needs a live model and `LISTING_PROBE=1`) |

## The listing budget — what `install --budget` changes besides the install list

Claude Code caps the skill+command listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` — default fraction
0.01, so 6,000 chars on a 200k window (3-byte model) and 30,000 at 1M — and past the
cap it drops entries to name-only, buying descriptions back in priority order. Every
leaf here costs about 44,400 entry-chars (`name + 4 + min(description + when_to_use, 1536)` per
skill and command, the walk `scripts/lib/plugin-checks.sh`'s `pc_listing_entry_cost`
does): 7.4x the 200k cap, 1.5x the 1M cap. The name+4 floor alone is 77% of the 200k
cap, so no amount of description trimming makes everything fit there.

So `install --budget` finishes by computing that cost from the marketplace clone and writing
`skillListingBudgetFraction` into the scope's settings file — `.claude/settings.local.json`
(local), `.claude/settings.json` (project), `~/.claude/settings.json` (user) — at the
smallest 0.01 step that covers cost x 1.05 at the 200k floor: 0.08 today. The fraction
is a cap, not a fill, so a 1M window pays nothing extra for the larger value. It never
lowers a value that already covers, keeps every other key, refuses to touch a file that
is not valid JSON (stderr names the value to set by hand), and prints what it did. The
price is the listing itself: about 14,800 system-prompt tokens per turn, almost all of
it prompt-cache reads. `uninstall` removes the key only when it still holds the value
`install --budget` would set now — any other value is yours and is left alone, with a
line saying so. It does that by default, so a value an install before 0.3.0 wrote
unasked is cleaned up too; `uninstall --no-budget` keeps it.

Whether an overflowed listing actually changes what fires was measured once
(`rationale/2026-09-15-listing-eviction-probe.md`): same skill with and without its
description, at 1, 13, 226 and 205-with-rivals skills — 47/50 against 47/50, zero delta,
one model, one prompt shape, triggering only. On that evidence the budget step buys
nothing measured, so since 0.3.0 it is opt-in: `--budget` is for whoever wants the
question moot at that price, one settings key you can see and remove.

The `everything` bundle that once existed served this same want and was removed on the
"unreachable" reading, before the probe. This plugin is a script, not a bundle, and no
gate enforces the cost stated here — it is recorded (see "What has teeth") and
recomputed by `scripts/context-budget.sh` on every run.

## History

The suites were retired 2026-09-26, which is why there are no bundles to skip.
