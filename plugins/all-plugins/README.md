# all-plugins

Installs every leaf plugin of this marketplace at one scope, with zero prompts, and
uninstalls them again. One script, one exit code; the two commands only relay it.

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
| `--marketplace NAME` | read a different added marketplace's manifest instead of this one; still one marketplace per run |

## Exit codes

| Code | Means | What the command does with it |
|---|---|---|
| `0` | every plugin installed or removed (or the dry run printed) | relays the `Run /reload-plugins` line when the script printed one — it does so only when something was installed or enabled |
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
  `/reload-plugins` and cannot do it for you.
- **Does not decide what you need.** That is `/stack-scan:suggest`, which reads your
  manifests and installs a picked set with evidence. This plugin is for the case where
  you have already decided you want everything.

## What has teeth

| Rule | Standing |
|---|---|
| The exit codes, the leaves-only list, the scope flag, zero prompts | **gate** — a mechanism, not prose: `scripts/all-plugins.sh` returns them, and a shim-driven harness, `scripts/__tests__/all-plugins.test.sh` (CI-globbed with every other plugin harness), fails the build if they drift |
| The commands relay the script instead of running `claude plugin install` themselves | **agent-graded** — it is instruction text in `commands/*.md`; nothing detects a substituted loop |
| The cost paragraph below | **recorded** — the overflow arithmetic is reproduced by `scripts/context-budget.sh`; the zero-delta firing result is one n=50 measurement, and nothing re-runs it in CI (`scripts/smoke/listing-eviction-probe.sh` needs a live model and `LISTING_PROBE=1`) |

## The cost, stated — and how much of it is measured

With every leaf installed, the host's skill listing overflows its budget — a formula,
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction`, 6,000 chars on a 200k
window and 30,000 at 1M — by about 6.6x and 1.3x respectively (`scripts/context-budget.sh`
prints the live figure as its EVERYTHING INSTALLED row). Over budget the host reduces
entries to name-only and buys descriptions back in priority order; hooks and agents are
not in that budget and load regardless. That arithmetic is reproduced and not in doubt.

What the overflow DOES is the part that was believed and then measured. This marketplace
said for weeks that a name-only skill "silently stops being reachable". On 2026-09-15 that
was tested with a control arm — the same skill with and without its description, at 1, 13,
226 and 205-with-rivals skills — and firing did not change: 47/50 against 47/50
(`rationale/2026-09-15-listing-eviction-probe.md`). What did move firing, in both arms, was
eight skills contesting the same territory. So the honest statement is: the listing
overflows, one measurement says that costs nothing you can detect, and that measurement is
one model, one target skill, one prompt shape, n=50 per arm, and it scored triggering only —
not whether the work that followed was as good. Raising `skillListingBudgetFraction` in
`settings.json` (0.066 at 200k, 0.014 at 1M) buys the descriptions back for roughly 13k
system-prompt tokens per turn; on that evidence it is not obviously worth paying.

The `everything` bundle that once existed served this same want and was removed on the
"unreachable" reading, before the probe. This plugin is a script, not a bundle: it has no `dependencies` key, so
the bundle listing gates (`pc_listing_declaration`, the README member check) do not
apply to it — which is why the cost is stated here instead of enforced by one.
