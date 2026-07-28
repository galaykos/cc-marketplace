# skill-router

File-aware skill auto-routing. The marketplace ships ~50 best-practice skills, but a skill only helps if it fires at the right moment. This plugin surfaces the relevant one automatically, driven by the file you actually touch — not by whether the prompt happened to name it.

## Install

```
claude plugin install skill-router@cc-plugins-marketplace
```

Installed automatically by the `taskmaster-suite` and `everything` bundles.

## Two axes

The plugin routes on two independent signals, and it helps to keep them apart:

- **File → skill** (`rules.tsv`): you edited a `.sql` file, so load the SQL skill. Fires after an edit.
- **Prompt → command** (`prompt-rules.tsv`): you asked for a landing page, so `/craft-layer:craft` fits better than the generic pipeline. Fires on the prompt, before any work starts.

## What it does

Four hooks, all fail-open (any error, or a missing `jq`, exits silently and never blocks an edit or a prompt):

- **`SessionStart` → `prime.sh`** — sniffs the repo's manifests (composer.json, package.json, Dockerfiles, `*.tsx`/`*.sql` presence) and injects a one-line index of the skills relevant to this stack, filtered to the plugins you actually have installed.
- **`PostToolUse` (Edit/Write/MultiEdit) → `route.sh`** — after an edit, matches the file against `rules.tsv`. A high-confidence match (path or extension) injects a directive to load the relevant skill and review the change against it — **once per signal per session**, so a run of `.sql` edits nudges you once, not every time.
- **`SessionEnd` → `summary.sh`** — low-confidence content signals (a file that mentions `password`, uses `async`/locks, is dense with `try/catch`) never interrupt inline; they accumulate and surface once as a quiet end-of-session digest.
- **`UserPromptSubmit` → `route-prompt.sh`** — matches the prompt against `prompt-rules.tsv` and names the best-suited command in one line. "build a landing page" points at `/craft-layer:craft`, "a colour change on this shadcn project" at `/ui-ux:theme`, anything feature-shaped and unclaimed at `/taskmaster:task`.

## Prompt routing, and why priority

The marketplace's reminder hooks each nudge toward their own plugin, and when two match one prompt the winner is — by their own comment — *scheduling order*. Fine for a nudge, useless for "which tool actually fits this". `prompt-rules.tsv` replaces that with an explicit priority column: highest match wins, ties break by row order.

```
# pattern	command	owning_plugin	priority	reason
landing page|marketing (site|page)	/craft-layer:craft	craft-layer	90	visual-craft work — live reference research, a board you approve
(colou?r|theme|palette) (change|swap)	/ui-ux:theme	ui-ux	85	a colour decision — judge candidates on a live preview URL
build|create|add|implement	/taskmaster:task	taskmaster	10	feature-shaped ask — pin down scope before code
```

A rule fires only if its `owning_plugin` is installed, so an uninstalled specialist falls through to the next-best row rather than pointing at a command you do not have. Adding a route is one tab-separated row — `route-prompt.sh` carries no literal command names and `scripts/validate.sh` fails the build if one appears. The gate also rejects a row whose command resolves to no `plugins/*/commands/*.md`, whose `owning_plugin` disagrees with the command's own plugin, whose priority is not an integer, or that is missing a field.

**Standing: gated.** `scripts/smoke/prompt-route-tests.sh` (its own CI step) asserts which command comes back for each shape, that priority beats row order, that every guard silences it, and that all four gate strings above actually fire.

The router claims the same per-prompt marker the reminder hooks use, so at most one advisory line lands on a prompt. **Residual, stated rather than papered over:** the harness decides which `UserPromptSubmit` hook runs first, so a reminder hook can still win that race and speak instead of the router. Priority is authoritative among these rules, not across independently-installed processes. `CC_REMIND=off` silences every advisory nudge including this one; `CC_ROUTE=off` silences only the router.

It never forces a skill to run — hooks cannot — it injects a directive the model then acts on. It complements the existing description-based skill triggering; it does not replace it.

## Adding a file route

Edit `rules.tsv` — one tab-separated row, no code change (prompt routes go in `prompt-rules.tsv`, above):

```
signal_type   pattern                 skill                 owning_plugin   confidence
glob          *.sql                   sql-best-practices    sql             high
content       \b(password|jwt)\b      security-review       security        low
```

- `signal_type`: `glob` (matched against the edited file path) or `content` (a `grep -E` pattern matched against the file's contents).
- `confidence`: `high` fires inline once per session; `low` is deferred to the SessionEnd digest.
- A rule only fires if its `owning_plugin` is installed.

### Stack markers (optional 6th column)

When two stacks claim the same file pattern (vue2 vs vue3 on `*.vue`, php vs laravel on `*.php`), an optional `stack_marker` column discriminates by sniffing a manifest at the repo root:

```
glob   *.vue   vue3-best-practices   vue3   high   package.json~"vue"[[:space:]]*:[[:space:]]*"[~^>=v ]*3[."]
glob   *.php   php-best-practices    php    high   !composer.json~laravel/framework
```

- Format: `<manifest>~<ERE>`, split on the **first** `~` — the manifest name cannot contain `~`, but the regex may. Prefix `!` negates the match verdict. `-` or empty means no marker.
- Fallback chain: `||`-separated alternatives (`a~re||b~re`) are tried in order and the **first decisive alternative wins** — its match verdict is final. Alternatives whose manifest is absent/unreadable (or that are malformed) are skipped; no decisive alternative at all fires. Put the authoritative source first: the vue rows check the installed `node_modules/vue/package.json` version before the declared `package.json` range, so `workspace:*`/`latest`/loose ranges resolve to the actually-installed major once dependencies are installed. A literal `||` inside a regex is unsupported (single `|` alternation is fine).
- Fail-open semantics: the manifest is read from the session cwd, regular files only, capped at 64 KiB. Manifest absent/unreadable → the rule **fires** (undetectable stack keeps today's behavior). `grep -E` exit 0 → satisfied; exit 1 → suppressed; exit ≥ 2 (malformed regex) → fires. `!` inverts only the 0/1 verdict.
- Complementary same-pattern pairs that should co-fire (e.g. a11y alongside react on `*.tsx`) are declared with a pairwise comment directive so the marketplace's overlap gate allows them: `# co-fire-ok: <pattern> <skillA> <skillB>`.

## State

A per-session dedup file lives at `<repo>/.claude/skill-router/fired-<session_id>.json` (gitignored) and is removed at session end.
