# all-plugins

Installs every leaf plugin of this marketplace at one scope, with zero prompts, raises
the host's skill-listing budget so every description is actually sent, and undoes both.
One script, one exit code; the two commands only relay it.

## Three ways to run it

```bash
# 1. In a session, after installing this one plugin:
/plugin install all-plugins@cc-plugins-marketplace
/all-plugins:install                   # every leaf plugin at local scope (not found yet? /reload-plugins first)
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
| `--scope local\|project\|user` | where the install records go; default `local` (this checkout, not committed) |
| `--dry-run` | print the plan — one `DRY` line per command it would run — and exit 0 without running any |
| `--self` | `uninstall` only: remove `all-plugins` too, last; without it the plugin stays and the script says how to remove it |
| `--no-budget` | leave `skillListingBudgetFraction` alone in both directions (see "The listing budget") |
| `--marketplace NAME` | read a different added marketplace's manifest instead of this one; still one marketplace per run |

## Exit codes

| Code | Means | What the command does with it |
|---|---|---|
| `0` | every plugin installed or removed (or the dry run printed); the budget step's own failures are stderr lines, never an exit code | relays the `Run /reload-plugins` line when the script printed one — it does so only when something was installed or enabled |
| `1` | at least one plugin failed; the others were still attempted | lists the `FAIL` lines and stops |
| `2` | a precondition is missing — the marketplace is not added, `claude` or `jq` is not on `PATH`, or the arguments are wrong | shows the stderr line, which names the fix |

## What it does not do

- **Never installs a bundle.** Leaves only — every plugin whose manifest has no
  `dependencies` key, the same rule `scripts/validate.sh` counts leaves by. A bundle
  is a curated subset of those same leaves, so beside the full set it adds nothing.
- **Never touches another marketplace.** The plugin list is read from one added
  marketplace's `marketplace.json` (this one unless `--marketplace` says otherwise),
  never from what happens to be installed.
- **Never prompts.** There is no picker and no confirmation; `--dry-run` is the preview.
- **Does not reload the session.** The host owns that; the command tells you to run
  `/reload-plugins` and cannot do it for you. The raised budget takes effect on the same
  reload.
- **Does not decide what you need.** That is `/stack-scan:suggest`, which reads your
  manifests and installs a picked set with evidence. This plugin is for the case where
  you have already decided you want everything.

## What has teeth

| Rule | Standing |
|---|---|
| The exit codes, the leaves-only list, the scope flag, zero prompts | **gate** — a mechanism, not prose: `scripts/all-plugins.sh` returns them, and a shim-driven harness, `scripts/__tests__/all-plugins.test.sh` (CI-globbed with every other plugin harness), fails the build if they drift |
| The commands relay the script instead of running `claude plugin install` themselves | **agent-graded** — it is instruction text in `commands/*.md`; nothing detects a substituted loop |
| The budget step: the fraction written, never lowered, foreign values kept, invalid JSON untouched, removed only when it is the script's own value | **gate** — the same harness drives it against fixture settings files |
| The overflow arithmetic | **recorded** — reproduced by `scripts/context-budget.sh`; the 0.07 figure moves as the marketplace grows, and the script recomputes it on every run |
| The zero-delta firing result | **recorded** — one n=50 measurement; nothing re-runs it in CI (`scripts/smoke/listing-eviction-probe.sh` needs a live model and `LISTING_PROBE=1`) |

## The listing budget — what `install` changes besides the install list

Claude Code caps the skill+command listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` — default fraction
0.01, so 6,000 chars on a 200k window (3-byte model) and 30,000 at 1M — and past the
cap it drops entries to name-only, buying descriptions back in priority order. Every
leaf here costs about 36,500 entry-chars (`name + 4 + min(description + when_to_use, 1536)` per
skill and command, the walk `scripts/lib/plugin-checks.sh`'s `pc_listing_entry_cost`
does): 6.1x the 200k cap, 1.2x the 1M cap. The name+4 floor alone is 67% of the 200k
cap, so no amount of description trimming makes everything fit there.

So `install` finishes by computing that cost from the marketplace clone and writing
`skillListingBudgetFraction` into the scope's settings file — `.claude/settings.local.json`
(local), `.claude/settings.json` (project), `~/.claude/settings.json` (user) — at the
smallest 0.01 step that covers cost x 1.05 at the 200k floor: 0.07 today. The fraction
is a cap, not a fill, so a 1M window pays nothing extra for the larger value. It never
lowers a value that already covers, keeps every other key, refuses to touch a file that
is not valid JSON (stderr names the value to set by hand), and prints what it did. The
price is the listing itself: about 12,200 system-prompt tokens per turn, almost all of
it prompt-cache reads. `uninstall` removes the key only when it still holds the value
`install` would set now — any other value is yours and is left alone, with a line saying
so. `--no-budget` skips the step in both directions.

Whether an overflowed listing actually changes what fires was measured once
(`rationale/2026-09-15-listing-eviction-probe.md`): same skill with and without its
description, at 1, 13, 226 and 205-with-rivals skills — 47/50 against 47/50, zero delta,
one model, one prompt shape, triggering only. On that evidence the budget step may be
buying nothing; it exists because sending every description is the one way to make the
question moot, and it costs one settings key you can see and remove.

The `everything` bundle that once existed served this same want and was removed on the
"unreachable" reading, before the probe. This plugin is a script, not a bundle: it has no `dependencies` key, so
the bundle listing gates (`pc_listing_declaration`, the README member check) do not
apply to it — which is why the cost is stated here instead of enforced by one.
