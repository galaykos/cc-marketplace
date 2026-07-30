---
description: Set or report the terse output level — lite, full, ultra, off — a chat-message shape contract that never touches code, files, or how much work the turn does.
argument-hint: "[lite | full | ultra | off | status]"
---

# /terse:level

The level is written by this plugin's `hooks/mode.sh` when it sees this command, so
the switch already happened before you read this. Your job is to confirm it and
follow the contract, not to re-implement it.

Parse the first token of `$ARGUMENTS`:

## `lite` / `full` / `ultra`

The hook wrote the level and re-injected the contract. Confirm in **one line**:
name the level and its two budget numbers (answer / work-done report, in prose
lines of ~100 rendered characters each).

| Level | Answer | Report | Word handling |
| --- | --- | --- | --- |
| lite | 10 | 18 | full sentences, filler dropped |
| full | 6 | 12 | articles and filler dropped, fragments fine |
| ultra | 3 | 6 | plus abbreviated prose nouns and causal arrows |

Then apply it from your very next message. Load the `terse-output` skill if the
contract is not already in context.

## `off`

The hook removed the level file. Confirm in one line that normal length resumes.

## `status` or no argument

Report the active level and where it came from, without changing anything:

```bash
printf 'env CC_TERSE=%s\nfile %s: %s\n' "${CC_TERSE:-unset}" \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode" \
  "$(cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode" 2>/dev/null || echo none)"
```

`CC_TERSE` wins over the file when both are set. The level is machine-local and
persists across sessions until changed.

## Never

Do not confuse this with doing less work. Every level compresses the message only:
same tool calls, same verification, same file contents, same commit messages, same
subagent prompts. If a finding does not fit the budget, write it to a file and cite
the path — dropping it is the one failure this plugin counts as worse than verbosity.
