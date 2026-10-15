#!/usr/bin/env bash
# Tests for rv-observe.sh (PostToolUse dispatch observer) and rv-consent.sh (PreToolUse
# consent ask) from a payload cwd INSIDE the project — the state-root cases. Their gate
# behaviour (counts, disclosure) is exercised with candor's gate in
# scripts/smoke/completion-gate-hook-tests.sh; this harness covers only where they look.
#
# Why: the payload cwd follows the model's `cd` (rationale/2026-09-25-session-plugin-usage-
# review.md, finding 2). Both hooks read the run sentinel at `$cwd/.claude/...`, so after a
# `cd app/Models` the observer recorded no reviewer dispatch and the consent ask went silent.
set -u
unset CLAUDE_PROJECT_DIR   # the hooks' state-root resolver reads it; fixtures must not inherit it

here=$(cd "$(dirname "$0")" && pwd)
OBS="$here/../../hooks/rv-observe.sh"
CONSENT="$here/../../hooks/rv-consent.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hooks fail open without it)"; exit 0; }

rc=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1 — $2"; rc=1; }
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT

REPO="$WS/repo"; SUB="$REPO/app/Models"; mkdir -p "$SUB" "$REPO/.claude/task-runner"
git init -q "$REPO" 2>/dev/null
SENT="$REPO/.claude/task-runner/active-run.json"
printf '{"slug":"t"}' > "$SENT"

# 1) the observer, fired from a subdirectory, records at the ROOT
jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Agent", tool_input:{prompt:"RV-CARD: 05\nreview the diff"}}' \
  | bash "$OBS" >/dev/null 2>&1
[ -f "$REPO/.claude/task-runner/rv/rv-seen-05.json" ] \
  && ok "rv-observe from a subdirectory records at the repo root" \
  || bad "rv-observe from a subdirectory records at the repo root" "no rv-seen-05.json under $REPO/.claude"
[ ! -e "$SUB/.claude" ] && [ ! -e "$REPO/app/.claude" ] \
  && ok "rv-observe creates no .claude/ in the subdirectory" \
  || bad "rv-observe creates no .claude/ in the subdirectory" "found one under $REPO/app"

# 2) the consent ask, fired from a subdirectory, sees the root's registered run
out=$(jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"bash review-skip.sh --card 03 --reason \"ctx pressure\""}}' \
  | bash "$CONSENT" 2>/dev/null)
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1 \
  && ok "rv-consent from a subdirectory asks inside the root's run" \
  || bad "rv-consent from a subdirectory asks inside the root's run" "out=<$out>"

# 2b) what the ask SHOWS. A reason over 200 characters read "no reason given" (the pattern
#     wanted its closing quote inside the interval), and a shell-built id showed as `bg-`.
consent_msg() { # <command> -> the ask's reason text
  jq -cn --arg cwd "$SUB" --arg c "$1" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:$c}}' \
    | bash "$CONSENT" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null
}
r150=$(printf 'r%.0s' $(seq 150)); r250="$(printf 'q%.0s' $(seq 200))$(printf 'z%.0s' $(seq 50))"
msg=$(consent_msg "bash review-skip.sh --card 03 --reason \"$r150\"")
case "$msg" in *"Reason: $r150"$'\n'*) ok "rv-consent shows a 150-char reason whole, no ellipsis" ;;
  *) bad "rv-consent shows a 150-char reason whole, no ellipsis" "msg=<$msg>" ;; esac
msg=$(consent_msg "bash review-skip.sh --card 03 --reason \"$r250\"")
case "$msg" in *"Reason: $(printf 'q%.0s' $(seq 200))…"*) ok "rv-consent shows a 250-char reason cut at 200 with …" ;;
  *) bad "rv-consent shows a 250-char reason cut at 200 with …" "msg=<$msg>" ;; esac
msg=$(consent_msg 'H=$(git rev-parse HEAD); bash review-skip.sh --card "bg-${H:0:12}" --reason "gate is red"')
case "$msg" in *'for card bg-${H:0:12}. Reason: gate is red'*) ok "rv-consent names a shell-built id whole" ;;
  *) bad "rv-consent names a shell-built id whole" "msg=<$msg>" ;; esac
# a REDIRECT into a record named with a shell expansion is a write too; its id class lagged the display's
msg=$(consent_msg 'H=$(git rev-parse HEAD); echo "{}" > .claude/task-runner/rv/rv-skip-bg-${H:0:12}.json')
case "$msg" in *'for card bg-${H:0:12}.'*) ok "rv-consent asks on a redirect into rv-skip-bg-\${H:0:12}.json" ;;
  *) bad "rv-consent asks on a redirect into rv-skip-bg-\${H:0:12}.json" "msg=<$msg>" ;; esac
msg=$(consent_msg 'cat .claude/task-runner/rv/rv-skip-bg-${H:0:12}.json')
[ -z "$msg" ] && ok "rv-consent stays silent on reading that record" || bad "rv-consent stays silent on reading that record" "msg=<$msg>"
# any shell expansion can build the name: a command substitution, a quoted variable, a backtick
for c in 'echo "{}" > .claude/task-runner/rv/rv-skip-bg-$(git rev-parse --short=12 HEAD).json' \
         'echo "{}" > .claude/task-runner/rv/rv-skip-"$H".json' \
         'echo "{}" > .claude/task-runner/rv/rv-skip-`git rev-parse HEAD`.json'; do
  [ -n "$(consent_msg "$c")" ] && ok "rv-consent asks on a redirect into a record named by: ${c#*rv-skip-}" \
    || bad "rv-consent asks on a redirect into a record named by: ${c#*rv-skip-}" "silent"
done
# ...and one whose expansion holds a pipe, which read as the end of the redirect (2026-10-15)
for c in 'echo "{}" > .claude/task-runner/rv/rv-skip-bg-$(git rev-parse HEAD | cut -c1-12).json' \
         'echo "{}" > ".claude/task-runner/rv/rv-skip-`git rev-parse HEAD | cut -c1-12`.json"'; do
  [ -n "$(consent_msg "$c")" ] && ok "rv-consent asks on a redirect into a record named by a piped expansion: ${c#*rv-skip-}" \
    || bad "rv-consent asks on a redirect into a record named by a piped expansion: ${c#*rv-skip-}" "silent"
done
c='echo "$(wc -l < /tmp/a)" > /tmp/n; ls .claude/task-runner/rv/rv-skip-*.json'
[ -z "$(consent_msg "$c")" ] && ok "rv-consent stays silent on a read after a redirect fed by an expansion" \
  || bad "rv-consent stays silent on a read after a redirect fed by an expansion" "asked"
msg=$(consent_msg 'cat .claude/task-runner/rv/rv-skip-07.json > /tmp/x')
[ -z "$msg" ] && ok "rv-consent stays silent on copying a record out" || bad "rv-consent stays silent on copying a record out" "msg=<$msg>"
# an earlier redirect is not the record's: the path before the name stops at a separator too
for c in 'mkdir -p out 2>/dev/null; ls .claude/task-runner/rv/rv-skip-*.json' \
         'git status > /tmp/st && jq -r .reason .claude/task-runner/rv/rv-skip-*.json'; do
  [ -z "$(consent_msg "$c")" ] && ok "rv-consent stays silent on a read after another redirect: $c" \
    || bad "rv-consent stays silent on a read after another redirect: $c" "asked"
done

# 2c) the reviewer's type per card, so candor can ask for ui-ux-reviewer on a UI card by name,
#     and the run-close range review's RV-RANGE marker, which arrives through a Skill call.
RVD="$REPO/.claude/task-runner/rv"
jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Agent", tool_input:{subagent_type:"ui-ux:ui-ux-reviewer", prompt:"RV-CARD: 07\nreview"}}' \
  | bash "$OBS" >/dev/null 2>&1
[ -f "$RVD/rv-agent-07@ui-ux.ui-ux-reviewer.json" ] && [ -f "$RVD/rv-seen-07.json" ] \
  && ok "rv-observe records the reviewer type beside the card count" \
  || bad "rv-observe records the reviewer type beside the card count" "$(ls "$RVD" 2>/dev/null | tr '\n' ' ')"
jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Agent", tool_input:{subagent_type:"x:../../evil", prompt:"RV-CARD: 08"}}' \
  | bash "$OBS" >/dev/null 2>&1
[ -f "$RVD/rv-seen-08.json" ] && [ -z "$(find "$REPO" -name '*evil*' 2>/dev/null)" ] \
  && ok "rv-observe drops a reviewer type carrying path characters, keeps the card record" \
  || bad "rv-observe drops a reviewer type carrying path characters, keeps the card record" "$(find "$REPO" -name '*evil*')"
jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Skill", tool_input:{skill:"code-review:review", args:"0123abc..HEAD RV-RANGE: 4567def89abc"}}' \
  | bash "$OBS" >/dev/null 2>&1
[ -f "$RVD/range-4567def89abc.json" ] \
  && ok "rv-observe records RV-RANGE from a Skill call" \
  || bad "rv-observe records RV-RANGE from a Skill call" "$(ls "$RVD" | tr '\n' ' ')"
jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Skill", tool_input:{skill:"code-review:review", args:"RV-RANGE: <HEAD12>"}}' \
  | bash "$OBS" >/dev/null 2>&1
[ -z "$(find "$RVD" -name 'range-*' ! -name 'range-4567def89abc.json')" ] \
  && ok "an unfilled RV-RANGE placeholder records nothing" \
  || bad "an unfilled RV-RANGE placeholder records nothing" "$(ls "$RVD" | tr '\n' ' ')"
grep -q '"matcher": "Agent|Task|Skill"' "$here/../../hooks/hooks.json" \
  && ok "hooks.json routes Skill calls to rv-observe" || bad "hooks.json routes Skill calls to rv-observe" "matcher lacks Skill"

# 2d) a closing run: the sentinel renamed to closed-run.json until candor's last read. A review
#     its block asks for must still be recorded, and a skip must still ask.
CLOSED="$REPO/.claude/task-runner/closed-run.json"; mv "$SENT" "$CLOSED"
jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Skill", tool_input:{skill:"code-review:review", args:"RV-RANGE: 89abcdef0123"}}' \
  | bash "$OBS" >/dev/null 2>&1
[ -f "$RVD/range-89abcdef0123.json" ] && ok "rv-observe records inside a closing run" || bad "rv-observe records inside a closing run" "no range record"
out=$(jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"bash review-skip.sh --card range-89abcdef0123 --reason \"x\""}}' \
  | bash "$CONSENT" 2>/dev/null)
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1 \
  && ok "rv-consent asks inside a closing run" || bad "rv-consent asks inside a closing run" "out=<$out>"
mv "$CLOSED" "$SENT"

# 3) no registered run → both silent, nothing written
rm -f "$SENT"
jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Agent", tool_input:{prompt:"RV-CARD: 06"}}' \
  | bash "$OBS" >/dev/null 2>&1
[ ! -e "$REPO/.claude/task-runner/rv/rv-seen-06.json" ] \
  && ok "rv-observe records nothing outside a registered run" \
  || bad "rv-observe records nothing outside a registered run" "rv-seen-06.json written"
out=$(jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"bash review-skip.sh --card 03 --reason \"x\""}}' \
  | bash "$CONSENT" 2>/dev/null)
[ -z "$out" ] && ok "rv-consent silent outside a registered run" || bad "rv-consent silent outside a registered run" "out=<$out>"

# 4) fail-open on a cwd that no longer exists
for h in "$OBS" "$CONSENT"; do
  printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"x"}}' "$WS/gone" | bash "$h" >/dev/null 2>&1
  [ $? = 0 ] && ok "$(basename "$h") exits 0 on a deleted cwd" || bad "$(basename "$h") exits 0 on a deleted cwd" "non-zero"
done
[ ! -e "$WS/gone" ] && ok "a deleted cwd is not recreated" || bad "a deleted cwd is not recreated" "$WS/gone exists"

exit $rc
