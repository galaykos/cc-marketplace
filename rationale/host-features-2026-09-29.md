# Host plugin features — `renames`, `forceRemoveDeletedPlugins`, `userConfig`, `${CLAUDE_PLUGIN_DATA}` (2026-09-29)

Four host features the marketplace wants to adopt: `renames` and `forceRemoveDeletedPlugins` in
`.claude-plugin/marketplace.json` (to clean up installs of removed plugins), and `userConfig` +
`${CLAUDE_PLUGIN_DATA}` in plugins (to declare off-switches and move hook state). This note records
what the official docs say about each one and what the CLI actually did. Where the two disagree,
the measurement wins, and the disagreement is written down.

**Method.** Every experiment ran under `env -i` with a scratch `HOME` and `CLAUDE_CONFIG_DIR`
(`mktemp -d`); the real `~/.claude` was never used.

- **Test marketplaces.**
  - `hf-test` holds plugins `a`, `b`, `opt`, `p1` and `p2`.
    - `opt` declares a boolean and a string option, both with defaults.
    - `p1` and `p2` both declare an option named `cc_remind`.
    - Each of those three has a SessionStart hook that writes `CLAUDE_PLUGIN_DATA`, every
      `CLAUDE_PLUGIN_OPTION_*` and `CLAUDE_PROJECT_DIR` to a file.
    - The TTY install check added `optnd`: one defaulted option, and one with no default and no
      `required`.
  - `hf-deps` holds `suite`, which declares `dependencies` on `dep-a` and `dep-b`.
  - One replay used this repo's real `core-suite`, taken from history with
    `git archive 6e51639b^` (marketplace 0.115.0, before the suites were retired).
- **Sources.** Most runs used a directory source. The git runs served the repo over a local
  smart-HTTP `git http-backend`, because the CLI rejects `file://` URLs
  (`Invalid marketplace source format`).
- **Modes**, as used in the labels below:
  - *CLI* — a `claude plugin …` subcommand, run with stdin closed (no TTY) unless marked "under a
    pseudo-terminal".
  - *-p* — `claude -p "ok" --max-turns 1` with **no login**. It exits `Not logged in · Please run
    /login`, but still ran SessionStart hooks on every build tested. At session start it
    uninstalled plugins on 2.1.191 and later, and migrated renamed plugins (rewrote the key and
    installed the successor) on 2.1.282.
  - *TUI* — the interactive UI driven in a pseudo-terminal, with a placeholder API key and
    `ANTHROPIC_BASE_URL` pointed at a closed local port so no model request left the machine.
- **The real config was not touched.** No file under the real `~/.claude` mentions any test
  marketplace (checked by grep afterwards).

**Standing labels** follow CLAUDE.md "Say what has teeth":
- *measured (CLI version, mode)*: a command was run and its output is quoted.
- *doc-stated*: read on the page cited in `## Sources` and not re-measured.
- *inferred*: reasoned from a measurement or a doc line, not run.
- *untested because …*: not run, with the reason.

**Every session result below comes from `-p` with no login, or from the TUI with a placeholder
key.** No logged-in session was run, and one could, in principle, differ.

## Sources

- https://code.claude.com/docs/en/plugins/host-marketplace, sections "Rename or remove a plugin", "Migrate users with a renames map" and "Uninstall removed plugins from users' machines" — accessed 2026-09-29
- https://code.claude.com/docs/en/plugins/marketplace-reference, the top-level field table (`renames`, `forceRemoveDeletedPlugins`) and the validation-message table — accessed 2026-09-29
- https://code.claude.com/docs/en/plugins/manifest-reference ("Plugin manifest reference"), sections "User configuration", "Unrecognized fields" and "Environment variables" — accessed 2026-09-29
- https://code.claude.com/docs/en/settings-reference, section `pluginConfigs` — accessed 2026-09-29
- https://code.claude.com/docs/en/plugins/cli-reference (`plugin install --config`, `plugin uninstall --keep-data`, `plugin prune`) — accessed 2026-09-29
- https://code.claude.com/docs/en/plugins/dependencies — accessed 2026-09-29
- https://code.claude.com/docs/en/changelog — accessed 2026-09-29. Cross-checked against https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md (same day); both carry the same entries quoted below.
- **CLI builds.**
  - Native builds under `~/.local/share/claude/versions/`: 2.1.281; 2.1.282, the pin
    (`scripts/official-validate.sh` `PIN=` and `.github/workflows/validate.yml`); 2.1.283; 2.1.284.
  - From npm (`@anthropic-ai/claude-code`) into a throwaway prefix: 2.1.191 and 2.1.81.
  - **2.1.192 and 2.1.82 were never published**: `npm view` returns E404, and the published list skips
    from 2.1.191 to 2.1.193 and from 2.1.81 to 2.1.83.

## renames

- **Schema:**
  - A top-level object in `marketplace.json` that maps each former plugin `name` to its current name,
    or to `null` for a plugin you removed (marketplace-reference field row, accessed 2026-09-29).
  - A target must be a name in `plugins[]`, another key in `renames`, or `null`.
  - `claude plugin validate` reports a bad chain as `chain does not resolve (<reason>)` and a bad
    target as `target "x" is not a valid plugin name (PluginIdSchema)`.
- **Semantics:**
  - **Doc-stated** (host-marketplace, "Migrate users with a renames map", accessed 2026-09-29):
    - a rename rewrites the old key to the new one in **both `enabledPlugins` and `pluginConfigs`**,
      in user, project and local settings;
    - "Treat `renames` as append-only history" — keep old entries after everyone has migrated, and add
      a second entry rather than editing the first, because Claude Code "follows the chain from the
      oldest name".
  - **Rename, target not yet installed** — measured (2.1.282, CLI + -p), directory and git sources.
    Install `a`, remove its entry, add `"renames": {"a": "b"}`, run `claude plugin marketplace
    update`, then:
    - The first `claude plugin list` prints `Note: Renamed to "b" in the "hf-test" marketplace`.
    - The same command rewrites `enabledPlugins` from `a@hf-test` to `b@hf-test` and deletes `a`'s
      install record.
    - Until the next session start, `b` is enabled but not installed: a second `plugin list` prints
      `No plugins installed.`
    - The next session start installs `b`.
    - A session start with no `plugin list` before it does the whole migration: key rewritten and `b`
      installed.
    - *Untested because* the options were not saved for this plugin: the `pluginConfigs` half of the
      rewrite.
  - **Git-source not-cached window.** The not-cached window lasts until the next session start on
    2.1.282 (measured with local smart-HTTP git and `-p`). The doc's one-time
    `/plugin install <successor>@<marketplace>` advice for git-hosted marketplaces stays in place for
    GitHub users: a GitHub-hosted marketplace was not measured, and the advice costs nothing when the
    successor is already installed.
  - **Rename, target already installed (the merge case)** — measured (2.1.282, CLI + -p), git source:
    - `plugin list` shows both plugins, with the note on `a`.
    - Afterwards `enabledPlugins` is `{b@hf-test: true}` and only `b` is installed. No duplicate, no
      error.
    - `a`'s old cache directory is left on disk.
  - **Chains.** A two-step chain (`x→y`, `y→a`) passes validation. *Untested because* only validation
    needed it here: migrating an install through a multi-step chain.
  - **No host check that a renamed plugin is really gone.** `{"a": "b"}` while `a` is still listed in
    `plugins[]` passes `validate --strict` — measured (2.1.282, CLI). Any such check must be local.
  - **`null` values:** see `## forceRemoveDeletedPlugins`.
- **Minimum CLI:** 2.1.193.
  - Doc-stated on host-marketplace ("Automatic migration requires Claude Code v2.1.193 or later") and
    on the marketplace-reference row.
  - The changelog's 2.1.193 entry: "marketplace `renames` maps are now followed automatically".
- **On the pinned CLI (2.1.282):** measured (2.1.282, CLI) with `claude plugin validate --strict <dir>`.
  - Exit 0 (`✔ Validation passed`) for one manifest holding a `null` value, the two-step chain and
    `forceRemoveDeletedPlugins: true`. The same file also passes on 2.1.281, 2.1.283 and 2.1.284.
  - Exit 1 for a cycle: `renames.p: chain does not resolve (cycle) — target must be a name in
    plugins[], a key in renames, or null`.
  - Exit 1 for a target that is not listed: `renames.old: chain does not resolve (target-missing)`.
- **Standing:**
  - Measured on 2.1.282: validation, the rename, the merge case and the session-start install.
    The session-start parts ran in unauthenticated `-p` mode.
  - Doc-stated only:
    - the `pluginConfigs` rewrite;
    - the append-only rule;
    - the rewrite in project and local settings;
    - the recurring notice under managed settings.
  - *Untested because* every install here was user scope: project, local and managed behaviour.

## forceRemoveDeletedPlugins

- **Schema:** a top-level boolean in `marketplace.json`. Documented in the marketplace-reference
  field row and in host-marketplace "Uninstall removed plugins from users' machines" (both accessed
  2026-09-29).
- **Semantics:**
  - **Doc-stated.** At each session start Claude Code uninstalls every installed plugin from the
    marketplace that is "neither listed nor renamed". It does this in user, project and local scope;
    installs made only by managed settings stay. Each removed plugin is listed under **Flagged** as
    `Removed from marketplace`.
  - **Measured (2.1.282, CLI + -p).** Install `a`, delete its entry, run `marketplace update`, then:

    | marketplace change | `claude plugin list` | after the next session start |
    |---|---|---|
    | `renames: {"a": null}` + flag | `Note: Removed from the "hf-test" marketplace`, key dropped from `enabledPlugins`, then `✘ disabled` | uninstalled (install record gone) |
    | `renames: {"a": null}`, no flag | same note, then `✘ disabled` | still installed, disabled |
    | `renames: {"a": "b"}` + flag | `Note: Renamed to "b"…` | `a` gone, `b` installed and enabled (normal migration) |
    | flag, no `renames` entry | `✘ failed to load` / `Error: Plugin a not found in marketplace hf-test` | uninstalled, key dropped |
    | neither | same failure | still installed; fails to load every session |

    - `plugin list` never uninstalls anything; only session start does.
    - After the uninstall the plugin's cache directory is still on disk.
  - **Removing a plugin that pulled in dependencies** — measured (2.1.282, CLI + -p).
    - **Synthetic case.** `suite` declares `dependencies: ["dep-a", "dep-b"]`.
      `claude plugin install suite@hf-deps` printed `(+ 2 dependencies: dep-a, dep-b)`, and
      `installed_plugins.json` marks both with `"auto": true`.
    - **Four runs**, each dropping `suite` from `plugins[]` with the flag set:
      - `{"suite": null}` in `renames`, dependencies auto-installed;
      - no rename entry, dependencies auto-installed;
      - `{"suite": null}`, with `dep-a` and `dep-b` also installed explicitly before `suite` (no
        `auto` mark);
      - no rename entry, with `dep-a` and `dep-b` also installed explicitly.
    - **Result, identical in all four.** After one session start, `suite` is uninstalled and `dep-a`
      and `dep-b` stay **installed and enabled**.
    - **The one difference is `claude plugin prune --dry-run`.**
      - Auto-installed members show as `2 auto-installed plugins no longer needed at user scope`, so a
        later `claude plugin prune -y` would remove them.
      - Explicitly installed members print `Nothing to prune`.
    - **Real `core-suite` replay.**
      - In a throwaway config, `claude plugin install core-suite@cc-plugins-marketplace` from the
        0.115.0 snapshot pulled in 7 members, all `auto`: candor, code-review, git-workflow,
        hindsight, secret-scanning, skill-router, stack-scan.
      - The snapshot was then republished without `core-suite`, with `{"core-suite": null}` and the
        flag.
      - One session start uninstalled `core-suite`. All 7 members stayed installed and enabled, and
        `plugin prune --dry-run` listed all 7 as `no longer needed`.
      - Re-running `claude plugin install candor@cc-plugins-marketplace` printed `already installed …
        marked as manually installed`. That cleared `candor`'s `auto` mark, and the prune list dropped
        to 6.
    - **What cleanup text must say:**
      - Force-removing a retired suite did not remove its members — measured (2.1.282, -p).
      - The members can still be removed two other ways:
        - a later `claude plugin prune`;
        - `claude plugin uninstall <suite> --prune`, which the docs say "also remove[s]
          auto-installed dependencies that no remaining plugin needs" (doc-stated, cli-reference,
          accessed 2026-09-29).
      - A user who wants to keep a member should run
        `claude plugin install <member>@cc-plugins-marketplace` once, to mark it manually installed.
  - *Not driven:* the **Flagged** heading and its status line in `/plugin`. TUI mode was available,
    but no `/plugin` screen was opened after a removal.
  - *Untested because* only user scope was installed: project and local scope.
- **Minimum CLI:** no doc page and no changelog entry states a minimum.
  - Measured (2.1.191, CLI + -p): the flag-only, flag + `null` and flag + non-null-rename cases were
    all uninstalled at session start. See `## Older CLI behaviour` for why the rename case is a hazard
    there.
  - On 2.1.81, plain `validate` does not flag the key as unknown, and an unauthenticated `-p`
    session did **not** uninstall `a` — measured (2.1.81, CLI + -p). That 2.1.81 carries an uninstall
    routine is *inferred* from reading its `cli.js`; the routine was not seen to run.
  - No bisect was run: no consumer needs a bound below the pin.
- **On the pinned CLI (2.1.282):** `validate --strict` passes with the flag set (see the pinned bullet
  under `## renames`), and the behaviour matches the tables above.
- **Standing:**
  - Measured on 2.1.282: the table, and the dependency and `core-suite` runs.
  - Measured on 2.1.191: the flag cases.
  - All session-start results come from unauthenticated `-p` runs.
  - Doc-stated: the scope rules and the Flagged listing.
  - Unexplained on 2.1.81: the key is known, but no removal was observed in an unauthenticated
    session.

## userConfig

- **Schema:** manifest-reference "User configuration", accessed 2026-09-29.
  - A top-level `plugin.json` object whose keys match `^[A-Za-z_]\w*$`.
  - Each option is a strict object:
    - required: `type` (`string` | `number` | `boolean` | `directory` | `file`), `title`,
      `description`;
    - optional: `default`, `required`, `options`, `multiple`, `sensitive`, `min`/`max`.
  - `required: true` makes the configuration dialog refuse an empty value (doc-stated: "the
    configuration dialog doesn't accept an empty value").
  - An unknown key inside an option means the plugin does not load. Measured (2.1.282, CLI):
    `userConfig.level: Invalid input`, exit 1.
- **Semantics:** install-time prompt.
  - **`claude plugin install opt@hf-test` with no TTY** — measured (2.1.282, CLI):
    - No prompt and no block. It prints `2 userConfig options not yet set — run /plugin configure
      opt@hf-test in Claude Code, or pass --config KEY=VALUE.`
    - The plugin is enabled and nothing is written to `pluginConfigs`.
  - **`claude plugin install` from a terminal, with a TTY** — measured (2.1.282 and 2.1.284, CLI
    under a pseudo-terminal, no input sent):
    - Run for two plugins: `opt` (all options defaulted) and `optnd` (one option with no default and
      no `required`).
    - On both builds and for both plugins: no prompt. The same one-line notice is printed and the
      process exits on its own, exit 0, in 0.2–0.4 s.
    - The plugin is enabled and nothing is written to `pluginConfigs`.
    - `--config quiet=true --config level=terse` writes
      `pluginConfigs["opt@hf-test"].options = {level: "terse", quiet: true}`.
  - **Interactive `/plugin install` of a plugin whose options ALL have defaults and none is
    `required`** — measured (2.1.282, TUI) and (2.1.284, TUI):
    - **The Configure dialog opens.** After the scope choice the screen shows `Configure opt` /
      `Plugin options` / `❯ Quiet` / `Level` / `Save configuration`, with the hint
      `Enter to continue · Esc to cancel`.
    - On 2.1.284 the boolean row is a toggle, `❯ Quiet ◀ false ▶`, and the hint gains
      `←/→ to change` (changelog 2.1.284: boolean options are now a true/false choice).
    - This is the doc's "prompts the user for when the plugin is enabled".
    - It does not block: the plugin is active before the dialog is answered. Observed by reading
      `settings.json` while the dialog was still on screen: `enabledPlugins` already held
      `opt@hf-test: true` and `pluginConfigs` was absent (2.1.282, TUI).
    - **Esc** gives `✓ Installed opt. Plugin is now active.` and saves nothing (2.1.282 and 2.1.284).
    - **Enter through every row without typing:**
      - on 2.1.282: the same line, and **nothing** is saved;
      - on 2.1.284: `✓ Installed and configured opt.`, and the boolean's displayed default is
        **saved**, `pluginConfigs["opt@hf-test"].options = {quiet: false}`. The string default is not
        saved.
    - **Typing a value into one row** (2.1.282): `✓ Installed and configured opt.`, and only that key
      is saved.
  - **Updating an installed plugin to a version that adds `userConfig`** — measured (2.1.282, update
    via CLI; next TUI start). `claude plugin update` (0.1.0 → 0.2.0) printed no notice and no prompt,
    and the next TUI start showed no dialog.
    - *Untested:* updating from inside the TUI (`/plugin` update), and marketplace auto-update.
  - **A headless session with nothing saved** — measured (2.1.282, -p): no prompt; the plugin loads
    and its hooks run.
- **Semantics:** export to hooks — measured (2.1.282, -p); the nothing-saved and saved-`false` cases
  also on 2.1.284.
  - **Nothing saved:** no `CLAUDE_PLUGIN_OPTION_*` variable at all. It is not the `default` and not
    empty; `${VAR-<unset>}` printed `<unset>` for every option. The doc's "exported to hook processes
    for every option" holds only for options with a **saved** value.
  - **Only `level` saved:** `CLAUDE_PLUGIN_OPTION_LEVEL=terse`, while unsaved options stay absent.
  - **Saved `true`:** exported as the string `true`.
  - **Saved `false`:**
    - `--config quiet=false` stores `{quiet: false}` and the hook sees `CLAUDE_PLUGIN_OPTION_QUIET=false`:
      present, the literal string `false`, not empty. Measured (2.1.282, CLI + -p) and (2.1.284,
      CLI + -p).
    - A `/plugin configure` toggle to `true` and back to `false` saved `{quiet: false}` (`Configuration
      saved.`), and the hook saw `false`. Measured (2.1.284, TUI + -p).
    - The `/config` panel row was not driven.
  - **Two plugins declaring the same key** — measured (2.1.282, CLI + -p). `p1` and `p2` both declare
    `cc_remind`, saved as `off-from-p1` and `on-from-p2`. Each hook saw only its own plugin's value:
    `p1` got `CLAUDE_PLUGIN_OPTION_CC_REMIND=off-from-p1`, `p2` got `…=on-from-p2`. Option values are
    per plugin even when the key name is shared.
  - **User environment variables:**
    - A user-set `CC_*` variable reaches the hook unchanged.
    - A user-set `CLAUDE_PLUGIN_OPTION_LEVEL=user-env` is **overwritten** by a saved `terse`.
    - A user-set `CLAUDE_PLUGIN_OPTION_QUIET=user-env` for an option with no saved value passes
      through unchanged.
  - **Consequence for a hook's resolver:**
    - A manifest `default` never reaches a hook's **environment** unless it has been saved. A resolver
      that reads env → `CLAUDE_PLUGIN_OPTION_<NAME>` → default must carry its own fallback, equal to
      the manifest's `default`. That is two copies of each default, and nothing in the host keeps them
      equal.
    - On 2.1.284 an accepted dialog can save a boolean's default, and that saved value then outranks
      any later change to the plugin's `default` — *inferred*.
  - **Other hook events.** Export to hooks other than SessionStart is doc-stated (the "Where each
    variable resolves" table lists hook commands generally). Only SessionStart was measured.
  - **Where saved values are read from:** since 2.1.207, only user, `--settings` and managed settings;
    project and local settings are ignored. Doc-stated (settings-reference `pluginConfigs`; changelog
    2.1.207).
- **Minimum CLI:**
  - `userConfig` itself: 2.1.83. Changelog 2.1.83: "Plugin options (`manifest.userConfig`) now
    available externally".
  - `/config` rows: 2.1.269 (doc).
  - `options`: 2.1.271 (doc: "users on Claude Code versions before v2.1.271 can't load the plugin").
  - `plugin install --config`: 2.1.147 (cli-reference).
  - The `CLAUDE_PLUGIN_OPTION_*` export has no minimum of its own in either source. Its first
    changelog mention is 2.1.207, which rejects `${user_config.*}` in shell-form hooks and points to
    `$CLAUDE_PLUGIN_OPTION_<KEY>`. Measured absent on 2.1.81 (-p).
- **On the pinned CLI (2.1.282):** measured (2.1.282, CLI) with `claude plugin validate --strict
  <plugin>`.
  - Exit 0 for each of:
    - a boolean and a string option, each with `default` and without `required`;
    - the same plus an option with no default;
    - an option with `required: true` and no default;
    - an `options` list whose default is one of the options.
  - Exit 1 for an unknown key inside an option.
- **Standing:**
  - Measured on 2.1.282: prompt behaviour on the CLI (no TTY and TTY) and TUI paths, export, and the
    shared-key case.
  - Measured on 2.1.284: the TUI dialog, CLI install under a TTY, the saved-`false` export and the
    nothing-saved export.
  - Hook-environment results come from unauthenticated `-p` sessions.
  - Doc-stated:
    - the `required` empty-value rule;
    - `sensitive`/keychain storage;
    - the `/config` rows;
    - export to hook events other than SessionStart.
  - *Untested because not needed here:* `${user_config.KEY}` substitution in exec-form `args`, and
    how `sensitive` values are exported.

## CLAUDE_PLUGIN_DATA

- **Schema:** a path variable. Doc-stated (manifest-reference "Environment variables", accessed
  2026-09-29):
  - It resolves to `~/.claude/plugins/data/<id>/`, **created on first reference**.
  - `<id>` is the plugin identifier with every character other than a letter, digit, `_` or `-`
    replaced by `-`.
  - It is kept across plugin updates and deleted on uninstall from the last scope. Per cli-reference
    "What an uninstall deletes and keeps" (accessed 2026-09-29), there are three exceptions:
    - `--keep-data` is passed;
    - another installed plugin uses the same folder, for example an id that differs only in letter
      case;
    - Claude Code cannot read the installed-plugins list back after the removal. Then the options,
      secrets and data directory all stay, and the result carries
      `savedKept: "install_records_unreadable"`.
  - It is exported to hook commands, MCP stdio servers and LSP servers. It is absent from the Bash
    tool's environment. Monitor commands receive no variables at all ("Not exported" in the "Where
    each variable resolves" table).
- **Semantics:**
  - Measured (2.1.282, -p): a SessionStart hook received
    `CLAUDE_PLUGIN_DATA=<config-dir>/plugins/data/opt-hf-test`. The directory is under
    `CLAUDE_CONFIG_DIR` when that is set, which gives `~/.claude/...` by default.
  - **One directory per plugin id, not per project** — measured (2.1.282, -p). Sessions started from
    two different project directories received the **same** `CLAUDE_PLUGIN_DATA` while
    `CLAUDE_PROJECT_DIR` differed. Any per-project state under it must be keyed by the hook itself,
    for example from `CLAUDE_PROJECT_DIR`.
  - **Install scopes share it** — *inferred* from the id rule, not measured. The directory is keyed by
    plugin id (`<plugin>@<marketplace>`), so user, project and local installs of one plugin share
    one directory.
  - A `--plugin-dir` session resolved it to `<config-dir>/plugins/data/opt-inline`. Measured (2.1.282,
    -p).
  - `claude plugin uninstall opt@hf-test` (the last scope) deleted the plugin's data directory and
    cleared its `pluginConfigs` entry. Measured (2.1.282, CLI).
  - *Untested because the probe hook runs `mkdir -p` itself:* whether the host creates the directory
    before the first write. "Created on first reference" is doc-stated.
  - *Untested because it needs a logged-in session that runs a tool:* whether the variable is absent
    from the Bash tool's environment.
- **Minimum CLI:** 2.1.78. Changelog 2.1.78: "Added `${CLAUDE_PLUGIN_DATA}` variable for plugin
  persistent state that survives plugin updates".
- **On the pinned CLI (2.1.282):** exported to SessionStart hooks, as above. The same export was seen
  on 2.1.284 and 2.1.81 (-p).
- **Standing:**
  - Measured on 2.1.282: the path, per-plugin scope and `--plugin-dir` id (unauthenticated `-p`
    sessions), and deletion on uninstall (CLI).
  - Inferred: shared across install scopes.
  - Doc-stated:
    - created on first reference;
    - the three keep-data exceptions;
    - absence from the Bash tool;
    - no variables for monitor commands;
    - export to MCP and LSP servers.

## Pinned CLI validation

`claude plugin validate --strict` on 2.1.282, the pin in `scripts/official-validate.sh` and
`.github/workflows/validate.yml`. Measured (2.1.282, CLI):

| input | result |
|---|---|
| marketplace: `forceRemoveDeletedPlugins: true`, `renames` with `null`, and the chain `x→y→a` | `✔ Validation passed`, exit 0 (also 2.1.281, 2.1.283, 2.1.284) |
| marketplace: `renames` cycle `p→q→p` | 2 errors `chain does not resolve (cycle)`, exit 1 |
| marketplace: `renames` target not listed | `chain does not resolve (target-missing)`, exit 1 |
| marketplace: `renames: {"a": "b"}` with `a` still listed | `✔ Validation passed`, exit 0 |
| marketplace: `"bogusKey": 1` (control) | `bogusKey: Unknown field 'bogusKey'. Claude Code ignores it at load time.`, promoted to a failure by `--strict`, exit 1 |
| plugin: `userConfig` with a boolean and a string option, each with `default` and no `required` | `✔ Validation passed`, exit 0 |
| plugin: an unknown key inside an option | `userConfig.level: Invalid input`, exit 1 |

**Verdict: the pin does not need to move.** All four features validate and behave on 2.1.282.

## Older CLI behaviour

- **`renames`, on 2.1.191** (the newest published release below 2.1.193):
  - `validate --strict` fails any manifest carrying the map, valid or not:
    `renames: Unknown field 'renames'. Claude Code ignores it at load time.`, exit 1. Measured
    (2.1.191, CLI).
  - At load time the key is ignored. The marketplace adds and updates, but nothing migrates: an
    installed `a` stays `✘ failed to load` / `Plugin a not found in marketplace hf-test` across
    sessions. Measured (2.1.191, CLI + -p).
  - **With a non-null rename AND the flag** (`{"a": "b"}` + `forceRemoveDeletedPlugins: true`):
    after one session start `a` is **uninstalled** and `b` is **not installed**. The user is left
    with neither; `enabledPlugins` is `{}` and `plugin list` prints `No plugins installed.` Measured
    (2.1.191, CLI + -p).
    - The same manifest on 2.1.282 migrates `a` to `b` normally.
    - **So older-CLI fallback text must say:** on Claude Code older than 2.1.193, install the
      successor yourself (`claude plugin install <successor>@<marketplace>`). "Uninstall the old one"
      alone is not enough. On 2.1.191 the flag removed the old plugin without installing the new one
      (measured). That is not true of every build below 2.1.193: 2.1.81 removed nothing in an
      unauthenticated `-p` session (see `## forceRemoveDeletedPlugins`).
    - **The trade-off in setting the flag** alongside a non-null rename:
      - With the flag, a 2.1.191 user silently loses a merged plugin at session start. Whether
        `/plugin` lists it under Flagged on 2.1.191 was not checked.
      - Without it, the old plugin stays installed and shows a visible, recoverable
        `✘ failed to load` / `Plugin <name> not found in marketplace` until the user acts.
- **`renames`, on 2.1.81** — measured (2.1.81, CLI):
  - There is no `--strict` flag (`error: unknown option '--strict'`).
  - Plain `validate` reports an **error**: `root: Unrecognized keys: "description", "renames"`.
  - Even so, `plugin marketplace add` and `plugin install b@hf-test` from that marketplace succeed:
    the key is ignored at load time, and nothing fails to load.
- **`forceRemoveDeletedPlugins`:**
  - 2.1.191 knows the key. The flag-only case and the flag + `null` case are both uninstalled at
    session start. Measured (2.1.191, CLI + -p).
  - 2.1.81 knows the key, but did not uninstall in an unauthenticated session; see
    `## forceRemoveDeletedPlugins`.
- **`userConfig`, on 2.1.81** (the newest published release below 2.1.83) — measured (2.1.81,
  CLI + -p):
  - A plugin declaring `userConfig` passes plain `validate`, installs, and its hooks run.
  - A value saved in `pluginConfigs` is **not** exported: no `CLAUDE_PLUGIN_OPTION_*`. A resolver
    therefore falls through from env straight to its default.
- **`userConfig` with `options`, on 2.1.191** (below 2.1.271) — measured (2.1.191, CLI):
  - `validate`: `userConfig.tone: Unrecognized key: "options"`, exit 1.
  - `plugin install` **fails**: `has an invalid manifest file … Unrecognized key: "options"`.
  - This is the only case measured here where adopting a feature stops a plugin loading on an older
    CLI.
- **`CLAUDE_PLUGIN_DATA` below 2.1.78:** *untested because* measuring 2.1.77 would take a third npm
  install, over this study's cap. From 2.1.81 up the variable is exported. Below 2.1.78 it is
  *inferred* to be unset, which is the fallback case every hook must already handle.

## Minimum CLI versions

| feature | minimum | source |
|---|---|---|
| `renames` | 2.1.193 | host-marketplace and marketplace-reference pages; changelog 2.1.193. Measured ignored on 2.1.191. |
| `forceRemoveDeletedPlugins` | no doc page states one | Documented (field row; host-marketplace "Uninstall removed plugins…"), but no minimum is stated and there is no changelog entry. Measured working on 2.1.191; the key is known to 2.1.81's schema. |
| `userConfig` | 2.1.83 | Changelog 2.1.83. From the docs: `options` needs 2.1.271, `/config` rows 2.1.269, `install --config` 2.1.147. The `CLAUDE_PLUGIN_OPTION_*` export has no stated minimum and was measured absent on 2.1.81. |
| `${CLAUDE_PLUGIN_DATA}` | 2.1.78 | Changelog 2.1.78. Measured on 2.1.81 and 2.1.282. |

## Kill-trigger verdict

**Kill-trigger: clear.** None of the spec's four clauses fires:

1. **`renames` / `forceRemoveDeletedPlugins` unsupported by any CLI the repo can pin — clear.**
   - Both pass `validate --strict` on the pin, 2.1.282, and on 2.1.281, 2.1.283 and 2.1.284.
   - Both behave as documented on 2.1.282: the rename migrates, and the flag uninstalls at session
     start (CLI + -p).
2. **`userConfig` unsupported by any CLI the repo can pin — clear.**
   - A plugin with defaulted boolean and string options passes `validate --strict` on 2.1.282.
   - It installs and loads there, and a saved value reaches hooks as `CLAUDE_PLUGIN_OPTION_<KEY>`.
3. **`userConfig` forces an install-time prompt that cannot be defaulted — clear.**
   - The prompt exists, but it can always be defaulted. **Esc** always leaves the plugin active.
     **Plain Enter** does too for options without `required`. Unsaved options fall to the hook's own
     default.
   - Measured on 2.1.282 and 2.1.284, in TUI mode.
   - *Untested:* plain Enter past a `required` option. The docs say the dialog refuses an empty
     value there.
4. **Unset options exported in a way that defeats env-first resolution — clear.**
   - An unset option is not exported at all. A saved one is exported as its literal value; `false`
     arrives as the string `false`.
   - Values stay per plugin even when two plugins share a key name.
   - `CC_*` variables reach hooks unchanged.
   - The resolver reads `CLAUDE_PLUGIN_OPTION_<NAME>` as its option layer. A user-set variable of that
     name is overwritten when the option is saved, and passes through as if it were the option when
     not saved. That is a quirk of the option layer. It cannot outrank the env layer (`CC_*`), which
     the resolver reads first.

**Spec criterion 31 ("no install-time prompt") — FAILS on the interactive TUI path; it holds only on
non-TUI paths. It needs the user's sign-off before card 38.**

- **Where it fails.** A fresh `/plugin install` in the TUI opens the `Configure <plugin>` dialog for
  any plugin that declares `userConfig`. That includes a plugin whose options all have defaults and
  none is `required`. Measured (2.1.282, TUI) and (2.1.284, TUI).
- **Where it holds:**
  - `claude plugin install` from a terminal **with a TTY** never prompts. It prints the one-line
    `N userConfig options not yet set …` notice and exits 0 on its own. Measured (2.1.282 and 2.1.284,
    CLI under a pseudo-terminal), both with all options defaulted and with one no-default option. A
    `required` option was not tried.
  - The same install with no TTY behaves the same way (2.1.282, CLI).
  - An update via `claude plugin update` that adds `userConfig` to an installed plugin shows nothing,
    and the next TUI start shows no dialog (2.1.282). Updating from inside the TUI, and auto-update,
    are untested.
  - Headless sessions never prompt (-p).
- **What the user must decide.** The dialog is dismissible and never blocks. Declaring the off-switches
  in `userConfig` means every fresh TUI install of those plugins shows it. On 2.1.284, pressing Enter
  through it also persists boolean defaults. The user must accept that, or narrow the adoption,
  before the declarations ship.
