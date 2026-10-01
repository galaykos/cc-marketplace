---
description: Set or report the terse output level — lite, full, ultra, wenyan-*, off — a chat-message shape contract that never touches code, files, or how much work the turn does.
argument-hint: "[lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra | off | status]"
disable-model-invocation: true
---

# /candor:level

The level is written by this plugin's `hooks/mode.sh` when it sees this command,
so the switch normally happened before you read this. It can also have failed
silently — an unwritable config dir, or a state file someone replaced with a
symlink, both make the hook exit without writing. **Read the state before you
confirm anything**; announcing a level that was never written is worse than the
switch not happening:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/level.sh" --sources
```

It prints each layer the hooks read — `CC_TERSE`, the level file, the `cc_terse` /config
option — then `active: <level> <source>`. The first non-empty layer wins, in that order, and a
value that is not a level below counts as `off` rather than falling through to the next layer.

Parse the first token of `$ARGUMENTS`:

## `lite` / `full` / `ultra` (and the `wenyan-*` variants)

The hook wrote the level and re-injected the contract. If the level-file line does
not show the level asked for (`wenyan` is written as `wenyan-full`), say the switch
failed. If `active` names another level, say which source overrides it (`CC_TERSE`:
unset it). Otherwise confirm in **one line**:
name the level and its two budget numbers (answer / work-done report, in prose
lines of ~100 rendered characters each).

| Level | Answer | Report | Word handling |
| --- | --- | --- | --- |
| lite | 10 | 18 | full sentences, filler dropped |
| full | 6 | 12 | articles and filler dropped, fragments fine |
| ultra | 3 | 6 | plus abbreviated prose nouns and causal arrows |

The three `wenyan-lite` / `wenyan-full` / `wenyan-ultra` levels are the SAME rows
of that table — identical prose-line budgets — with the word layer swapped for a
classical-Chinese register (`terse-output`'s `references/wenyan.md`). Confirm one of
them the same way, naming the register alongside the budgets.

Then apply it from your very next message. Load the `terse-output` skill if the
contract is not already in context.

## `off`

The hook removed the level file, and its context this turn says whether `CC_TERSE` or
the `cc_terse` option still keeps a level active. If it says so, report that, whatever
`active` shows; when `active` is `off` anyway, add that the option sits where `level.sh`
cannot read it — a `--settings` file, a managed drop-in or policy, or a symlinked
settings file. Otherwise read `active`: if it is `off`, confirm in one line that normal
length resumes. If it still names a level, do not say that — name the source holding it
instead: `env` is `CC_TERSE` (unset it); `option` is the `cc_terse` option in the
settings file printed — set it to `off` in `/config`, unless that file is
`managed-settings.json`: administrator policy, which `/config` cannot override; `file`
means the file was not removed (a symlink the hook will not touch, or an unwritable
config dir).

## `status` or no argument

Report, without changing anything, every source the block above printed and which one
wins (`active`). The level file and the option persist across sessions until changed;
`CC_TERSE` lasts as long as the environment that set it. Not seen by this command or the
badge, though the hooks apply it: a `cc_terse` saved only through a `--settings` file,
managed drop-ins or policy, or in a symlinked settings file — say so when `active` is
`off` and the user reports terse replies.

Then print the reference card (display only, change nothing):

| Command | What it does |
|---|---|
| `/candor:level [name\|status]` | Set or report the level; persists across sessions |
| `/candor:check [--last N] [--tokens]` | Measure turn-final messages against the budget, beside the candour axes |

Reports use one skeleton: verdict → blocker or decision → artifacts → ≤5 findings →
skipped (`none` when nothing was) → next. Tables, code blocks and trees are free. `wenyan`
alone is an alias for `wenyan-full`. Chat prose only: the same tool calls run, the
same tests run, files are written at full length.

## Never

Do not confuse this with doing less work. Every level compresses the message only:
same tool calls, same verification, same file contents, same commit messages, same
subagent prompts. If a finding does not fit the budget, write it to a file and cite
the path — dropping it is the one failure this plugin counts as worse than verbosity.
