# Flags: --yes, --persist, --global, --all

Full semantics for the `/plugin-scout:suggest` flags. `SKILL.md`'s Flags section
is the short pointer; this file is the source of truth a reviewer checks against.

## What "headless" means

Six branches in this plugin turn on it, so it needs one definition:

> **Headless** = the session cannot ask, i.e. the AskUserQuestion tool is
> unavailable (`claude -p` and other non-interactive runs). If AskUserQuestion is
> available, the session is interactive — **being a subagent does not make a run
> headless.**

Guessing wrong in one direction skips the entire picker and dumps a wall of
commands; in the other it hangs a `claude -p` run on a question nobody can answer.

## `--yes`

The auto-installer. Bypasses ONLY the install picker — every other step
(Preflight, Detection, Report) runs unchanged, and the full report always prints
before any install happens.

- Auto-select set, two parts, both filtered to not-already-installed:
  1. every tier-1 suggestion with a detection signal and cited evidence —
     the SKILL's stack table AND the `references/signals.md` rows alike;
  2. every tier-2 core row from `references/any-core.md` — the curated
     any-project set installs on every run because its usefulness does not
     depend on a signal.
- Tier-3 ("universal" / "no signal detected") suggestions are never
  auto-installed, under any flag combination. A mass install of the remainder
  must be a human pick. `--yes --all` is not a mass installer: `--all` changes
  only what the picker offers, and `--yes` skips the picker, so the two combined
  behave exactly like `--yes` alone. Say so rather than silently ignoring `--all`.
- Zero auto-installable picks (nothing in either part not yet installed):
  print the report only, run no picker, and add a hint line to rerun without
  `--yes` to pick from the tier-3 set manually.
- A signal that fired for a `—` row in `references/signals.md` (terraform, i18n)
  installs nothing — there is no plugin. Print its routing line instead; do not
  let `--yes` turn an uncovered stack into silence.
- Marketplace-add preflight is unaffected by `--yes`: adding a marketplace is
  a trust decision and is never silent. Interactive sessions still ask via
  AskUserQuestion as in Preflight. **In headless mode with `--yes` set and the
  marketplace absent, stop before Detection** and print: the marketplace-add
  command to run manually, and a note that `--yes` requires the marketplace to
  already be registered in headless mode. Do not fall back to command-printing
  mode here — that would silently skip the trust decision `--yes` is not allowed
  to skip. (`SKILL.md` Preflight says the same; if the two ever disagree, this
  file wins and the other is a bug.)
- Headless without `--yes`: print install commands instead of running them, then
  stop.
- Headless with `--yes` and the marketplace present: installs proceed for real
  (that is the point of the flag).
- Hooks note: plugins installed via `--yes` may ship hooks (SessionStart,
  UserPromptSubmit, PreToolUse) that activate once installed. The core set makes
  this certain, not merely likely — `secret-scanning` blocks writes containing
  secrets and `command-guard` denies destructive commands — so the summary line
  must name both by name. The user did not see a picker for these.

## `--all`

Restores exhaustive paging: every eligible row is offered as an explicit
checkbox, 15 per call, paging until all of them appeared or the user stops.
That is the pre-0.12 default; it now costs ~5 calls and ~20 questions and is
opt-in for the user who wants to see everything as options rather than as a
numbered report plus a door (`references/picker.md`).

- Changes the picker only. Detection, the report, install scope and the
  auto-install set are untouched.
- No effect under `--yes` (there is no picker to page) — see above.
- Combines freely with `--persist` and `--global`.

## `--persist`

Changes the Install section's scope and adds a settings step afterwards; it
covers only what actually got installed this run. Mutually exclusive with
`--global`.

- Install scope: with `--persist`, every `claude plugin install` this run uses
  `--scope project` instead of this skill's default `--scope local`. Note the
  CLI's OWN default is `user` (machine-wide): plugin-scout always passes
  `--scope` explicitly and must never omit it, or an install silently goes
  machine-wide.
- Marketplace scope follows: run the Preflight add as
  `claude plugin marketplace add galaykos/cc-marketplace --scope project` under
  `--persist`, so the declaration lands in the same team-shared file. Without the
  flag the add defaults to user scope.
- Written set: exactly the plugins actually installed this run — the picker's
  picks, or the `--yes` auto-set (tier 1 + core). Never the full detected set
  and never plugins that were already installed before this run.
- Settings step, after installs finish — **verify, do not author**:
  - `enabledPlugins`: the CLI writes these itself at `--scope project`. Read
    `.claude/settings.json` and CONFIRM one `"<name>@cc-plugins-marketplace": true`
    entry per plugin that installed **successfully** this run. Report any missing
    entry rather than adding it. Hand-writing this key for an install that failed
    produces a repo whose settings enable a plugin nobody has — the CLI has a
    dedicated error for that state ("only the repository's settings enable it and
    it is not installed on this machine").
  - `extraKnownMarketplaces`: merge with `jq` if absent —
    `{"cc-plugins-marketplace": {"source": {"source": "github", "repo": "galaykos/cc-marketplace"}}}`.
    Redundant when the scoped marketplace add above ran; harmless, and it covers
    the case where the marketplace was already registered at user scope.
- Merge, not overwrite: read the existing file with `jq`, deep-merge the missing
  entry into it, and write the merged result back — every unrelated existing key
  is preserved untouched.
- Missing file: create it, seeded as `{}`, then merge into that.
- Unparseable existing JSON: abort the settings step with a clear message naming
  the file and the parse error, and write nothing — do not overwrite a file the
  skill cannot safely parse. Installs that already ran at project scope are not
  rolled back; say so in the message.
- Required notice: after a successful write, print one line stating that
  committing this file means anyone who clones the repo and accepts the Claude
  Code trust prompt will auto-install these plugins.
- Re-running `--persist` is idempotent only if detection reads the settings
  files too — see the Preflight note in `SKILL.md`. A project-scope entry that
  the CLI wrote is not always reported as an install, so a scout that reads only
  `claude plugin list` re-offers and re-installs the same set every run.
- Removing a plugin from the persisted set: run
  `claude plugin uninstall <name>@cc-plugins-marketplace --scope project`. The
  bare command defaults to `--scope user` and fails with "not installed at scope
  user". Then confirm the `enabledPlugins` entry is gone from
  `.claude/settings.json`; if it remains, delete it by hand, or the next settings
  read re-enables the plugin.
- Running `--persist` inside the cc-marketplace repo itself is accepted and out
  of scope for special-casing — the self-reference is harmless.
- Combinable with `--yes`: run Install (auto-installing tier 1 + core), then
  persist that same set.

## `--global`

Changes the Install section's scope to the machine-wide user scope; no settings
step of its own — the CLI writes the user's own settings.

- Install scope: with `--global`, every `claude plugin install` this run uses
  `--scope user` — the user's `~/.claude/settings.json`, which enables each
  plugin in **every repo on this machine**, not just this project.
- Required notice: before the first install (in the report, and again in the
  summary line), print one line stating that user scope is machine-wide —
  these plugins will be active in every project the user opens.
- No project-settings step: `--global` writes nothing into the repo. The CLI
  owns the user-settings write; do not hand-merge `~/.claude` files.
- Mutually exclusive with `--persist`: the two name different owners for the
  same install (team-shared repo file vs personal machine-wide file). Both flags
  at once: abort **before Preflight** with one line naming the conflict and
  asking for exactly one of them — before the marketplace-add trust prompt can
  fire, not merely before the installs.
- Combinable with `--yes`: the auto-set installs at user scope. This is the
  intended one-shot "set up my machine" path; the machine-wide notice still
  prints — `--yes` never silences it.
- Headless: same rules as the other flags.

## Scope model

Three modes, one flag surface — every install this run uses exactly one scope:

- Default: `--scope local` — this project's `.claude/settings.local.json`,
  personal. **Claude Code does not gitignore this file for you.** Run
  `git check-ignore .claude/settings.local.json`; if it comes back unignored,
  tell the user to add the rule, or the "personal" set is commit surface.
- With `--persist`: `--scope project` — this project's `.claude/settings.json`,
  team-shared, committed.
- With `--global`: `--scope user` — the user's `~/.claude/settings.json`,
  machine-wide, every repo.

## Standing

**Agent-graded, all of it.** No script checks that `--yes` stopped at tier 2,
that the marketplace-add prompt fired, that the `--persist` merge preserved
unrelated keys, or that the machine-wide notice printed. Those are model
behaviours a reviewer judges, and the absolute-sounding wording above ("never",
"always") states a contract, not a guarantee.

The residual worth naming: the `--persist` abort path writes to a **committed**
file. If the model merges anyway after a parse error, or authors an
`enabledPlugins` entry for a failed install, nothing here catches it — only a
human reading the diff does.
