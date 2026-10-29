---
name: dialogue-scripting
description: Use when writing or wiring Yarn Spinner dialogue (`.yarn`, `.yarnproject`, `DialogueRunner`, a dialogue view or presenter, `<<once>>`, `when:` node groups) or Ink (`.ink`, inkjs, `Continue()`, `ChooseChoiceIndex`, `#` line tags) — the Yarn Spinner 3 presenter rename, syntax that 2.x lacks, which Yarn Spinner for Godot edition can ship, and Ink's missing localisation.
---

> Last verified: 2026-10-26 — https://docs.yarnspinner.dev/

<!-- version-tail-ok: Yarn Spinner ships as Unity and Godot packages and on NuGet, not npm/composer/pypi; the stamp points at docs.yarnspinner.dev -->

## Read the version first

Read the Yarn Spinner version from where the project installed it: the Unity package
manifest and lock (`Packages/manifest.json`, `Packages/packages-lock.json`), the addon
folder under `addons/` in a Godot project, or the NuGet reference in the `.csproj`. Read
the ink runtime from the ink integration package, or `inkjs` in `package.json`. Yarn
Spinner 2 and 3 differ in API and in compiled output (3.0 requires existing scripts to be
recompiled); never mix snippets across them.

Standing: every rule below is **agent-graded**. No script in this plugin parses `.yarn`
or `.ink`; the Yarn Spinner compiler (`ysc`) and inklecate are the real syntax gates.

## Yarn Spinner 3: what a 2.x memory gets wrong

- Dialogue Views became **Dialogue Presenters** — the docs call them "the same thing,
  but renamed". The built-ins are Line Presenter and Options Presenter; 2.x tutorials
  still say Line View and Options List View.
- The 2.x base class `DialogueViewBase` and its callback methods are replaced by
  `DialoguePresenterBase`, whose methods are async. Override
  `RunLineAsync(LocalizedLine line, LineCancellationToken token)` and return a
  `YarnTask`. A 2.x view is not drop-in compatible; port it.
- The runner waits for every presenter's task before the next line. The base
  implementation does nothing and returns at once, so a custom presenter that misses an
  override shows nothing and raises nothing.
- The cancellation token says the player asked to hurry or skip the current line. A
  presenter that ignores it makes the advance button do nothing.

## Yarn Spinner 3 syntax that 2.x does not have

- `<<once>> … <<endonce>>` runs a block the first time only; `<<once if $cond>>` adds a
  condition, `<<else>>` an alternative, and `<<once>>` at the end of a line or option
  applies to that line alone.
- Node groups: several nodes share one `title:`, each with a `when:` header; at run time
  the runner drops the nodes whose condition fails and picks one of the rest (barks,
  storylets). Every node in a group needs a `when:` header; a missing one is a compile
  error.
- Smart variables compute their value at run time from an expression instead of being
  stored.

## Yarn Spinner for Godot: ship the C# edition

- The C# edition is the one to ship.
- The GDScript edition is official but alpha: its docs say not to ship a game on it yet.
  It needs Godot 4.6 or later, and the `ysc` compiler on `PATH` for automatic
  compilation.

## Ink: localisation is yours to build

- Ink has no built-in localisation: no line IDs, no string tables. Yarn Spinner has both
  (in Unity, "Add Line Tags to Scripts" writes a `#line:` ID into every line, and the
  project builds per-locale string tables).
- For ink, either translate whole `.ink` files per locale, or tag each line with a stable
  ID (`#id:guard_01`) and look the text up in your own tables; community tools automate
  the tagging.
- Line-ID localisation breaks on ink's dynamic text. Glue, mid-line diverts, inline
  variable text and alternatives assemble one displayed line from several source
  fragments, so no single ID covers it. If the game will be translated, decide before
  writing and keep those features out of translatable lines.
- Runtime loop: `Continue()` while `canContinue`, show `currentChoices`, call
  `ChooseChoiceIndex(i)`, then `Continue()` again. The chosen branch prints nothing
  until that next `Continue()`.

## Anti-patterns

- **2.x view in a 3.x project** — subclassing `DialogueViewBase`, or following a 2.x
  tutorial's callback signatures.
- **Silent presenter** — a custom presenter with no `RunLineAsync` override, or one that
  ignores the cancellation token.
- **Shipping on the GDScript alpha** of Yarn Spinner for Godot.
- **Translate-later ink** — glue and inline variables in a game that will be localised.
