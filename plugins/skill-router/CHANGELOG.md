# Changelog

All notable changes to the skill-router plugin.

## 0.13.5

### Changed
- Catalog text follows two merges: `opinion-round` is now <!-- removed-ok -->
  approach-deliberation's blind-panel mechanism and `task-orchestration` is <!-- removed-ok -->
  plan-before-code's "Split into tasks". No routing rows changed — neither skill
  had one.

## 0.13.4

### Changed
- `**/migrations/**` now routes to `sql-best-practices` alone. The <!-- removed-ok -->
  `database-design` row and its three co-fire blessings are gone with the skill: <!-- removed-ok -->
  a migration file in a MySQL project used to load `sql` + `database-design` + <!-- removed-ok -->
  `mysql` at once, 4,333 tokens of bodies, with "index every foreign key" stated
  in six places across the family.

## 0.13.3

### Fixed
- **Directory globs matched case-sensitively, which silently disabled a whole
  plugin.** `match_glob` tested `**/dir/**` with a case-SENSITIVE substring
  comparison, and `**/resources/js/Pages/**` is inertia's ONLY routing row. On a
  project scaffolded by Laravel's current starter kits — which generate
  `resources/js/pages/` — the router matched nothing, the 2,134-token skill never
  loaded, and `/inertia:review` had to be typed by hand. `**/Livewire/**` had the
  same exposure, masked only by livewire's second row. Directory segments now
  match case-insensitively; the `nocasematch` shell option is saved and restored
  rather than left on. Residual, stated in the code: case is checkable, a wrong
  directory NAME is not.
- **The surfaced ledger could not tell "shown to the model" from "accumulated".**
  `summary.sh` wrote `pending_low` after dropping the `flushed` flag that
  `route-prompt.sh` sets when it actually prints the digest, so
  `scripts/retirement-queue.sh` counted both states as surfacing — for exactly
  the skills a retirement queue ranks first. The ledger line now carries
  `pending_low_flushed` and `pending_low_unflushed`; `pending_low` stays as the
  union so an older reader keeps working.

## 0.13.2

### Fixed
- **The `fired` ledger never persisted, so every edit re-injected directives the model
  already had.** 0.13.1 keyed the marker on `transcript_path` falling back to
  `session_id`, then interpolated the value raw into `fired-$session_id.json`. An
  absolute transcript path makes that a nested filename whose parents are never created,
  so the write failed on every call and `fired` was empty every time — the property that
  the same skill is not re-nudged on a later edit did not hold. Cost was paid in the
  dynamic context channel, repeatedly, per edit. The key is now hashed with `cksum`, the
  idiom `code-review/hooks/conventions.sh` and `lean/hooks/budget.sh` already used.
- **`route-marker-tests.sh` could not have caught it**: its helper used a fresh session
  id per call and wiped `.claude` between calls, so the dedup ledger was never exercised
  at all. It now has a case that holds one context across two edits, sends a path-shaped
  `transcript_path`, and asserts both the suppression and that the ledger file lands.

## 0.13.1

### Fixed
- **One-shot markers now key on `transcript_path`, falling back to `session_id`.**
  PostToolUse is the only hook channel that reaches subagents at all, and a subagent
  shares its parent's `session_id` while getting its own transcript — so a
  session-keyed marker the parent already claimed deduped the worker's nudge away.
  The advisory was structurally silent in the one context where most fan-out code is
  written. `scripts/lib/plugin-checks.sh`'s new `pc_context_key` gates it.

## 0.13.0

### Added

- **`lane.tsv`** — declares `route-prompt` as the owner of `tool-fit-catalog` at
  phase `any`, yielding to `taskmaster:remind`. The yield is not a new decision:
  the charter this hook injects already tells the model "clarification outranks
  tool-fit", so the row records a deference the plugin was shipping in prose and
  nothing could check. `prime.sh` (SessionStart), `route.sh` (PostToolUse) and
  `summary.sh` (SessionEnd) are outside the gated channel and carry no row.

### Changed

- **The work-shaped gate now reaches symptom phrasing.** `hooks/route-prompt.sh`
  asked "is there a making verb here?", so `fix the checkout crash` was work and
  `why is the checkout page broken` was not. Nine realistic incident prompts were
  run against it: seven were dropped — `production is down`, `users are seeing
  500s on login`, `this query got really slow after the last release`, `something
  regressed in the cart total`, `investigate the memory leak`, `the payment
  webhook keeps failing intermittently`, and the one above. An incident is
  normally reported by its effect, not by a verb, so the one moment where picking
  the right tool matters most was the moment the catalog never reached.

  The symptom alternation is appended to the existing verb alternation inside the
  **same** grep, not given a line of its own: `scripts/validate.sh` allows this
  hook four prompt-matching greps and calls a fifth a routing table regrowing in
  shell. That budget is unchanged.

  **The symptom tier is split in two, and the weak half is bound.** Written flat,
  it made `scroll down and tell me what you see` and `the meeting ran slow today`
  work-shaped, because `down` and `slow` are ordinary English long before they are
  incident vocabulary. So: `error`, `crash`, `500s`, `regress(ed|ion)`, `why is`,
  `investigate` and `not working` match bare — a prompt carrying one is about a
  defect whatever the grammar around it. `down`, `slow`, `broken`, `failing`,
  `fails`, `leak` and `stuck` match only after a state verb (`is`, `are`, `went`,
  `keeps`, `got`, `am`, …) with at most one word between. A system in a bad state
  says so with a state verb; a sentence that merely contains the word does not.
  Same shape as `taskmaster/hooks/preview-guard.sh`'s bounded weak `.html` tier.

  *Limitation:* the bound is grammatical, not semantic. `payment failures spiking`
  is missed, and `the build is slow to watch` still fires. Recall on the weak tier
  is traded for the silence of the plain-prompt path; the strong tier is unbounded
  and is what carries recall.

  **Cost, stated plainly:** the catalog is ~2.6k tokens and it now fires in
  symptom-phrased sessions that previously paid nothing. It is still bounded by
  the existing once-per-session `mkdir`, so the increase is one injection per
  session, not per prompt. `scripts/context-budget.sh` cannot see this — it
  measures one fixed making-verb prompt in an empty sandbox, and that prompt
  already fired before this change. Every false positive is therefore a real,
  structurally unmeasurable cost, which is the whole reason the weak tier is
  bound rather than shipped flat.

## 0.12.1

### Fixed

- `README.md` § Adding a file route told you to put prompt routes in
  `prompt-rules.tsv`. **That file has never existed in this plugin.**
  Prompt-shaped routing was removed deliberately —
  `hooks/route-prompt.sh`'s header records the reason ("a table only ever routes
  the phrasings its author thought of, and every new plugin needed a new row")
  and the command catalog plus model judgment replaced it. The section now says
  so explicitly, including that adding such a table is a decided-against design,
  so the next person to look does not go build the file the docs promised.

## 0.12.0

### Added

- **Engine-specific database routing.** `mysql-best-practices`,
  `mariadb-best-practices` and `postgresql-best-practices` shipped with no
  file-routing channel at all — they were named in this file's own limitation
  block as unrouted. Six rows now route them on `*.sql` and `**/migrations/**`,
  discriminated by a compose-image-first marker chain (compose → `.env.example`
  `DB_CONNECTION` → composer.json → package.json).

  The last two links are deliberate and invert the router's usual
  fire-if-uncertain bias, for these rows only: the three engine skills are
  mutually exclusive and their advice conflicts, so a repo with a composer.json
  and no database hint gets none of them rather than all three. A bare directory
  of `.sql` files with no manifests still fires all three — no signal, fail-open,
  and the one place the conflicting-advice cost is accepted. Three known misses
  are listed in `rules.tsv` rather than left to be discovered.

- **Plain-source rows for Go, Ruby and Rust** — `*.go`, `*.rb`, `*.rs` route to
  `low-cognitive-load` + `solid-principles`, matching what `*.ts` / `*.js` /
  `*.py` already did. The limitation block recorded this gap; it is now closed
  and the text says so.

- Twelve `# co-fire-ok:` declarations for the new pairs. Generic + engine on one
  file is intended (portable SQL vs what only that engine does); the engine rows
  discriminate against each other by distinct markers and need no blessing.

### Notes

- Correction to 0.11.0's note: `*.php` was NOT missing. Lines 78-79 have carried
  Laravel and plain-PHP rows behind `composer.json` markers all along.
- Still unrouted, deliberately: `code-smells`, `reuse-hygiene`, `yagni-check`,
  `plan-before-code`. `comment-discipline` stays absent by design — its own
  PreToolUse/PostToolUse hook is its delivery channel.
- No context-budget change: the dynamic channel measures a synthetic edit to
  `src/example.ts`, which no new row matches.

## 0.11.0

### Fixed

- **The router was inert on every real install.** `prime.sh`, `route.sh` and
  `route-prompt.sh` each resolved the installed-plugins root as
  `dirname "$CLAUDE_PLUGIN_ROOT"`. That is correct only under a flat
  `<plugins>/<plugin>` layout; a real install is versioned
  (`<marketplace>/<plugin>/<version>`), so the result was
  `<marketplace>/<plugin>` — a directory whose only children are version
  numbers. Consequences, all silent:
  - every `owning_plugin` was reported not-installed, so **every glob rule was
    suppressed** and no edit ever produced a nudge;
  - `route-prompt.sh`'s catalog glob (`<root>/*/commands/*.md`) was one path
    segment short, matched nothing, and the hook exited before printing —
    **no command catalog was ever injected**;
  - `prime.sh`'s session index was filtered down to nothing.

  Resolution now lives in one place, `hooks/plugins-dir.sh`, and handles both
  layouts. Skill and command paths resolve through the version segment, and a
  cache holding several releases of one plugin contributes exactly one catalog
  entry (the highest version it can order).

### Added

- `hooks/plugins-dir.sh` — layout detection plus `pr_plugin_installed`,
  `pr_plugin_root` and `pr_plugin_roots`, sourced by all three hooks. Absent or
  unsourceable, every caller falls back to fire-if-uncertain; the router's
  declared bias is toward surfacing, never toward silence.
- `scripts/smoke/versioned-layout-tests.sh`, wired as its own CI step. It runs
  the firing, suppression, catalog-uniqueness and skill-path assertions against
  **both** layouts. This is the gate that was missing: the three existing router
  harnesses build a flat scratch layout by construction, so 73 green assertions
  could not see a bug that only exists under the layout users actually have.

### Notes

- The `~2.6k` dynamic-token figure in the README and in
  `context-budget-dynamic-baseline.json` is measured against a flat checkout. It
  is the cost a *working* router pays; before 0.11.0 a real install paid nothing,
  because nothing was emitted.
- Not addressed here: `rules.tsv` coverage. There is still no plain `*.php` row
  (only `*.blade.php`), and 44 glob + 11 content rows cover 127 shipped skills.
  A working router with sparse rules is a different problem from a dead one.
