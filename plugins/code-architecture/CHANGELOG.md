# Changelog

All notable changes to the code-architecture plugin.

## 0.12.0

### Added

- **`/code-architecture:coding-task`** and the `coding-entry` skill behind it — an
  entry point for coding work typed straight into a session, where nothing
  previously stated the house rules before the first edit.

  Skills reached work in exactly two ways before this: `Skills to apply` on a
  taskmaster card (delegated, spec'd work only) and skill-router's nudge (which
  fires AFTER a file is edited). Ad-hoc work hit neither.

  **Load vs prime.** Five always-relevant skills are loaded in full
  (comment-discipline, testing-best-practices, plan-before-code,
  low-cognitive-load, code-smells — ~9.5k tokens). Everything stack-matched is
  PRIMED: one `Read <abs-path>` line, expanded only when the work reaches that
  surface. Loading the matched set eagerly measures 17.9k on a Laravel + Inertia
  + React repo and 37k worst case, against 12.4k for this marketplace's entire
  always-on budget — most of it for surfaces the task never touches. Priming is
  the idiom `delegation-contracts` § Skill priming already uses for cards.

  **The triage line is mandatory, and not decoration.** Typing a slash command
  silences two hooks that fire on a plain prompt: `taskmaster/hooks/remind.sh:9`
  and `skill-router/hooks/route-prompt.sh:59` both exit on `/*`. So this command
  does not run alongside the clarify nudge — it replaces it. It emits one line —
  `trivial` / `needs a spec` / `already spec'd` — and hands to `/taskmaster:task`
  or `/task-runner:run` accordingly. Without that line, using the command would
  silently cost you a guardrail.

  **Ownership before size.** The triage asks first whether a deeper command already
  owns the shape of work — `/ui-ux:build` for a component, `/craft-layer:craft` for a
  whole app, `/craft-layer:sections`, `/ui-ux:theme`, `/debugging:debug`,
  `/ultra-deep-research:research` — and hands over with a one-line `route:` instead of
  loading anything. Those commands prime their own skills; `/ui-ux:build` in particular
  already resolves the stack skill and injects Read paths into its worker
  (`ui-ux/commands/build.md:43`), which is why a UI sibling of this command was
  considered and rejected rather than built. Schema and infrastructure work gets no
  entry command either: by blast radius it lands in the `needs a spec` row, and
  taskmaster's `erd` skill owns data modelling.

  `references/skill-map.md` holds the manifest → skill table. The file → skill
  half is NOT duplicated there; skill-router's `rules.tsv` owns it and fires on
  every write.

### Notes

- **Standing: agent-graded.** No script checks that a `trivial` verdict was
  honest, that a primed path was read, or that detection matched reality.
  `validate.sh` gates what it can — the 150-line body ceiling (91 used), the
  description linter, and `pc_handoff_refs` resolution for every `plugin:skill`
  token in the map. No new smoke harness ships: the existing gates cover every
  mechanically checkable property, and a harness re-asserting them would be the
  theater this repo's own laws name. Behaviour is judged by a reader.
- **A new command is not free.** It adds one line to skill-router's tool-fit
  catalog, injected on every work-shaped prompt: +25 dynamic tokens per prompt,
  forever, plus +142 always-on for the two descriptions. Both baselines are
  updated in this change rather than left to fail someone else's CI.
- Scope held deliberately narrow: no question rounds (grill), no spec or cards
  (taskmaster), no execution (task-runner). It primes and triages.
