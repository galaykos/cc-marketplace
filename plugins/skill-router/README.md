# skill-router

File-aware skill auto-routing. The marketplace ships ~50 best-practice skills, but a skill only helps if it fires at the right moment. This plugin surfaces the relevant one automatically, driven by the file you actually touch — not by whether the prompt happened to name it.

## Install

```
claude plugin install skill-router@cc-plugins-marketplace
```

Installed automatically by the `taskmaster-suite` and `everything` bundles.

## What it does

Three hooks, all fail-open (any error, or a missing `jq`, exits silently and never blocks an edit):

- **`SessionStart` → `prime.sh`** — sniffs the repo's manifests (composer.json, package.json, Dockerfiles, `*.tsx`/`*.sql` presence) and injects a one-line index of the skills relevant to this stack, filtered to the plugins you actually have installed.
- **`PostToolUse` (Edit/Write/MultiEdit) → `route.sh`** — after an edit, matches the file against `rules.tsv`. A high-confidence match (path or extension) injects a directive to load the relevant skill and review the change against it — **once per signal per session**, so a run of `.sql` edits nudges you once, not every time.
- **`SessionEnd` → `summary.sh`** — low-confidence content signals (a file that mentions `password`, uses `async`/locks, is dense with `try/catch`) never interrupt inline; they accumulate and surface once as a quiet end-of-session digest.

It never forces a skill to run — hooks cannot — it injects a directive the model then acts on. It complements the existing description-based skill triggering; it does not replace it.

## Adding a route

Edit `rules.tsv` — one tab-separated row, no code change:

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
- Fail-open semantics: the manifest is read from the session cwd, regular files only, capped at 64 KiB. Manifest absent/unreadable → the rule **fires** (undetectable stack keeps today's behavior). `grep -E` exit 0 → satisfied; exit 1 → suppressed; exit ≥ 2 (malformed regex) → fires. `!` inverts only the 0/1 verdict.
- Complementary same-pattern pairs that should co-fire (e.g. a11y alongside react on `*.tsx`) are declared with a pairwise comment directive so the marketplace's overlap gate allows them: `# co-fire-ok: <pattern> <skillA> <skillB>`.

## State

A per-session dedup file lives at `<repo>/.claude/skill-router/fired-<session_id>.json` (gitignored) and is removed at session end.
