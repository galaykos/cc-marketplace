# reuse-guard

A **warn-only reuse-hygiene guard** so a cooperating agent does not build on dead
code — a symbol that is already deprecated, or one a change has left orphaned.

## Install

```
/plugin marketplace add galaykos/cc-marketplace
/plugin install reuse-guard@cc-plugins-marketplace
```

## Commands

| Command | Does |
|---------|------|
| `/reuse-guard:check [symbol\|path]` | On-demand Tier-2 pass: per-language dead-code tool shellout + export-aware orphan / reachability detection + a full deprecated-reference report for the target. |

## Two tiers

reuse-guard is two-tier by design: a cheap language-agnostic floor that runs
everywhere, plus a precise per-language depth you invoke when you need it.

- **Tier 1 — language-agnostic, ambient, warn-only (reuse-a-corpse).** A
  PostToolUse hook on `Edit|Write|MultiEdit` greps the *incoming added content*
  for references to symbols in a **session-cached deprecated-symbol set**. The
  set is built once per session by grepping the repo for deprecation markers
  (`@deprecated`, `#[deprecated]`, `[Obsolete]`, `Deprecated:` doc-comments,
  `DeprecationWarning`, `DEPRECATED` / `TODO: remove` comments) and cached, so
  there is no repo-wide grep per edit after the first. On a hit it warns once
  (`reuse-guard: added code references \`foo\`, marked @deprecated at path:line —
  prefer its replacement`). High precision, silence is the common case.

- **Tier 2 — per-language precision + orphan detection, on-demand
  (`/reuse-guard:check`).** The false-positive-prone and expensive work lives
  here, off the ambient path: export-aware **orphan / reachability detection**
  (module-private symbols the change left with zero inbound refs, excluding
  exported / public-API symbols), a **per-language dead-code tool shellout**
  when the ecosystem's tool is installed, and a full deprecated-reference report.

## Honest limits

- **Heuristic string match, not resolved semantics.** The deprecated-symbol set
  is a symbol name near a marker; a same-name collision can over- or under-warn.
- **Warn-only.** No hook ever emits `decision:block` or `permissionDecision:deny`.
  It raises the visibility and cost of casual reuse-of-dead-code for a cooperating
  agent — it is **not tamper-proof, not a security boundary**, and defeatable by
  anyone with shell access.
- **Fail-open.** Missing `jq` / `git` / a language tool means exit 0, never a block.
- Precision is Tier-2's job; the ambient tier trades depth for near-zero noise.

## Composition seams

reuse-guard **owns** reuse-time deadness detection (a symbol you are about to
reuse) and on-demand orphan / reachability. It deliberately defers the adjacent
concerns to their owners:

- **"Dead code" as a review-catalog framing** → `code-review` code-smells (the
  dispensables catalog: unreferenced symbols as a review finding).
- **Speculative generality / don't-create-dead-weight** → `code-architecture`
  yagni-check (interfaces with one implementation, config nobody sets).
- **Dependency-level deprecation** (a whole package deprecated/abandoned) →
  `packages` package-hygiene.

## Pairs well with

- **intent-guard** — drift / corner-cutting at done (distinct hook events, so
  co-installed output does not double up: reuse-guard is PostToolUse only).
- **code-review** — code-smells catalogs dead code as a review finding.
- **code-architecture** — yagni-check owns speculative generality.
