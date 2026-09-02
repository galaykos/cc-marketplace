#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
#
# SessionStart, matcher `compact` ONLY. Re-asserts the deliberation marker after a
# compaction has taken the decision out of the model's context.
#
# WHY THIS HOOK EXISTS. approach-deliberation's own SKILL.md:40 says "Check the
# MARKER, never memory" — the marker is `.claude/approaches/deliberated.json` and
# it survives compaction perfectly well. What does NOT survive is the model's
# knowledge that a deliberation happened at all, so it never thinks to look. The
# documented failure is a compacted session re-litigating a shape that was already
# decided: the marker was on disk the whole time and nothing pointed at it.
#
# WHY SessionStart AND NOT PreCompact. PreCompact is the intuitive choice and it
# does not work: Claude Code writes PreCompact stdout to the debug log and never
# adds it to the model's context. The documented exceptions are UserPromptSubmit,
# UserPromptExpansion, SessionStart and PostModelSwitch. SessionStart is also the
# event that carries a `compact` source, so it is both the only channel that
# reaches the model and the only one that knows a compaction just happened.
#
# WHY IT COSTS NOTHING IN THE COMMON CASE. The matcher is `compact`, so this is
# silent on startup, resume, clear and fork. A session that never compacts never
# pays. A session that compacts pays ~40 tokens once per compaction — set against
# re-running a four-persona blind panel, which is what it prevents.
#
# LIMITATION (honest scope):
#   - Advisory. SessionStart stdout informs a turn; it cannot block one. If the
#     model re-deliberates anyway, nothing here stops it.
#   - It re-asserts THAT a decision exists and which task it was for. It does not
#     restore the REASONING — the alternatives weighed, the kill-trigger. Those
#     live in the transcript the compaction just summarized, and no hook can pull
#     them back.
#   - It cannot tell whether the marker's task is still the task in hand. A stale
#     marker from an abandoned task will be announced exactly like a live one;
#     the skill's own staleness rules still apply.
#   - Marker-shaped only. A deliberation that ran and never wrote the marker is
#     invisible here, the same blind spot the skill already carries.
{
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  src=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null) || exit 0
  # Belt and braces: the hooks.json matcher already scopes this to compaction, but
  # a hand-edited settings.json could wire it without one.
  [ "$src" = "compact" ] || exit 0

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0

  marker="$cwd/.claude/approaches/deliberated.json"
  [ -f "$marker" ] || exit 0

  task=$(jq -r '.task // empty' "$marker" 2>/dev/null) || exit 0
  by=$(jq -r '.by // empty' "$marker" 2>/dev/null)
  at=$(jq -r '.at // empty' "$marker" 2>/dev/null)
  [ -n "$task" ] || exit 0

  printf '[approaches] This session was compacted. A deliberation marker survives on disk: task "%s"' "$task"
  [ -n "$by" ] && printf ', decided by %s' "$by"
  [ -n "$at" ] && printf ' at %s' "$at"
  printf '.\n'
  printf 'The SHAPE of this change is already settled — do not re-run approach-deliberation or an opinion panel for it. Read %s and continue from the decision. If the task in hand is a DIFFERENT one, the marker does not apply and a fresh deliberation is correct.\n' ".claude/approaches/deliberated.json"
} 2>/dev/null || exit 0
exit 0
