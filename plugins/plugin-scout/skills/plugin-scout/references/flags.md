# Flags: --yes, --full, --stack, --persist, --global, --all

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
  auto-installed by `--yes`, under any flag combination that lacks `--full`.
  `--full` (below) is the one mass installer, and it confirms first unless paired
  with `--yes`. `--yes --all` is not a mass installer: `--all` changes
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

## `--full`

The stack-aware mass installer. Installs every catalog leaf that is any-stack, or
whose class the manifests (or `--stack`) satisfy, per
`references/stack-relevance.md` — which owns the class table, the domain-bound
rule and the typed-token rule; this section does not restate them.

- What it includes, by name so no later reader has to infer it: every
  **any-stack** leaf whether or not its signal fired — the six stack-bound leaves
  (`laravel`, `web-dev`, `craft-layer`, `design-lab`, `payments`, `llm-app`)
  follow `references/stack-relevance.md` and are the only tier-1 or tier-3 rows
  `--full` can skip. Any-stack covers the whole of tier 2 and, from tier 3, the
  process/pipeline group (taskmaster, task-runner, orchestration, approaches,
  system-design), the session-wide group (terse, plus candor, lean, hindsight and
  skill-router — the four `references/any-core.md` routes to `--global` for `--yes`;
  `--full` is the flag that bullet does not bind) and the research/tooling group
  (brain, fresh-take, ultra-deep-research, and vercel-skills-scout
  when its signal has not fired — they are tier 1 when it has).
  Leaves only, never a suite.
- What it excludes: stack-mismatched leaves (a class whose manifest evidence is
  absent and whose `--stack` token was not typed); `payments` and `llm-app` when
  their domain signal is absent and no token in their class was typed; the
  bundles and `plugin-scout` by construction; already-installed leaves.
- What prints, in this order: the report header line (eligible count, installed
  count, detected stack with evidence); any fired `references/signals.md` `—`
  routing line; the **plan block** below; then the `Beyond this marketplace` block
  (`references/official-complements.md` — printed, never run, exactly as without
  the flag). The three-tier inventory, the relevance pass and the picker do NOT
  run: there is nothing to lift or pick when everything eligible installs.
- The plan block, one labelled line each, nothing omitted:
  - `Install (N):` the leaves that will install, sorted.
  - `Already installed (K):` skipped leaves — the installed set is the SKILL's
    Preflight set (project-filtered `claude plugin list` ∪ the three settings files)
    ∪ the `dependencies` of every installed suite, so a `--full` run never re-issues
    installs for a bundle's members (`references/picker.md` "installed in effect").
  - `Excluded:` one line per excluded leaf — the class's evidence negated plus the
    token that would include it, e.g. `laravel — PHP / Laravel evidence absent (no
    laravel/framework, no @inertiajs/*); --stack laravel includes`, or
    `payments — Payments domain signal absent (no STRIPE_ key, no stripe dep);
    --stack stripe includes`.
  - One count line for the bundles and `plugin-scout` (by construction).
  - `Restored by --stack:` one line per class a typed token restored (see `--stack`).
  - `Overlap pairs installed together:` the pairs `references/picker.md` names
    (ui-ux / craft-layer / design-lab, taskmaster / task-runner / orchestration,
    web-dev / laravel) that are in the set. Named, not resolved — the picker was
    the only place overlap was surfaced and it does not run here.
  - `Hooks added:` hook-bearing plugins grouped by event — every event key present
    in the file (Stop, UserPromptSubmit, PreToolUse, PostToolUse, SessionStart,
    SessionEnd, …), never a fixed list — read from each plugin's
    `hooks/hooks.json` at run time (23 of the 36 leaves ship one at the time of
    writing; recount, never quote). `secret-scanning` and `command-guard` are
    always named, as under `--yes`: the user did not see a picker for them.
  - `MCP servers added:` each server from a plugin's `.mcp.json`, marked local or
    remote with its URL — `design-lab` ships a hosted `https://mcp.reui.io` endpoint
    that needs a browser sign-in, and a remote server is a trust decision the plan
    must show before the confirm.
  - The listing-cap paragraph, last, because it is the one line most likely to
    change the answer: Claude Code budgets the skill listing it sends the model at
    `contextWindowTokens × bytesPerToken × skillListingBudgetFraction` (default
    fraction 0.01) — **6,000 chars** on the default 200k window, **30,000** on the
    1M tier, on a current-tokenizer model (3 bytes/token). The unit is NOT the
    plugin description: the host charges one entry per skill and per command —
    `name + 4 + min(len(description), 1536)` from each `skills/*/SKILL.md` and
    `commands/*.md` frontmatter, plus one separator per entry beyond the first
    (`pc_listing_entry_cost` in `scripts/lib/plugin-checks.sh` is the one
    implementation; `bash scripts/context-budget.sh` is the entry point that
    recomputes it).
    Read those frontmatters from the registered marketplace clone
    (`claude plugin marketplace list` prints its path) for every plugin in the set,
    sum, and print the figure against both caps. If the clone is unreadable, sum the
    catalog descriptions instead and SAY it is a proxy that undercounts the metered
    channel by roughly 40%. Over the cap the host reduces entries to
    name-only in priority order, silently, so skills stop being reachable with no
    error. Print the lever with the smallest fraction, in 0.01 steps, that fits at
    200k — e.g. `{ "skillListingBudgetFraction": 0.06 }` in settings.json — the fraction
    is a ceiling, not a purchase; it only admits description text that was being
    evicted. Never write it, never trim the set: the scout cannot make an over-cap
    install reachable, it can only say so before the install. The flagship
    Laravel + Inertia + React set costs roughly 35,000 chars — over at both tiers.
- The ask: ONE AskUserQuestion for the plan — after Preflight's own marketplace-add
  ask, if that fired — with exactly three options: "Install N plugins at scope S
  (Recommended)" / "Print the commands instead" / "Stop". `--full --yes` skips the
  plan ask; everything above still prints first.
- Then Install per the SKILL — the same `claude plugin install <name>@cc-plugins-marketplace --scope <scope>`
  per leaf, the same exit-0 success rule, the same summary and `/reload-plugins`
  line, the same `--persist` verify step.
- Headless without `--yes`: print the plan, then the install commands, and stop.
  Headless with `--yes`: install for real, with the marketplace-add rules of
  `--yes` above (absent marketplace → stop before Detection).
- No `claude` CLI: installed state is unknown, so `Already installed` cannot be
  computed — print the full command list, no ask.
- Combinability: `--full --all` — `--all` has no effect (there is no picker to
  page); say so rather than silently ignoring it, as with `--yes --all`.
  `--full --persist` / `--full --global` — scope only; the machine-wide notice
  prints as always, and `--persist` writes exactly the set that installed this
  run. `--full --yes` — no confirm, otherwise identical.

## `--stack`

A typed stack, for the manifest that is not there yet. Vocabulary: the token column
of `references/stack-relevance.md`, nothing else.

- Form: `--stack a,b,c` or `--stack=a,b,c` — one token after the flag,
  comma-separated, **no spaces**; consumed before the remainder of `$ARGUMENTS`
  becomes the path. `--stack laravel, react` is the trap: `laravel,` yields an <!-- removed-ok -->
  empty token, which aborts like an unknown one, and a positional argument that is
  itself a vocabulary token aborts with the hint `did you mean --stack laravel,react`
  — never let it become the scan root. Tokens are lower-cased; duplicates are
  ignored.
- A bare `--stack` with no value, or any token outside the vocabulary, aborts
  **before Preflight** — before the marketplace-add prompt can fire — printing the
  accepted list. `django`, `rails`, `go` are not tokens: an uncovered stack needs
  none, because absent manifests already exclude both stack classes.
- Effect: a token restores its class ONLY when that class's manifest evidence is
  absent, and the plan prints one line per restored class under
  `Restored by --stack:`. When the manifest already satisfies the class the token
  changes nothing. Manifest wins; there is no contradiction notice, because
  `react` and `vue` are one class and no conflict is detectable at that level. <!-- removed-ok -->
- Never changes a leaf's tier in the default flow: `--yes --stack laravel`
  installs exactly what `--yes` installs. `--stack` without `--full` is accepted,
  prints one line — `--stack laravel: accepted, no effect without --full` — and
  changes nothing else; the `Restored by --stack:` line exists only in the
  `--full` plan.

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
unrelated keys, that the machine-wide notice printed, that `--full` applied the
exclusion table, computed the listing figure, disclosed every hook and MCP
server, or asked before installing. `pc_scout_names` gates the names in
`references/stack-relevance.md`'s table and nothing else about it. Those are model
behaviours a reviewer judges, and the absolute-sounding wording above ("never",
"always") states a contract, not a guarantee.

Two residuals worth naming. Headless `--full --yes --persist` is the one path that
writes ~30 `enabledPlugins` entries into a committed `.claude/settings.json` with
no human in the loop — the commit notice prints only after the write. And the
`--persist` settings step writes to a **committed** file, and only the model
honours its abort. If the model merges anyway after a parse error, or authors an
`enabledPlugins` entry for a failed install, nothing here catches it — only a
human reading the diff does.
