# Flags: --yes, --persist, --global

Full semantics for the three `/plugin-scout:suggest` flags. `SKILL.md` Flags
section is the short pointer; this file is the source of truth a reviewer
checks against.

## `--yes`

The auto-installer. Bypasses ONLY the AskUserQuestion install picker in the
Install section — every other step (Preflight, Detection, Report) runs
unchanged, and the full report table always prints before any install happens.

- Auto-select set, two parts, both filtered to not-already-installed:
  1. every tier-1 suggestion with a detection signal and cited evidence —
     the SKILL's stack table AND the `references/signals.md` rows alike;
  2. every tier-2 core row from `references/any-core.md` — the curated
     any-project set installs on every run because its usefulness does not
     depend on a signal.
- Tier-3 ("universal" / "no signal detected") suggestions are never
  auto-installed, under any flag combination — that floor is absolute. A mass
  install of the remainder must be a human pick through the picker.
- Zero auto-installable picks (nothing in either part not yet installed):
  print the report only, run no picker, and add a hint line to rerun without
  `--yes` to pick from the tier-3 set manually.
- Ambiguous Vue major (see Stack signals): `--yes` does not resolve the
  ambiguity. Suggest nothing for vue and keep the report's ambiguous-
  constraint line — an ambiguous signal is not a signal-backed pick. (There
  is no vue2 plugin to fall back to; it was removed after baseline testing.)
- Marketplace-add preflight is unaffected by `--yes`: adding a marketplace is
  a trust decision and is never silent. Interactive sessions still ask via
  AskUserQuestion as in Preflight. In headless mode with `--yes` set and the
  marketplace absent, stop before Detection and print: the marketplace-add
  command to run manually, and a note that `--yes` requires the marketplace
  to already be registered in headless mode. Do not fall back to
  command-printing mode here — that would silently skip the trust decision
  `--yes` is not allowed to skip.
- Headless without `--yes`: behavior is unchanged — print install commands
  instead of running them, then stop.
- Headless with `--yes` and the marketplace present: installs proceed for
  real (that is the point of the flag).
- Docs note: plugins installed via `--yes` may ship hooks (SessionStart,
  UserPromptSubmit, etc.) that activate in later sessions once installed —
  this is no different from a manual install, but is worth surfacing because
  the user did not see an install picker for these specific picks. The core
  set makes this more likely (secret-scanning and comment-discipline ship
  write-time hooks), so the summary line must name it.

## `--persist`

Changes the Install section's scope and adds a settings step afterwards; it
covers only what actually got installed this run. Mutually exclusive with
`--global` — see below.

- Install scope: with `--persist`, every `claude plugin install` this run uses
  `--scope project` instead of the default `--scope local` — the CLI itself
  records the `enabledPlugins` entries in the project's `.claude/settings.json`
  (repo-relative, the team-shared file — deliberately not user scope, since
  the point of `--persist` is that teammates who clone the repo get the same
  set without rerunning plugin-scout).
- Written set: exactly the plugins actually installed this run — the picker's
  picks, or the `--yes` auto-set (tier 1 + core). Never the full detected set
  and never plugins that were already installed before this run (they need no
  new entry). This mirrors the explicit-pick invariant the rest of the skill
  holds to.
- Settings step, after installs finish: verify `.claude/settings.json` carries
  both keys, merging in with `jq` whatever the CLI did not write itself —
  - `enabledPlugins`: `{"<name>@cc-plugins-marketplace": true}` — one entry
    per plugin installed this run.
  - `extraKnownMarketplaces`: `{"cc-plugins-marketplace": {"source":
    {"source": "github", "repo": "galaykos/cc-marketplace"}}}`.
- Merge, not overwrite: read the existing file with `jq`, deep-merge the
  missing entries into it, and write the merged result back — every unrelated
  existing key (other `enabledPlugins` entries, other settings) is preserved
  untouched.
- Missing file: create it, seeded as `{}`, then merge into that.
- Unparseable existing JSON: abort the settings step with a clear message
  naming the file and the parse error, and write nothing — do not overwrite a
  file the skill cannot safely parse. Installs that already ran at project
  scope are not rolled back; say so in the message.
- Required notice: after a successful write, print one line stating that
  committing this file means anyone who clones the repo and accepts the
  Claude Code trust prompt will auto-install these plugins.
- Removal note for docs: a persisted `true` entry re-installs the plugin the
  next time settings are read if someone runs `claude plugin uninstall`
  manually — uninstalling does not remove the settings.json entry. Removing a
  plugin from the persisted set requires editing `.claude/settings.json`
  directly.
- Running `--persist` inside the cc-marketplace repo itself is accepted and
  out of scope for special-casing — the self-reference is harmless.
- Combinable with `--yes`: run Install (auto-installing tier 1 + core), then
  persist that same set.

## `--global`

Changes the Install section's scope to the machine-wide user scope; no
settings step of its own — the CLI writes the user's own settings.

- Install scope: with `--global`, every `claude plugin install` this run uses
  `--scope user` — the user's `~/.claude/settings.json`, which enables each
  plugin in **every repo on this machine**, not just this project.
- Required notice: before the first install (in the report, and again in the
  summary line), print one line stating that user scope is machine-wide —
  these plugins will be active in every project the user opens.
- No project-settings step: `--global` writes nothing into the repo — no
  `.claude/settings.json`, no `.claude/settings.local.json` entries. The CLI
  owns the user-settings write; do not hand-merge `~/.claude` files.
- Mutually exclusive with `--persist`: the two name different owners for the
  same install (team-shared repo file vs personal machine-wide file). Both
  flags at once: abort before Preflight with one line naming the conflict and
  asking for exactly one of them. Nothing installs on the aborted run.
- Combinable with `--yes`: the auto-set (tier 1 + core) installs at user
  scope. This is the intended one-shot "set up my machine" path; the
  machine-wide notice above still prints — `--yes` never silences it.
- Headless: same rules as the other flags — without `--yes`, print the
  `--scope user` install commands and stop; with `--yes` and the marketplace
  registered, install for real.

## Scope model

Three modes, one flag surface — every install this run uses exactly one scope:

- Default: `--scope local` — this project's `.claude/settings.local.json`,
  gitignored, personal. Repo-only with zero commit surface.
- With `--persist`: `--scope project` — this project's `.claude/settings.json`,
  team-shared, committed.
- With `--global`: `--scope user` — the user's `~/.claude/settings.json`,
  machine-wide, every repo.
