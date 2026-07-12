---
name: reuse-hygiene
description: Use before reusing an existing function, class, or symbol — confirm it is not deprecated or an abandoned orphan before you build on it, and do not leave the last caller's removal behind as new dead code.
---

Reuse is the cheapest way to write code and the cheapest way to inherit a bug.
Before you call, extend, or copy an existing symbol, spend one moment confirming
it is still alive: not marked deprecated, not an orphan the codebase forgot to
delete. Building on a corpse spreads it — every new caller makes the eventual
removal more expensive and the deprecation more permanent.

This skill is the cooperative half of `reuse-guard`. The plugin's ambient hook
will warn you *after* you add a reference to a deprecated symbol; this skill is
how you avoid earning that warning in the first place, and how you clean up when
your own change turns a live symbol into a dead one.

## Before you reuse a symbol

1. **Check it is not deprecated.** Look at the definition and its doc-comment for
   a deprecation marker — `@deprecated`, `#[deprecated]`, `[Obsolete]`,
   `Deprecated:`, `DeprecationWarning`, or a plain `DEPRECATED` / `TODO: remove`
   comment. A marker is an explicit author signal that this symbol is on its way
   out; a new caller argues the opposite.
2. **Check it is not an orphan.** A symbol with no live callers is dead weight,
   even without a marker. Reusing it resurrects code nobody has exercised — its
   assumptions may already be stale. Confirm it is actually reached before you
   lean on it.
3. **Check the replacement, if any.** A well-written deprecation names its
   successor ("use `bar` instead"). Reaching for the deprecated symbol anyway is
   a choice you should be able to justify, not a default.

## When you are unsure, run the check command

If you cannot tell from a quick read whether a symbol is deprecated or orphaned —
especially in an unfamiliar module, or when the definition is far from the call
site — run:

```
/reuse-guard:check <symbol|path>
```

That Tier-2 pass does the precise, expensive work the ambient hook deliberately
skips: export-aware orphan / reachability detection (it excludes exported /
public-API symbols so a library export is not mistaken for dead code), a shellout
to the ecosystem's real dead-code tool when one is installed, and a full
deprecated-reference report for the target. Use it as a lookup before you commit
to a reuse, not as a gate you wait on — it degrades to the heuristic when no tool
is present, and it never blocks.

## Prefer the documented replacement

When a symbol is deprecated and names its successor, use the successor. If you
have a real reason to touch the deprecated one anyway — a bug fix in code that
must keep working until removal, or a call the replacement does not yet cover —
say so out loud in the change, so the next reader knows it was deliberate and not
an oversight. Silent reuse of a deprecated symbol reads as an accident and invites
the exact drift this guard exists to catch.

## Do not leave an orphan behind

Reuse hygiene runs both directions. When your change **removes the last caller**
of a symbol, you have just created dead code — do not walk away from it:

- **Remove it** in the same change when it is clearly yours to remove (a private
  helper, a local of the module you are editing). Version control remembers it;
  a dead symbol left in the tree only misleads the next reader.
- **Flag it** when removal is out of your scope or the symbol may be part of a
  public surface you cannot see all callers of. Note the now-orphaned symbol so a
  follow-up — or `/reuse-guard:check` — can settle it, rather than letting it rot
  silently.

The one thing not to do is nothing: an orphan you created and ignored is the same
corpse the next agent will be tempted to reuse.

## Reading a reuse-guard warning

If the ambient hook fires — `reuse-guard: added code references \`foo\`, marked
@deprecated at path:line` — it is not a wall, it is a prompt. Do not paper over it:

- **Open the cited `path:line`.** The marker usually explains why the symbol is
  deprecated and what to use instead. Follow that instead of the symbol you reached
  for, unless you have the deliberate reason above.
- **A false positive is possible** (same-name collision, a marker in an unrelated
  comment). Confirm the reference really is the deprecated symbol before you rewrite
  around it — but a real hit is the common case, so verify, do not assume noise.
- **Do not silence it by renaming to dodge the grep.** That defeats the guard
  without fixing the reuse; the successor symbol, not the string match, is the point.

## Composition seams

`reuse-guard` owns a narrow lane — **reuse-time deadness detection** (a symbol you
are about to reuse) and **on-demand orphan / reachability**. It does not try to be
the whole dead-code story. Defer the neighbors to their owners:

- **"Dead code" as a review-catalog framing** — unreferenced symbols surfaced as
  a review finding during a code review — belongs to `code-review` code-smells
  (the dispensables catalog). This skill is a *pre-reuse* check, not a review pass.
- **Speculative generality / creating dead weight** — interfaces with one
  implementation, config nobody sets, hooks nobody calls — belongs to
  `code-architecture` yagni-check. That is about not *building* dead code; this
  skill is about not *reusing* it.
- **Dependency-level deprecation** — a whole package deprecated, abandoned, or
  yanked upstream — belongs to `packages` package-hygiene. reuse-guard reasons
  about symbols inside the repo, not the health of third-party dependencies.

## Honest limits

The ambient tier is a heuristic string match (a symbol name near a deprecation
marker), not resolved semantics, so a same-name collision can over- or under-warn;
it is warn-only and defeatable by anyone with shell access. Treat its silence as
"probably fine," not "proven safe" — when the reuse matters, run the check
command and read the definition yourself. The value here is catching the case that
actually bites: a cooperating agent reaching for a symbol whose author already
said, in writing, that it is on its way out.
