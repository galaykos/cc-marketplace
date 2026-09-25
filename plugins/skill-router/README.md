# skill-router

File-aware skill auto-routing. The marketplace ships the marketplace's best-practice skills, but a skill only helps if it fires at the right moment. This plugin surfaces the relevant one automatically, driven by the file you actually touch — not by whether the prompt happened to name it.

## Install

```
claude plugin install skill-router@cc-plugins-marketplace
```

Installed automatically by three of the four bundles (`core-suite`, `workflow-suite`, `frontend-suite`; `craft-suite` does not carry it).

## Two axes

The plugin routes on two independent signals, and it helps to keep them apart:

- **File → skill** (`rules.tsv`, pattern-matched in the hook): you edited a `.sql` file, so load the SQL skill. Fires after an edit. Deterministic, because "this path is SQL" is a fact.
- **Prompt → command** (the host's own command listing + model judgment): you asked for a landing page, so `/craft-layer:craft` may fit better than the pipeline you named. Fires before any work starts. Judged, not matched, because "which tool fits this ask" is not a fact about the string.

## What it does

Six hooks, all fail-open (any error, or a missing `jq`, exits silently and never blocks an edit, a prompt or a spawn):

- **`SessionStart` → `prime.sh`** — sniffs the repo's manifests (composer.json, package.json, Dockerfiles and compose files, a `.github/workflows/` directory, `*.tsx`/`*.sql` presence) and injects a one-line index of the skills relevant to this stack, filtered to the plugins you actually have installed. Manifests are read at the project root (see State), not the payload cwd (0.20.0): SessionStart fires again on resume and compact, and a session compacted while `cd`-ed into a subdirectory used to be re-primed from that subdirectory. The signal→skill rows mirror `code-architecture/skills/coding-entry/references/skill-map.md`; `pc_prime_coverage` compares the two NAME lists in both directions, and nothing checks that a row's predicate matches the signal the map describes — that is `scripts/smoke/prime-map-tests.sh`'s job and only for the cases it fixtures.
- **`PostToolUse` (Edit/Write/MultiEdit, JetBrains `create_new_file`, Bash) → `route.sh`** — after an edit, matches the file against `rules.tsv`. A high-confidence match (path or extension) injects a directive to load the relevant skill and review the change against it — **once per signal per session**, so a run of `.sql` edits nudges you once, not every time.
  - **Files written through Bash route too** (0.20.0). After a Bash call, each file the command wrote with `>`/`>>` (including `cat > f <<'EOF'`), `[sudo] tee`, or `sed -i`/`perl -i` is routed exactly as if it had been Edited — same one-shot, one envelope per call. Only the first 8 targets a command names are examined, and only one that exists afterwards as a regular file under the project root routes. Why: in one measured session 233 of 238 main-thread writes were Bash heredocs, and this hook routed one edit in three weeks (`rationale/2026-09-25-session-plugin-usage-review.md`, finding 1).
  - **Not caught:** interpreter writes (Python `open(…,'w')`, PHP `file_put_contents`, `node -e`), `cp`/`mv`/`install` destinations, a `{ …; } > f` group, and a path held in a shell variable (`> "$f"` is skipped, never guessed). Those files route only if they are later edited with a write tool. A relative target after a `cd` inside the same command (`cd app && cat > f`) resolves against the cwd the host reports, and whether that is sampled before or after the command is unverified. Such a target usually just stays silent.
  - Cost: the hook now runs after every Bash call. A call that writes nothing exits after reading the command, before `rules.tsv` or any state is touched. `scripts/context-budget.sh` sends Edit payloads only, so Bash-triggered output is not metered there; per file it is the same text an Edit of that file gets.
- **`SessionStart` (matcher `compact`) → `compact-capsule.sh`** — after a compaction, re-states the task state on disk the summary may have dropped: the arc phase sentinel, a registered task-runner run and scope lock, open taskmaster ledgers — one line each with the file path. Silent on startup/resume/clear/fork and when no ledger exists, so the always-on budget reads 0. PreCompact is not used: its stdout never reaches the model (the hook header says why). approaches re-asserts its own deliberation marker separately; this one does not repeat it.
- **`SubagentStart` (plugin-scoped agents, matcher `^[a-z0-9-]+:`) → `subagent-skills.sh`** (0.20.0) — hands a spawned plugin agent the absolute `SKILL.md` Read paths of the skills its own `bestpractices-skill:` frontmatter declares, **kept to the ones this repo's stack uses**. The filter is `prime.sh`'s evidence rows (the hook sources that file, so the two cannot disagree), read at the project root. Example: `web-dev:frontend-reviewer` declares React Native, Inertia, Vite and Next.js; in a Laravel/Inertia repo with Vite it gets the Inertia and Vite paths and nothing else. One `additionalContext` of about 600 characters at most (hard cap 700; a path past it is dropped whole): an instruction line — "Read these before working; a path the dispatcher already gave you needs no second Read" — and one path per line. The skill body is not injected.
  - Why: `bestpractices-skill:` is this marketplace's own key and Claude Code ignores it. Only task-runner's dispatcher turned it into Read paths, so an agent spawned any other way had no rubric. In one measured session, three ad-hoc `ui-ux:ui-ux-reviewer` spawns read zero SKILL.md files between them (`rationale/2026-09-25-session-plugin-usage-review.md`, finding 6). The host's `skills:` preload was rejected for these lists because it is stack-blind: about 4.4k tokens of React Native and Next.js per spawn in a Laravel repo.
  - Silent when the agent is built-in or a project agent, its plugin is not in this marketplace's install root or is disabled, it declares no `bestpractices-skill:`, or nothing declared matches the stack. A skill the agent already preloads through `skills:` is not repeated.
  - **Not handed out:** a declared skill `prime.sh` has no evidence row for (`motion-best-practices`, `security-review`, `performance-tuning`, `observability-design`). No manifest can say it applies, so those agents load it from their own instructions, as before. The filter also inherits `prime.sh`'s misses: `a11y-audit` needs a `.tsx`/`.jsx` within three levels of the root, so `a11y-engineer` in a Vue- or Blade-only repo gets nothing; `devops-practices` needs `.github/workflows/`.
  - Cost: measured 200-265 ms per plugin-agent spawn on two real Laravel/Inertia repos. **`scripts/context-budget.sh` does not meter SubagentStart output** (it executes SessionStart, UserPromptSubmit and Pre/PostToolUse hooks only), so this channel is absent from every budget table.
- **`SessionEnd` → `summary.sh`** — appends the session's surfaced/pending signals to the machine-local ledger and removes the state file; low-confidence signals themselves surface earlier, on the next prompt (below).
- **`UserPromptSubmit` → `route-prompt.sh`** — first flushes any accumulated low-confidence content signals (a file that mentions `password`, uses `async`/locks, is dense with `try/catch`) as one digest on your next prompt — a channel the model receives in time to act, unlike SessionEnd — then, on the first work-shaped prompt of a session, injects the rules for judging which installed command fits the ask, pointed at the command listing the host already put in the session. The hook does not pick; the model does. Exception in rule 3: a scope-first reminder on the same prompt outranks tool-fit.

## The tool-fit check

You ask for a marketing landing page and the only plugin that speaks up nudges you into a requirements pipeline. The fix is not a bigger keyword table — a table routes only the phrasings its author imagined, and every new plugin needs a new row. So the hook hands over the **discipline** and points at the list the host already sent, and the judgment stays with the model, which reads meaning:

```
[skill-router] Tool-fit check (once this session). Judge against the slash commands
already listed in this session — do not rebuild or ask for that list.
  … the six numbered rules below …
```

Until 0.18.0 the hook also rebuilt that list: one truncated frontmatter line per installed command, 5,122 of the 6,892 characters it emitted, growing by a row with every command you install. The host already lists every installed command with its **full** description; a second truncated copy bought nothing and was the largest line item in this plugin's dynamic budget. What the model does not have from the host listing is the discipline below — so that is all this hook sends now.

**What that trade gave up, plainly:** the rebuilt catalog was filtered by repo evidence, so a Laravel repo was never shown the Next.js review. The host listing has no such filter. Rule 1 below — "most requests fit none of them" — is now the only thing holding that down, and it is the model's judgment, not a gate.

### What the model is told to do with it

1. Judge by the **ask's substance**, not its wording. Most requests fit no command; silence is the default.
2. **You named a tool and something else clearly fits better** → an `AskUserQuestion` with exactly two options, never a silent switch:

```
You: run taskmaster: create a marketing landing page

⚠ taskmaster grills requirements; this ask is a visual deliverable.
  [ Proceed with /craft-layer:craft (Recommended) ]  [ Proceed with taskmaster as asked ]
```

3. No tool named and one clearly fits → one line, no picker.
4. Close call, or your choice was already right → nothing at all. Over-suggesting is the failure mode a command list invites, and rule 4 is what holds it back.
5. One picker per named tool per session. Declining is durable.
6. Under a hands-off boost (`ultra-goal`, or a `Goal:` marker), the Recommended route is auto-taken and written to the goal ledger with its rationale and both options — auditable after the fact, like every other goal auto-take.

### What has teeth here

**Agent-graded — the routing verdict.** Which command the model picks is a judgment with real variance. No script asserts it, and this README will not pretend otherwise.

**Gated — the mechanism.** `scripts/smoke/prompt-route-tests.sh` (its own CI step) asserts that six discipline phrases survive in the directive (`Silence is the default`, `AskUserQuestion`, `(Recommended)`, `as asked`, `one picker per named tool per session`, `goal ledger` — not one assertion per numbered rule), that each guard silences the hook, and that it injects once per session. `scripts/validate.sh` fails the build on a hardcoded slash-command token in the hook, or on a fifth prompt-matching pattern — the signature of a routing table regrowing in shell.

**Gated — Bash routing and the state root.** `scripts/__tests__/route.test.sh` (the plugin-harness CI step) runs real commands in temp git repos: a heredoc routes the same skills as an Edit of that file, a Bash call with no target, a missing target or an out-of-root target stays silent and writes no state, a subdirectory cwd keeps state at the repo root, the one-shot holds across Edit then Bash, and the 8-target cap holds. Which interpreter or copy commands escape the parser is listed above; no test can enumerate them.

**Gated — the subagent filter.** `scripts/__tests__/subagent-skills.test.sh` (the plugin-harness CI step) runs the hook against a fake versioned install holding the real agent files: Laravel/Inertia gives `frontend-reviewer` Inertia (plus Vite when `package.json` declares it) and never React Native or Next.js; Next.js gives it Next.js; an absent owning plugin drops its skill; a preloaded skill is not repeated; a built-in, unknown or field-less agent and both off switches stay silent; a subdirectory cwd gives the root's output; the envelope stays under the cap with whole paths. It also asserts `prime.sh` primes the same line from a subdirectory as from the root. **Recorded, not gated — delivery.** One live probe (CLI 2.1.282, haiku, `--plugin-dir`): the subagent's transcript carried the two expected paths as SubagentStart context, and the agent quoted them back. Whether an agent then reads them on a real task is unmeasured.

**Gated — the install layout.** `scripts/smoke/versioned-layout-tests.sh` (its own CI step) runs the firing, suppression and skill-path assertions twice: once against a flat `<plugins>/<plugin>` layout and once against the versioned `<marketplace>/<plugin>/<version>` cache a real install uses. Both directions matter — the suppression cases fail if a resolution bug is "fixed" by making the installed-filter always fire. Until 0.11.0 the hooks resolved the plugins root as `dirname "$CLAUDE_PLUGIN_ROOT"`, correct only under the flat layout, so on a real install every rule was suppressed and the tool-fit check had nothing to say: the router shipped inert and every harness stayed green, because every harness built the flat layout. That is the gap this step exists to close.

**The cost, plainly:** measured on this repository's own plugin tree, the tool-fit injection fell from **6,892 characters to 1,770** when 0.18.0 dropped the rebuilt catalog — and the removed part was the only part that grew with the number of plugins installed. Do not read a token figure out of this sentence: the committed number lives in `scripts/context-budget-dynamic-baseline.json` and covers this plugin's whole dynamic channel (tool-fit injection plus the per-edit hooks) on the worst prompt of the probe corpus. Recount with `bash scripts/context-budget.sh` and read the `plugin (dynamic)` table, never this sentence — and note that the committed baseline still carries the pre-0.18.0 figure until a maintainer re-baselines that channel. One rider: the probe runs against a flat checkout, so it is the cost a working install pays — before 0.11.0 no real install paid it, because nothing was emitted. A chat-only session pays nothing.

**Off switches, by channel.** `CC_ROUTE=off` silences the prompt-level tool-fit check **only**. `CC_REMIND=off` is the marketplace-wide advisory mute and silences both the tool-fit check and the per-edit file nudges — `route.sh` read neither variable until 0.17.0, so a user who muted the marketplace kept getting a nudge on every Edit while this README claimed otherwise. There is deliberately no switch for the file nudges alone: disable the plugin. `CC_SUBAGENT_SKILLS=off` silences `subagent-skills.sh` alone; `CC_REMIND=off` silences it too. `CC_SURFACED_LOG=off` stops the SessionEnd ledger below. `prime.sh`'s SessionStart index and `compact-capsule.sh`'s post-compaction state recall honour no switch — the first is one line at session start, the second is state recovery rather than advice.

It never forces a skill to run — hooks cannot — it injects a directive the model then acts on. It complements the existing description-based skill triggering; it does not replace it.

## Adding a file route

Edit `rules.tsv` — one tab-separated row, no code change:

```
signal_type   pattern                 skill                 owning_plugin   confidence
glob          *.sql                   sql-best-practices    sql             high
content       \b(password|jwt)\b      security-review       security        low
```

**There is no prompt-route table, and adding one is a decided-against design.** Only
`rules.tsv` ships; routes here are FILE-shaped. Prompt-shaped routing existed once and was
removed — `hooks/route-prompt.sh` states why in its header: *"a table only ever routes the
phrasings its author thought of, and every new plugin needed a new row"*. What replaced it
is the host's own command listing plus the model's judgment, which reads meaning rather
than matching strings. An earlier revision of this section pointed at a `prompt-rules.tsv` that has
never existed in this plugin; if you came here to add a row to it, this paragraph is the
answer.

- `signal_type`: `glob` (matched against the edited file's path relative to the project root — see State) or `content` (a `grep -E` pattern matched against the file's contents).
- `confidence`: `high` fires inline once per session; `low` accumulates and flushes as one digest on the next prompt (SessionEnd keeps the ledger).
- A rule only fires if its `owning_plugin` is installed. "Installed" is resolved by `hooks/plugins-dir.sh`, which handles both the flat and the versioned-cache layouts; when it cannot recognise the layout it reports *uncertain*, and uncertain fires. A nudge toward a plugin you do not have costs one line — a suppressed nudge costs the whole point of the router.

### Stack markers (optional 6th column)

When two stacks claim the same file pattern (one engine vs another on `*.sql`, plain PHP vs Laravel on `*.php`), an optional `stack_marker` column discriminates by sniffing a manifest at the repo root:

```
glob   *.sql            mariadb-best-practices   database  high   docker-compose.yml~image:[[:space:]]*"?[a-z0-9./-]*mariadb
glob   *.blade.php      laravel-best-practices   laravel   high   composer.json~laravel/framework
```

- Format: `<manifest>~<ERE>`, split on the **first** `~` — the manifest name cannot contain `~`, but the regex may. Prefix `!` negates the match verdict. `-` or empty means no marker.
- Fallback chain: `||`-separated alternatives (`a~re||b~re`) are tried in order and the **first decisive alternative wins** — its match verdict is final. Alternatives whose manifest is absent/unreadable (or that are malformed) are skipped; no decisive alternative at all fires. Put the authoritative source first: the vue rows check the installed `node_modules/vue/package.json` version before the declared `package.json` range, so `workspace:*`/`latest`/loose ranges resolve to the actually-installed major once dependencies are installed. A literal `||` inside a regex is unsupported (single `|` alternation is fine).
- `@base` in the manifest position matches the ERE against the edited file's **basename** instead of a file's content, so a bare-extension row can exclude a file shape: the `*.js`/`*.ts` design-principle rows carry `!@base~(^[a-z0-9_.-]*\.(config|conf|setup)\.[cm]?[jt]s$|…|\.d\.ts$|\.min\.[cm]?js$|^\.)`, so `tailwind.config.js`, `.eslintrc.js`, `global.d.ts` and `app.min.js` no longer draw a SOLID nudge. `app.config.service.ts` (a `.config.` mid-name) is source and still routes. An older `route.sh` treats an `@base` alternative as an absent manifest and fires — safe in both directions.
- `@path` in the manifest position matches the ERE against the edited file's **path** rather than its basename, which is the only way a row can exclude a DIRECTORY: `dist/index.html` and `src/index.html` share a basename, and the glob engine's one path-aware form (`**/dir/**`) can say "inside", never "not inside". The markup a11y rows (`*.html`, `*.erb`, `*.twig`) carry `!@path~(^|/)(dist|build|out|\.next|_site|coverage|vendor|node_modules)/|\.min\.` so built output draws nothing. The path is relative to the project root when the file sits under it and the payload's own spelling otherwise, so anchor on `(^|/)`, never `^`. An older `route.sh` treats `@path` as an absent manifest and fires — same safe fallback as `@base`.
- A `?` **prefix** on an alternative — `?package.json~"next"`, `?!composer.json~laravel/framework` (the `?` goes first) — makes that alternative **require** its manifest: absent or unreadable becomes decisive-suppress instead of merely indecisive, so a chain of `?` alternatives reads "fire only if a manifest exists and says yes". Without it an absent manifest lets the rule fire anyway — which is how the `**/components/**` Tailwind row nudged a Go module with a `components/` directory, and how the three shadcn rows nudged every `.tsx`/`.jsx`/`.vue` edit in a Next, Nuxt or plain-React repo that had never installed shadcn. Carrying it today: the shadcn rows, the `*.tsx` React Native and Next.js rows, `**/components/**`, and the three Next.js server rows. The default is unchanged and still fire-if-uncertain; `?` is per-row and opt-in.
  - 0.19.0 replaced the `||!@base~.` **default-deny tail** 0.18.0 put on four rows: same behaviour (a basename is never empty, so that alternative was always decisive-suppress), one mechanism instead of two spellings of it. `?` converts only the ABSENT-manifest case — a malformed ERE still fires, and a monorepo whose `package.json` lives in a workspace subdirectory reads as absent here, so a `?` row suppresses there. An older `route.sh` reads `?package.json` as a manifest that does not exist, skips the alternative and fires — the same safe fallback `@base` and `@path` have.
- Fail-open semantics: the manifest is read at the project root (see State), regular files only, capped at 64 KiB. Until 0.20.0 it was read from the session cwd, which follows the model's `cd`. One side effect cuts the other way: a session started inside a monorepo workspace used to read that workspace's `package.json`, and now reads the repo root's. Manifest absent/unreadable → the rule **fires** (undetectable stack keeps today's behavior) — unless the alternative carries the `?` prefix above, which is the one construct that reverses this. `grep -E` exit 0 → satisfied; exit 1 → suppressed; exit ≥ 2 (malformed regex) → fires. `!` inverts only the 0/1 verdict.
- Complementary same-pattern pairs that should co-fire (e.g. a11y alongside react on `*.tsx`) are declared with a pairwise comment directive so the marketplace's overlap gate allows them: `# co-fire-ok: <pattern> <skillA> <skillB>`.

## State

`<repo>` below is the **project root**: the git toplevel above the payload's cwd; outside git, `CLAUDE_PROJECT_DIR` when the cwd sits under it; otherwise the cwd itself. Until 0.20.0 it was the payload cwd, which follows the model's `cd`. In one measured session that meant `app/Enums`, then `app/Models`, then the repo root, and each directory got its own `.claude/` (finding 2 of the review cited above). All four state-touching hooks (`route.sh`, `route-prompt.sh`, `summary.sh`, `compact-capsule.sh`) resolve it the same way, so the file one writes is the file the next reads. `prime.sh` and `subagent-skills.sh` write no state and read their manifests at the same root. A `.claude/` left behind in a subdirectory by an older version is not cleaned up; delete it by hand.

A per-session dedup file lives at `<repo>/.claude/skill-router/fired-<ctx>.json` and is removed at session end. The directory writes a self-ignoring `.gitignore` the first time it is created (0.16.0) — this paragraph said "(gitignored)" before that, and nothing made it true.

`<repo>/.claude/skill-router/compact-log.jsonl` — one line per compaction the capsule fired on, recording whether the phase sentinel's `session_id` matched the post-compaction payload's. **Standing: recorded** — nothing reads it. It exists because two shipped mechanisms key on that match and no probe has established it (`rationale/collective-taskforce-backlog.md` #6); `grep -c true` against it answers the question on real sessions.

`$HOME/.claude/skill-router/<root-slug>/surfaced.jsonl` (the slug of the project root, not of the cwd, since 0.20.0) — **outside the project tree**, one line per session, appended by `summary.sh`: which skills the router nudged inline (`fired`) and which low-confidence signals it accumulated, split into `pending_low_flushed` (the digest actually reached the model) and `pending_low_unflushed` (accumulated, never shown). It records what the router OFFERED, never what the model loaded. `CC_SURFACED_LOG=off` skips the append entirely. **Standing: recorded** — the only reader in this marketplace is `scripts/turn-cost.sh --skills`, a maintainer path that ranks skills and never proposes a deletion.
