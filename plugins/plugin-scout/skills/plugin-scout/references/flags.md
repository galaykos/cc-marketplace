# Flags: --yes and --persist

Full semantics for the two `/plugin-scout:suggest` flags. `SKILL.md` Flags
section is the short pointer; this file is the source of truth a reviewer
checks against.

## `--yes`

Bypasses ONLY the AskUserQuestion install picker in the Install section — every
other step (Preflight, Detection, Report) runs unchanged, and the full report
table always prints before any install happens.

- Auto-select set: every tier-1 suggestion that (a) has a detection signal
  with cited evidence and (b) is not already installed. Tier-2 ("universal")
  suggestions are never auto-installed, under any flag combination — that
  floor is absolute.
- Zero tier-1 picks (nothing signal-backed and not-yet-installed): print the
  report only, run no picker, and add a hint line to rerun without `--yes` to
  pick from the tier-2 set manually.
- Ambiguous Vue major (see Stack signals): `--yes` does not resolve the
  ambiguity. Install neither vue plugin and keep the report's ambiguous-
  constraint line — an ambiguous signal is not a signal-backed pick.
- Marketplace-add preflight is unaffected by `--yes`: adding a marketplace is
  a trust decision and is never silent. Interactive sessions still ask via
  AskUserQuestion as in Preflight. In headless mode with `--yes` set and the
  marketplace absent, stop before Detection and print: the marketplace-add
  command to run manually, and a note that `--yes` requires the marketplace
  to already be registered in headless mode. Do not fall back to
  command-printing mode here — that would silently skip the trust decision
  `--yes` is not allowed to skip.
- Headless without `--yes`: behavior is unchanged from today — print install
  commands instead of running them, then stop (A2).
- Headless with `--yes` and the marketplace present: installs proceed for
  real (that is the point of the flag; A2).
- Docs note: plugins installed via `--yes` may ship hooks (SessionStart,
  UserPromptSubmit, etc.) that activate in later sessions once installed —
  this is no different from a manual install, but is worth surfacing because
  the user did not see an install picker for these specific picks (R13).

## `--persist`

Runs after the Install section completes (whether install ran via the picker
or via `--yes`), and only writes what actually got installed.

- Target: the project's `.claude/settings.json` (repo-relative, the
  team-shared file — deliberately not a user-scope file, since the point of
  `--persist` is that teammates who clone the repo get the same set without
  rerunning plugin-scout) (R6).
- Written set: exactly the plugins actually installed this run — the picker's
  picks, or the `--yes` tier-1 auto-set. Never the full detected set and never
  plugins that were already installed before this run (they need no new
  entry). This mirrors the explicit-pick invariant the rest of the skill
  holds to (R4).
- Shape (Verified platform facts):
  - `enabledPlugins`: `{"<name>@cc-plugins-marketplace": true}` — one entry
    per plugin written this run.
  - `extraKnownMarketplaces`: `{"cc-plugins-marketplace": {"source":
    {"source": "github", "repo": "galaykos/cc-marketplace"}}}`.
- Merge, not overwrite: read the existing file with `jq`, deep-merge the new
  `enabledPlugins` entries and the `extraKnownMarketplaces` entry into it, and
  write the merged result back — every unrelated existing key (other
  `enabledPlugins` entries, other settings) is preserved untouched (A3).
- Missing file: create it, seeded as `{}`, then merge into that (R2).
- Unparseable existing JSON: abort `--persist` with a clear message naming the
  file and the parse error, and write nothing — do not overwrite a file the
  skill cannot safely parse (R2).
- Required notice: after a successful write, print one line stating that
  committing this file means anyone who clones the repo and accepts the
  Claude Code trust prompt will auto-install these plugins (R6).
- Removal note for docs: a persisted `true` entry re-installs the plugin the
  next time settings are read if someone runs `claude plugin uninstall`
  manually — uninstalling does not remove the settings.json entry. Removing a
  plugin from the persisted set requires editing `.claude/settings.json`
  directly (R8).
- Running `--persist` inside the cc-marketplace repo itself is accepted and
  out of scope for special-casing — the self-reference is harmless (R9).
- Combinable with `--yes`: run Install (auto-installing the tier-1 set), then
  persist that same set.

## Not in scope

No new `--scope` flag: direct `claude plugin install` calls keep the CLI
default (user scope) regardless of these flags; `--persist` is the mechanism
for per-repo/team persistence, so a separate scope flag would be redundant
(A4, D2).
