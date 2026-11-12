# PHP: what the analyzer run must report

Read by `code-review`'s `analyzer-expert` when the diff holds `*.php`. Tools: phpstan, psalm, phpcs, rector.
The step order is `analyzer-triage`'s; this file adds what is specific to these tools.

## Steps, as they apply here

1. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-analyzers.sh" .` — exit 1 means no
   analyzer is configured: say so, name the cheapest one to add, and STOP.
2. Read the `ci` records to learn which config is authoritative before opening any.
3. Read `phpstan-baseline.neon` / `psalm-baseline.xml` before running anything.
4. Run the exact invocation the detector printed. Report the real exit code. Skip it when CI already passed it on this HEAD (the skill's step 4 says how to tell).
5. Triage into new defect / baselined debt / config gap.
6. Report config gaps last and loudest.

## What only this run can report

The analyzer's blind spots, derived from its config rather than from memory:

- **Level reach.** phpstan levels are cumulative. Name the bug class the configured
  level cannot reach in the code under review — argument types go unchecked below
  level 5, method calls and property access on nullable types below level 8 — not the
  number alone. `level max` is the installed phpstan's highest level (10 since PHPStan
  2.0), so name the version; `level unparsed` means read the config's `level:` yourself.
- **errorLevel direction.** psalm's scale runs backwards: 1 is strictest, 8 loosest.
  Report the direction every time; a bare number misleads every reader.
- **Baseline volume.** A baseline with hundreds of entries means the analyzer's
  verdict on the touched files may be entirely suppressed. Say the count and whether
  any entry covers a file in this diff.
- **Path scope.** A config analysing only `src/` says nothing about `app/` or
  `tests/`. Check the configured paths against the diff's paths and report any file
  the tool never looked at — a green run over an unanalysed file is not evidence.
- **Unenforced config.** No CI workflow invokes the tool: findings are advisory in
  this repo. Label them as such.

## Defer rules

Name these and move on; do not audit them here.

- Laravel-specific idioms, Eloquent N+1, FormRequests, policies → `laravel`'s
  backend-engineer, and `/code-review:review` for the fan-in.
- SQL and schema correctness → `database`'s database-engineer.
- Exploitability and authorization → `/security:review`.
- Applying any fix → `task-runner`'s task-executor or the backend engineer. You
  produce the list; you do not apply it.

## Before finishing

- [ ] The detector ran, and its exit code decided whether to proceed.
- [ ] The baseline was read BEFORE the tool ran, and its count is in the report.
- [ ] Every finding cites the analyzer's own rule identifier, not a coined name.
- [ ] Config gaps are stated as blindness, never as an invented defect list.
- [ ] Nothing was edited.

Output: findings one line each — `path:line — severity — rule-id — problem — fix` —
severity-ordered, then a `Config gaps` block, then one line naming the tool, its
config, its exit code and the baselined-debt count. If no analyzer exists, output is
that single fact and nothing else.
