---
name: reuse-hygiene
description: Use before reusing an existing function, class, or symbol — confirm it is not deprecated or an abandoned orphan — and when a change removes the last caller of something, so no new dead code is left behind. Covers the deep pass when a quick read cannot settle it.
---

Reuse is the cheapest way to write code and the cheapest way to inherit a bug.
Before you call, extend, or copy an existing symbol, spend one moment confirming
it is still alive: not marked deprecated, not an orphan the codebase forgot to
delete. Building on a corpse spreads it — every new caller makes the eventual
removal more expensive and the deprecation more permanent.

Reuse hygiene runs both directions: do not build on dead code, and do not leave
dead code behind when your own change kills the last caller.

## Before you reuse a symbol

1. **Check it is not deprecated.** Look at the definition and its doc-comment for
   a deprecation marker — `@deprecated`, `#[deprecated]`, `[Obsolete]`,
   `Deprecated:`, `DeprecationWarning`, `typing_extensions.deprecated`, or a plain
   `DEPRECATED` / `TODO: remove` comment. A marker is an explicit author signal
   that this symbol is on its way out; a new caller argues the opposite.
2. **Check it is not an orphan.** A symbol with no live callers is dead weight,
   even without a marker. Reusing it resurrects code nobody has exercised — its
   assumptions may already be stale. Confirm it is actually reached before you
   lean on it.
3. **Check the replacement, if any.** A well-written deprecation names its
   successor ("use `bar` instead"). Reaching for the deprecated symbol anyway is
   a choice you should be able to justify, not a default.

During a review pass, the same three questions apply to the symbols the diff
newly references — a hunk that reaches for a marked symbol is a finding, with the
marker's `path:line` as its evidence.

## The deep pass, when a read cannot settle it

In an unfamiliar module, or when the definition is far from the call site, do the
precise work rather than guessing. It is **advisory** — it reports, it never edits
code and never gates a change.

**1. Shell out to the ecosystem's dead-code tool, only if it is on `PATH`.** A tool
that is absent, misconfigured, erroring, or slow → degrade to step 2 and say
precision was unavailable. Apply a timeout (~60s) and an output cap (~200 lines).

- **JS/TS** (`package.json`) — prefer **knip** (`npx --no-install knip`); `ts-prune`
  only as a fallback. A non-zero exit usually means "found unused exports," not
  failure: parse stdout and treat parseable findings as success.
- **Python** (`pyproject.toml` / `setup.cfg` / any `*.py`) — **vulture**. It exits 0
  even with findings, so read stdout, not the exit code. Favor high-confidence
  items; mark low-confidence ones soft.
- **Go** (`go.mod`) — **deadcode**
  (`go run golang.org/x/tools/cmd/deadcode ./...`). It needs a buildable `main`; a
  library-only module or a build error → degrade, and say reachability could not be
  analyzed without an entrypoint.
- **Rust** (`Cargo.toml`) — no good answer. `cargo-udeps` reports unused
  *dependencies*, not dead *symbols* — wrong granularity. Note the gap and fall
  through to step 2; compiler `dead_code` warnings from a build you already have are
  the closest signal. Do not force a build.
- **Anything else** — step 2 only.

**2. Export-aware orphan detection.** This is where structural false positives live,
so bound it tightly:

- Locate the definition(s), then count inbound references repo-wide, subtracting the
  definition sites and any reference that lives **only in test files** — a symbol
  used solely by tests is scaffolding, noted separately, not a live production use.
- Report an **orphan only when both hold**: the symbol is module-private /
  non-exported, **and** it has zero non-definition, non-test inbound references.
- **Exported symbols are excluded from the orphan verdict.** A library export, a
  barrel re-export, an `export … as` alias, a `pub`/`public` item, or a symbol named
  in a config or manifest may have every caller outside this repo. Calling those dead
  is the classic false positive. Report their inbound-ref count as information only.

**3. Deprecated-reference report.** Independently of orphan status: if the target's
definition carries a marker, list every site still referencing it and name the
documented replacement when one is given.

**Output** — a short advisory report: which tool ran (or "degraded to heuristic" and
why) · deprecated? marker location, replacement, reference sites · orphan? or, for an
exported symbol, the ref count plus the explicit note that it is excluded from the
verdict · a recommendation (remove, migrate to the replacement, or "looks live, safe
to reuse"). No file writes, no edits — the user or a follow-up decides.

## Prefer the documented replacement

When a symbol is deprecated and names its successor, use the successor. If you have a
real reason to touch the deprecated one anyway — a bug fix in code that must keep
working until removal, or a call the replacement does not yet cover — **say so out
loud in the change**, so the next reader knows it was deliberate and not an oversight.
Silent reuse of a deprecated symbol reads as an accident.

Do not dodge the problem by renaming around a grep. The successor symbol, not the
string match, is the point.

## Do not leave an orphan behind

When your change **removes the last caller** of a symbol, you have just created dead
code — do not walk away from it:

- **Remove it** in the same change when it is clearly yours to remove: a private
  helper, a local of the module you are editing. Version control remembers it; a dead
  symbol left in the tree only misleads the next reader.
- **Flag it** when removal is out of scope, or the symbol may sit on a public surface
  whose callers you cannot see. Note the now-orphaned symbol so a follow-up settles
  it, rather than letting it rot silently.

The one thing not to do is nothing: an orphan you created and ignored is the same
corpse the next agent will be tempted to reuse.

## Composition seams

This skill owns a narrow lane — **reuse-time deadness** (a symbol you are about to
build on) and **orphan detection on demand**. It is not the whole dead-code story:

- **"Dead code" as a review catalog** — unreferenced symbols surfaced as a finding
  during a review — belongs to `code-smells` (the dispensables catalog) in this
  plugin. That is a review pass; this is a *pre-reuse* check.
- **Speculative generality / creating dead weight** — interfaces with one
  implementation, config nobody sets, hooks nobody calls — belongs to
  `code-architecture` yagni-check. That is about not *building* dead code; this is
  about not *reusing* it.
- **Dependency-level deprecation** — a whole package deprecated, abandoned, or yanked
  upstream — belongs to `packages` package-hygiene. This reasons about symbols inside
  the repo, not third-party health.
- **Pre-existing dead code passed mid-task** — a corpse you notice while editing for
  an unrelated reason — belongs to `code-architecture` plan-before-code: mention it,
  never delete it in an unrelated diff. The orphan rule above covers only orphans
  *your* change creates. (Admission law: `claude-authoring/skills/authoring-skills/SKILL.md` "The four laws".)

## Honest limits

Marker detection is a **heuristic string match** — a symbol name near a deprecation
marker, not resolved semantics — so a same-name collision can over- or under-warn.
Nothing here blocks anything, and any of it is defeatable by an agent with shell
access; it raises the visibility of casual reuse-of-dead-code, not an adversary's.
Treat a quiet result as "probably fine," not "proven safe" — when the reuse matters,
run the deep pass and read the definition yourself. The value is catching the case
that actually bites: reaching for a symbol whose author already said, in writing,
that it is on its way out.
