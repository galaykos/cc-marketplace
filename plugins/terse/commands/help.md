---
description: Print the terse reference card — levels and their budgets, every command, the crew agents, and what the mode never touches. One-shot display; changes no state.
---

# /terse:help

Print this card as-is. Do not change the level, do not write any file, do not
offer to do anything afterwards.

## Levels — `/terse:level <name>`

| Level | Answer | Report | Word layer |
|---|---|---|---|
| `lite` | 10 | 18 | full sentences, filler dropped |
| `full` | 6 | 12 | articles and filler dropped, fragments fine |
| `ultra` | 3 | 6 | plus abbreviated prose nouns, causal arrows |
| `wenyan-lite` / `wenyan-full` / `wenyan-ultra` | same as above | | classical Chinese register |
| `off` | — | — | normal length resumes |

Reports use one skeleton: verdict → artifacts → ≤5 findings → skipped (`none` when
nothing was) → blocker → next. Budgets are prose lines of ~100 rendered characters. Tables, code blocks and trees
are free. `wenyan` alone is an alias for `wenyan-full`.

## Commands

| Command | What it does |
|---|---|
| `/terse:level [name\|status]` | Set or report the level; persists across sessions |
| `/terse:check [--last N] [--tokens]` | Measure turn-final messages against the budget |
| `/terse:commit` | Conventional Commits message from the staged diff |
| `/terse:compress <file>` | Compress one prose markdown file, with backup |
| `/terse:help` | This card |

## Crew — compressed-return subagents

`terse-investigator` finds code and returns `path:line` rows · `terse-builder`
edits at most 2 decided files and returns a receipt · `terse-reviewer` returns
`path:line: severity: problem. fix.` Routing lives in the `terse-crew` skill.

## Never compressed

Reasoning and verification depth · tool calls · code · files written to disk ·
commit messages · prompts to subagents · quoted errors, paths, identifiers,
numbers · security warnings and destructive-action confirmations · steps the user
must perform by hand.

Turn it off with `/terse:level off`, or `CC_TERSE=off` in the environment.
