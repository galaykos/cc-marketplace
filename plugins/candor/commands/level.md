---
description: Set or report the terse output level — lite, full, ultra, wenyan-*, a reader name (newcomer, expert, on-call), off — a chat-message shape contract that never touches code, files, or how much work the turn does.
argument-hint: "[lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra | newcomer | expert | on-call | off | status]"
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
option — then `active: <level> <source>`. The option comes from `claude plugin configure`
(CLI 2.1.285+) when the host answers, which sees user and managed settings and their
drop-ins; otherwise the option line names the settings file it read instead. The first non-empty layer wins, in that order, and a
value that is not a level below counts as `off` rather than falling through to the next layer. A reader name
adds the length level it maps to as a third word: `active: newcomer file lite`.

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

## `newcomer` / `expert` / `on-call`

A reader name says who is reading. It takes one length level's budgets — `newcomer` →
`lite`, `expert` → `full`, `on-call` → `ultra` — and the hook adds one `Reader <name>:` line
with its word rule, which replaces that level's word layer, and its cap on lists and findings
(the `terse-output` skill's reader table). It replaces a length level; it does not stack on
one. Check the level-file line and `active` as above, then confirm in **one line**: the reader
name, the length level and its two budget numbers, the word rule and the cap.
Standing: unenforceable — nothing rewrites a reply; /candor:check counts prose lines only.

## `off`

The hook removed the level file, a reader name included, and its context this turn says whether `CC_TERSE` or
the `cc_terse` option still keeps a level active. If it says so, report that, whatever
`active` shows; when `active` is `off` anyway, add that the option sits where this
command cannot read it — always this session's `--settings` file, perhaps MDM or
server-managed policy (unmeasured); when the option line
names a settings file rather than `claude plugin configure`, also a managed drop-in or
policy, a symlinked settings file, or any settings file when `jq` is missing.
Otherwise read `active`: if it is `off`, confirm in one line that normal
length resumes. If it still names a level, do not say that — name the source holding it
instead: `env` is `CC_TERSE` (unset it); `option` is the `cc_terse` option in the
settings file printed — set it to `off` in `/config`, unless that file is
`managed-settings.json`: administrator policy, which `/config` cannot override; `file`
means the file was not removed (a symlink the hook will not touch, or an unwritable
config dir).

## `status` or no argument

Report, without changing anything, every source the block above printed and which one
wins (`active`; for a reader name, both the name and its length level). The level file and the option persist across sessions until changed;
`CC_TERSE` lasts as long as the environment that set it. The hooks apply a `cc_terse`
this command cannot see: one saved only in this session's `--settings` file, always;
perhaps one in MDM or server-managed policy (unmeasured); and
when the option line names a settings file, one in managed drop-ins or policy, in a
symlinked settings file, or in any settings file when `jq` is missing. Say so when
`active` is `off` and the user reports terse replies. The badge never asks the host (about
half a second per call, too slow for every keystroke), so it misses all of those.

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
