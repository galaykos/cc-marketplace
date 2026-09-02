# quality-suite

Meta-bundle: the code-quality plugins that carry a **mechanism** — something that
gates, blocks, warns at write time, or routes — in one install. Review and code
smells, architecture principles with the evidence-at-claim Stop gate, comment
discipline, destructive-command blocking, secret-leak prevention, and file-aware
skill auto-routing. (The membership rule is prose — no script checks it; code-review's
own mechanism is the review fan-in plus an advisory nudge, not a gate.) Uninstalls
cleanly: `/quality-suite:uninstall` removes the bundle and prunes the plugins it
auto-installed.

The nine advisory disciplines this bundle used to carry — security, a11y,
debugging, performance, resilience, packages (now stack-scan), observability, approaches in 0.7.0, <!-- removed-ok -->
and testing in 0.9.0 (it ships no ENFORCEMENT hook — its PostToolUse hook is advisory) — moved to **quality-principles-suite**.
They were never gates, and bundling them here meant a project wanting enforcement
paid for their always-on description context too. Install both if you want what
the old bundle was; the split exists so that is a choice. Deliberate design
patterns and KISS/YAGNI doctrine live in the siblings too: pattern-selection in
quality-principles-suite's approaches, the clarify-before-code question pipeline
in taskmaster-suite.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install quality-suite@cc-plugins-marketplace
```

## What's included

- **code-review** — correctness bugs, code smells, and convention drift on any diff or PR, plus `/code-review:review`
- **code-architecture** — plan-before-code, SOLID, YAGNI, and evidence-based verification via `/code-architecture:plan`, `/code-architecture:solid`, `/code-architecture:yagni`, `/code-architecture:verify`
- **command-guard** — PreToolUse hook that denies irreversible destructive commands and asks on scoped ones, plus `/command-guard:check`
- **secret-scanning** — PreToolUse hook that blocks high-confidence secrets at write time, plus `/secret-scanning:scan`
- **skill-router** — hook that auto-loads the matching best-practice skill on edit
- **candor** — a Stop gate on the two dishonesty shapes a script can prove: an unverified claim stated as done, and a silent scope reduction, plus `/candor:check`
- **lean** — prices every line, test, comment and file as a debit, so the smallest change that satisfies the requirement is the one that ships
- **comment-discipline** — routes every fact to the artifact that cannot lie about it and spends comments only where nothing else can hold them; a PostToolUse hook warns on all six noise categories and a PreToolUse lane denies the two strictest before the write, plus `/comment-discipline:review`

| Command | What it does |
|---------|--------------|
| `/quality-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **quality-principles-suite** — the advisory half, split out of this bundle in 0.7.0
- **taskmaster-suite** — spec and task-card pipeline whose output these reviews gate
- **git-workflow** — full-suite verification before merge/PR when a branch finishes
