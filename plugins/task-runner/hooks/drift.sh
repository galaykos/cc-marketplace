#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even under a
# stripped or broken PATH, where `env bash` itself exits 127.
#
# PostToolUse. The AD-HOC complement to scope.sh, which is a provable no-op on most turns:
# scope.sh:32 is `[ -r "$scope" ] || exit 0`, so when there is no task-runner card — a
# one-line request typed straight into a session, which is the common case — nothing in
# this marketplace watches whether the work stayed near the ask. This is the only surface
# here that is stack-agnostic by construction: it counts FILES against a REQUEST, so it
# reads a Dockerfile turn, a SQL turn and a React turn identically.
#
# THE THRESHOLD IS MEASURED, NOT CHOSEN. 400 local transcripts, 169 turns that edited at
# least one file: p50=2, p75=5, p90=12, p95=21, p99=40, max=157. DRIFT_FLOOR is p90, so
# roughly one edit-turn in ten can reach it before the two filters below apply. An earlier
# draft of this hook proposed 4 — that would have fired on about a third of all turns,
# which is the "a number someone wrote down" non-trigger that lean/skills/cost-model
# rejects, and is why this hook was refused the first time it was proposed rather than
# shipped with a guess. Re-derive from your own transcripts before changing it.
#
# STANDING: advisory. additionalContext is not a blocking key and this exits 0 on every
# path. It asks a question; it never renders a verdict. Breadth is not wrongness.
#
# LIMITATION (honest scope — the four laws, see
# .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
#   - BREADTH ONLY, NEVER DEPTH. 300 lines of unasked refactor inside the one file the
#     request named is completely invisible here, and that is probably the commoner way to
#     stray. This measures the axis that is countable, not the axis that matters most.
#   - A legitimately wide mechanical request IS a false positive. The breadth-marker list
#     below ("everywhere", "rename", "migrate", …) exists to cut the obvious cases, and it
#     is a word list, so it will miss phrasings nobody thought of.
#   - It reads the LAST typed user message only. A request built up over three turns is
#     scored against its final sentence.
#   - It cannot see a fan-out's total: each subagent context counts its own edits, the same
#     aggregate blind spot lean/hooks/budget.sh and comment-discipline/hooks/density.sh
#     each name for themselves.
#   - Whether a given extra file was NECESSARY needs a reader. That judgment stays
#     agent-graded, and is why the message ends in a question.
#
# Off switches: CC_REMIND=off silences every advisory nudge here; CC_DRIFT=off only this.
#
# FAIL-OPEN: missing jq, unreadable transcript, unwritable state, or any error exits 0.
{
  [ "${CC_REMIND:-}" = "off" ] && exit 0
  [ "${CC_DRIFT:-}" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || exit 0

  # A declared scope means scope.sh owns this turn; two voices on one territory is the
  # collision plugins/*/lane.tsv exists to prevent.
  [ -r "$cwd/.claude/task-runner/scope.json" ] && exit 0
  [ -r "$cwd/.claude/task-runner/active-run.json" ] && exit 0

  tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  [ -n "$tp" ] && [ -r "$tp" ] || exit 0            # no transcript → nothing to compare against

  DRIFT_FLOOR=12          # p90 of 169 measured edit-turns; see the header
  UNNAMED_RATIO=2         # at least half the files unnamed in the ask (1/N where N=2)

  # Only the tail is read: a long session's transcript is large, and everything this needs
  # sits after the last typed user message.
  # Transcript lines are JSON OBJECTS, one per line — not JSON-encoded strings. An
  # earlier draft piped them through `fromjson`, which wants a string, so every line was
  # discarded and the hook was silent on every input including the ones it exists for.
  # It looked exactly like correct suppression: three silence fixtures passed and the one
  # positive fixture did not, which is why a positive case is not optional.
  tail_json=$(tail -n 900 "$tp" 2>/dev/null)
  [ -n "$tail_json" ] || exit 0

  ask=$(printf '%s\n' "$tail_json" | jq -rs '
      (map(select(.type=="user" and (.message.content|type=="string"))) | last | .message.content) // ""
    ' 2>/dev/null)
  [ -n "$ask" ] || exit 0

  files=$(printf '%s\n' "$tail_json" | jq -rs '
      (map(.type=="user" and (.message.content|type=="string")) | rindex(true)) as $i
      | (if $i == null then [] else .[$i+1:] end)
      | map(.message.content // [] | if type=="array" then .[] else empty end
            | select(.type=="tool_use")
            | select(.name=="Edit" or .name=="Write" or .name=="MultiEdit")
            | .input.file_path // empty)
      | unique | .[]
    ' 2>/dev/null)
  count=$(printf '%s\n' "$files" | grep -c . 2>/dev/null)
  [ "${count:-0}" -ge "$DRIFT_FLOOR" ] || exit 0

  # A request that ASKS for breadth is not drift. Cheap word list, and its misses are
  # named in the limitation above.
  printf '%s' "$ask" | grep -qiE '\b(everywhere|every file|all (the )?(files|of them)|across the|entire|whole (repo|codebase|project)|rename|migrate|sweep|bulk|each of|throughout|codebase-wide|repo-wide)\b' && exit 0

  unnamed=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    b=$(basename "$f")
    printf '%s' "$ask" | grep -qF "$b" || unnamed=$((unnamed + 1))
  done <<EOF
$files
EOF
  [ $((unnamed * UNNAMED_RATIO)) -ge "$count" ] || exit 0

  # One question per user message, not per edit. Keyed on the transcript AND the ask, both
  # hashed: the raw key is an absolute path, and pasting one into a filename names a file
  # whose parents never existed — see authoring-hooks, references/one-shot-state.md.
  ctx=$(printf '%s%s' "$tp" "$ask" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  dir="$cwd/.claude/task-runner"
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  marker="$dir/drift-$ctx"
  [ -e "$marker" ] && exit 0
  : > "$marker" 2>/dev/null || exit 0

  msg=$(printf 'task-runner: %s files edited since the request, %s of them not named in it. Breadth is not wrongness — a wide change can be exactly right. The question is whether each of those files was asked for, implied by what was asked, or picked up on the way past. If some were picked up, say so now rather than at the end. (Advisory: counts breadth only, never depth — an unasked refactor inside a named file is invisible to this. CC_DRIFT=off silences it.)' \
    "$count" "$unnamed")
  jq -cn --arg ctx "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
} 2>/dev/null
exit 0
