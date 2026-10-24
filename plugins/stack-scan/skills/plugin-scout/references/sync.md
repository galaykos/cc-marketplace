# `--sync`: this project's plugins, at this project's scope

The reconcile mode. `SKILL.md`'s Flags bullet is the short pointer; this file is the
source of truth a reviewer checks against.

The default flow suggests and installs. `--sync` compares what is ENABLED here, scope by
scope, with what this project should have — tier 1 (signals that fired) plus tier 2
(`references/any-core.md`) — and closes the gap at local scope (`--persist`: project). It
is how a machine that installed everything at user scope moves to per-project installs
without leaving any project bare.

## Why the default flow cannot do this

Preflight's installed set is a union: a plugin enabled at user scope counts as installed
in every project, so a repo that relied on user scope shows every row `✓` and the picker
offers nothing. Which file enables a plugin decides whether a project still has it after
user scope is emptied, and only a per-scope read can tell.

## Steps

1. **Preflight** as in `SKILL.md` (marketplace present, `claude` CLI available). No
   `claude` CLI: print the plan and its commands, run nothing.
2. **Detection** as in `SKILL.md`. The recommended set is every fired tier-1 row (the
   stack table and `references/signals.md`) plus every tier-2 core row. No tier 3, no
   relevance pass, no picker — a sync never adds a plugin no signal or core row earned.
3. **Plan** — run the scope script with the recommended names:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/sync-plan.sh" --root "$PWD" [--persist] <name>...
   ```

   It prints `class<TAB>name<TAB>scope<TAB>command` rows (classes below). Exit 2 means it
   refused — an unparseable settings file or a name the catalog lacks; show its stderr
   line and stop. Never classify the settings files by hand instead.
4. **Report** — one header line (`Sync — <project> → <local|project> scope`, the detected
   stack), then one line per non-empty class with its plugin names, in the script's order.
   Name each `extra` row's tier (a tier-3 pick, opt-in `prompt-coach`, or `all-plugins`).
   A `note worktree` row prints: this is a linked worktree; local scope is recorded per
   path, so its installs cover this worktree alone — `--persist` writes the committed file
   every worktree checks out.
5. **Ask once** (AskUserQuestion), only when an `add`/`move` or a removable row exists:
   - `Install the missing N (Recommended)` — every `add` and `move` command
   - `Install the missing N and remove M` — also every `extra` and `duplicate` row that
     carries a command; offered only when M > 0
   - `Print the commands instead`
   - `Stop`

   Nothing to install or remove: say `in sync` and skip to step 7.
6. **Apply** — run each command from the script's fourth column, verbatim. Exit 0 is the
   only success; a failure does not abort the rest. Summary: installed n, removed r,
   failed m. Under `--persist`, run `references/flags.md`'s `--persist` verify step for
   what installed. Then the `/reload-plugins` line, naming the hooks a core install adds
   (`secret-scanning` and `command-guard` deny writes and commands; `candor`'s Stop gate
   can refuse a final message).
7. **Off-ramp** — an `offramp` row means user scope still enables N of this marketplace's
   plugins in every project. Print its command, and never run it: it is machine-wide,
   and any project not synced yet loses its plugins with it. The line to print: sync each
   project you use first, then run the command once.

## Row classes

| Class | Meaning | Command |
|---|---|---|
| `add` | recommended, enabled in no settings file | install at the target scope |
| `move` | recommended, enabled only at user scope | install at the target scope; the user-scope entry stays until the off-ramp |
| `held` | recommended, but a settings file sets it `false` | none — a disable is the user's decision; name the file |
| `extra` | enabled at local or project, not recommended | uninstall at that scope; a project-scope extra gets one only under `--persist` |
| `duplicate` | a local copy of a project-scope entry | uninstall the local copy; the project entry keeps it enabled |
| `ok` | recommended and enabled at local or project | none |
| `machine-wide` | enabled only at user scope, not recommended | none — other projects may rely on it |
| `unknown` | enabled, but not in this stack-scan's catalog | none — removed from the marketplace, or newer than this stack-scan |

## Rules

- **Never touches user scope.** No install, uninstall or disable at `--scope user`; the
  off-ramp is printed. A project-scope `extra` without `--persist` is reported only:
  `.claude/settings.json` is the team's file.
- **Removal is never the default.** An `extra` is often a deliberate tier-3 pick. Only the
  second option removes, and `--yes` never selects it.
- **stack-scan is always in the set.** The script adds it, so a synced project keeps the
  tool that manages it after the off-ramp.
- `--sync --yes` — runs the first option without asking; still prints the plan first.
  Headless without `--yes`: print the plan and its commands, then stop.
- `--sync --persist` — target project scope; the `--persist` notice and verify step apply.
- `--sync` with `--global`, `--full`, `--all`, `--stack` or `--skills` aborts before
  Preflight with one line: sync works on one project's scopes, and those flags pick a
  different set or a machine-wide scope.

## A bare project

A project with no plugin of this marketplace enabled has no `/stack-scan:suggest` to run.
Bootstrap it from the shell, start a session, then sync:

```bash
claude plugin install stack-scan@cc-plugins-marketplace --scope local   # or --scope project
/stack-scan:suggest --sync --yes
```

## Moving a machine off user scope

1. In each project you use: `/stack-scan:suggest --sync` (`--persist` where the team
   should share the set).
2. Then once, from any shell — the command the `offramp` row prints:
   `bash ~/.claude/plugins/marketplaces/cc-plugins-marketplace/plugins/all-plugins/scripts/all-plugins.sh uninstall --scope user --self`
3. A project you missed is bare afterwards; bootstrap it as above.

## Standing

**Gate** for the classification — `scripts/__tests__/sync-plan.test.sh` drives
`scripts/sync-plan.sh` against fixture settings files: precedence (local over project
over user), `held`, `duplicate`, project extras gated on `--persist`, foreign
marketplaces ignored, the worktree note, the off-ramp, and every refusal.
**Agent-graded** for everything around it: that Detection fed the script the right set,
that the ask came before any change, that only column-four commands ran, that user scope
was never touched. Not read: managed policy settings, a `--settings` file, a
`--plugin-dir` load, and install records (a project-scope `true` this machine never
installed classes as enabled).
