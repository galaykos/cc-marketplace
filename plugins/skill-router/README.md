# skill-router

File-aware skill auto-routing. The marketplace ships ~50 best-practice skills, but a skill only helps if it fires at the right moment. This plugin surfaces the relevant one automatically, driven by the file you actually touch — not by whether the prompt happened to name it.

## Install

```
claude plugin install skill-router@cc-plugins-marketplace
```

Installed automatically by the `taskmaster-suite` and `everything` bundles.

## Two axes

The plugin routes on two independent signals, and it helps to keep them apart:

- **File → skill** (`rules.tsv`, pattern-matched in the hook): you edited a `.sql` file, so load the SQL skill. Fires after an edit. Deterministic, because "this path is SQL" is a fact.
- **Prompt → command** (catalog + model judgment): you asked for a landing page, so `/craft-layer:craft` may fit better than the pipeline you named. Fires before any work starts. Judged, not matched, because "which tool fits this ask" is not a fact about the string.

## What it does

Four hooks, all fail-open (any error, or a missing `jq`, exits silently and never blocks an edit or a prompt):

- **`SessionStart` → `prime.sh`** — sniffs the repo's manifests (composer.json, package.json, Dockerfiles, `*.tsx`/`*.sql` presence) and injects a one-line index of the skills relevant to this stack, filtered to the plugins you actually have installed.
- **`PostToolUse` (Edit/Write/MultiEdit) → `route.sh`** — after an edit, matches the file against `rules.tsv`. A high-confidence match (path or extension) injects a directive to load the relevant skill and review the change against it — **once per signal per session**, so a run of `.sql` edits nudges you once, not every time.
- **`SessionEnd` → `summary.sh`** — appends the session's surfaced/pending signals to the machine-local ledger and removes the state file; low-confidence signals themselves surface earlier, on the next prompt (below).
- **`UserPromptSubmit` → `route-prompt.sh`** — first flushes any accumulated low-confidence content signals (a file that mentions `password`, uses `async`/locks, is dense with `try/catch`) as one digest on your next prompt — a channel the model receives in time to act, unlike SessionEnd — then, on the first work-shaped prompt of a session, injects the catalog of commands actually installed here plus the rules for judging which one fits the ask. The hook does not pick; the model does. Exception in the catalog's rule 3: a scope-first reminder on the same prompt outranks tool-fit.

## The tool-fit check

You ask for a marketing landing page and the only plugin that speaks up nudges you into a requirements pipeline. The fix is not a bigger keyword table — a table routes only the phrasings its author imagined, and every new plugin needs a new row. So the hook hands over the **catalog** and the **discipline**, and the judgment stays with the model, which reads meaning:

```
[skill-router] Tool-fit check (once this session). Commands installed here, and what each is for:

- /a11y:audit — Audit UI code against WCAG 2.2 AA
- /craft-layer:craft — Create a crafted web app (CRM, SaaS, landing page) end to end…
- /ui-ux:theme — Create or restyle a CSS-variable UI theme…
  … one line per installed command …
```

The catalog is built at runtime from each installed plugin's `commands/*.md` frontmatter — the descriptions already there, already length-linted. Nothing is generated, so nothing can drift, and a command you have not installed can never be suggested.

### What the model is told to do with it

1. Judge by the **ask's substance**, not its wording. Most requests fit no command; silence is the default.
2. **You named a tool and something else clearly fits better** → an `AskUserQuestion` with exactly two options, never a silent switch:

```
You: run taskmaster: create a marketing landing page

⚠ taskmaster grills requirements; this ask is a visual deliverable.
  [ Proceed with /craft-layer:craft (Recommended) ]  [ Proceed with taskmaster as asked ]
```

3. No tool named and one clearly fits → one line, no picker.
4. Close call, or your choice was already right → nothing at all. Over-suggesting is the failure mode a catalog invites, and rule 4 is what holds it back.
5. One picker per named tool per session. Declining is durable.
6. Under a hands-off boost (`ultra-goal`, or a `Goal:` marker), the Recommended route is auto-taken and written to the goal ledger with its rationale and both options — auditable after the fact, like every other goal auto-take.

### What has teeth here

**Agent-graded — the routing verdict.** Which command the model picks is a judgment with real variance. No script asserts it, and this README will not pretend otherwise.

**Gated — the mechanism.** `scripts/smoke/prompt-route-tests.sh` (its own CI step) asserts the catalog is built, that every entry resolves to a real command file, that it contains only installed plugins, that the directive still carries all six discipline rules, that each guard silences the hook, and that it injects once per session. `scripts/validate.sh` fails the build on a hardcoded slash-command token in the hook, or on a fifth prompt-matching pattern — the signature of a routing table regrowing in shell.

**The cost, plainly:** ~2.6k dynamic tokens measured for this plugin's hooks on the first work-shaped prompt + first edit of a session (the catalog is most of it), paid whether or not a better tool exists. A chat-only session pays nothing. `CC_ROUTE=off` disables this check; `CC_REMIND=off` disables every advisory nudge in the marketplace, this one included.

It never forces a skill to run — hooks cannot — it injects a directive the model then acts on. It complements the existing description-based skill triggering; it does not replace it.

## Adding a file route

Edit `rules.tsv` — one tab-separated row, no code change (prompt routes go in `prompt-rules.tsv`, above):

```
signal_type   pattern                 skill                 owning_plugin   confidence
glob          *.sql                   sql-best-practices    sql             high
content       \b(password|jwt)\b      security-review       security        low
```

- `signal_type`: `glob` (matched against the edited file path) or `content` (a `grep -E` pattern matched against the file's contents).
- `confidence`: `high` fires inline once per session; `low` accumulates and flushes as one digest on the next prompt (SessionEnd keeps the ledger).
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
