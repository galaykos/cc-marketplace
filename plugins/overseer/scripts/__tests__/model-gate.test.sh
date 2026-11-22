#!/usr/bin/env bash
# Tests hooks/model-gate.sh: while a program is open, a prompt's MODEL: line must match the model the Agent call runs.
# Asserts the deny cases (no model passed to an inherit agent, a different model, inherit with a model, an unreadable default)
# and the silent ones (a match by argument or by frontmatter, no MODEL: line, a mid-line MODEL:, no program, another tool, bad JSON).
set -u
here=$(cd "$(dirname "$0")" && pwd); HOOK="$here/../../hooks/model-gate.sh"
[ -x "$HOOK" ] || { echo "FAIL: $HOOK not executable"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq required"; exit 1; }
WS=$(mktemp -d); FH=$(mktemp -d); trap 'rm -rf "$WS" "$FH"' EXIT
git -C "$WS" init -q -b main 2>/dev/null || git -C "$WS" init -q
mkdir -p "$WS/.cc-artifacts/overseer" "$WS/sub"; printf '{"milestones":[]}\n' > "$WS/.cc-artifacts/overseer/program.json"
ag() { mkdir -p "$FH/.claude/plugins/cache/mkt/$1/$2/agents"; printf -- '---\nname: %s\n%b---\nbody\nmodel: haiku\n' "$3" "$4" > "$FH/.claude/plugins/cache/mkt/$1/$2/agents/$3.md"; }
ag task-runner 1.0.0 task-executor 'model: inherit\n'
ag pinned 1.0.0 seat "model: 'opus'\n"
ag bare 1.0.0 seat ''
ag split 1.0.0 seat 'model: opus\n'; ag split 2.0.0 seat 'model: sonnet\n'
pass=0; fail=0
ok() { pass=$((pass+1)); }; bad() { fail=$((fail+1)); echo "FAIL: $1"; }
# pay <cwd> <tool> <prompt> <subagent_type|-> <model|->: the PreToolUse payload the host sends for an Agent call
pay() { jq -cn --arg cwd "$1" --arg tool "$2" --arg p "$3" --arg t "$4" --arg m "$5" --arg tp "$FH/t.jsonl" \
  '{session_id:"s1",transcript_path:$tp,cwd:$cwd,hook_event_name:"PreToolUse",tool_name:$tool,
    tool_input:({description:"d",prompt:$p} + (if $t == "-" then {} else {subagent_type:$t} end) + (if $m == "-" then {} else {model:$m} end))}'; }
run() { pay "$@" | env HOME="$FH" "$HOOK"; }
denies() { local out; out=$(run "${@:2}"); printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 1 ] && ok || bad "$1 should deny in one line: $out"; LAST="$out"; }
silent() { local out; out=$(run "${@:2}"); [ -z "$out" ] && ok || bad "$1 should be silent: $out"; }
P=$(printf 'You are implementing ONE card.\nMODEL: opus\nTOUCH ONLY: a\n')
denies "MODEL: opus to an inherit agent with no model passed (simulation 3)" "$WS" Agent "$P" task-runner:task-executor -
printf '%s' "$LAST" | grep -q 'pass model: \\"opus\\"' && printf '%s' "$LAST" | grep -q 'frontmatter default (inherit)' && ok || bad "the reason names the default and the fix: $LAST"
silent "MODEL: opus with model: opus passed" "$WS" Agent "$P" task-runner:task-executor opus
denies "MODEL: opus with model: sonnet passed" "$WS" Agent "$P" task-runner:task-executor sonnet
silent "MODEL: opus to an agent whose frontmatter pins opus (quoted)" "$WS" Agent "$P" pinned:seat -
denies "MODEL: opus to an agent whose cached copies disagree" "$WS" Agent "$P" split:seat -
denies "MODEL: opus to the default agent with no model" "$WS" Agent "$P" - -
printf '%s' "$LAST" | grep -q 'could not be read' && ok || bad "an unknown default is named: $LAST"
silent "a sentence-ending period is not part of the name" "$WS" Task "$(printf 'MODEL: opus.\n')" - opus
I=$(printf 'Review the diff.\nMODEL: inherit\nRETURN CLEAN\n')
silent "MODEL: inherit, no model, an inherit agent" "$WS" Agent "$I" task-runner:task-executor -
silent "MODEL: inherit, no model, an agent with no model key" "$WS" Agent "$I" bare:seat -
denies "MODEL: inherit with a model passed" "$WS" Agent "$I" - opus
denies "MODEL: inherit to an agent that pins opus" "$WS" Agent "$I" pinned:seat -
silent "nearest neighbour: a prompt quoting MODEL: mid-line" "$WS" Agent "Every dispatch carries a \`MODEL: opus\` line." task-runner:task-executor -
silent "a prompt with no MODEL: line (taskmaster's own seats)" "$WS" Agent "Implement card 03." task-runner:task-executor -
silent "no program open in the project" "$FH" Agent "$P" task-runner:task-executor -
denies "a subdirectory of an open program's project" "$WS/sub" Agent "$P" task-runner:task-executor -
silent "another tool" "$WS" Bash "$P" - -
[ -z "$(printf 'not json' | env HOME="$FH" "$HOOK")" ] && ok || bad "malformed input is silent"
echo "model-gate.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
