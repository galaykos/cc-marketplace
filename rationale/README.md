# rationale/

Tracked design rationale that must survive but must not ship inside a plugin.

`CLAUDE.md` sends task docs, specs, and task history to `taskmaster-docs/`, which
is gitignored — correct for working material, wrong for anything that must
survive a fresh clone. It also said a document that must be tracked "goes in a
repo-level location outside `plugins/`" without naming one, and both candidate
names (`docs`, `taskmaster-docs`) are ignored by `.gitignore`. So the rule
pointed at nothing, and the only way to obey it was to delete the document.

This directory is that location.

## What belongs here

- Design rationale for a plugin's shape — the "why it is built this way" a
  reader needs once and a plugin loader should never pay tokens for.
- Post-mortems and decision records whose conclusions are already encoded in a
  gate, a skill, or a template, and whose reasoning would otherwise be lost.

## What does not

- **Anything a plugin needs at runtime.** If a skill reads it, it is a
  `references/` file inside that skill, not a document here.
- **Working task material** — specs, cards, ambiguity ledgers, session history.
  Those stay in `taskmaster-docs/`, gitignored on purpose.
- **A copy of something that ships.** Two copies of one rule is a guarantee that
  one of them will eventually be wrong. Put the rule where it ships and link it.

## Standing reviews worth re-reading

- `2026-09-01-fable5-prompt-alignment.md` — the leaked Fable-5 system prompt held
  against nine plugins; the eight fixes landed, the reasoning for what was NOT
  changed is only here.
- `claude-md-incident-log.md` — every number `CLAUDE.md` carried and how it rotted.

`scripts/validate.sh` enforces that non-functional `.md` files stay out of
`plugins/`. Nothing enforces what lands here — this file is `recorded`, not a
gate, and saying so is the point.
