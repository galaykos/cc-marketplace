#!/usr/bin/env bash
# Fixtures for plugins/code-review/hooks/review-debt.sh — the advisory review-debt nudge.
#
# One temp git repo, one scenario run in order, because the hook's whole contract is a
# SEQUENCE: a first prompt that only records a base, a diff that grows commit by commit, a
# review that moves the base, a HEAD that must not be nudged twice. Every payload carries
# transcript_path, the key the hook actually uses (pc_harness_payload).
#
# WHAT THIS DOES NOT CATCH: whether the host really delivers `.tool_input.subagent_type` /
# `.tool_input.skill` under those names on PostToolUse, and whether a typed slash command
# reaches UserPromptSubmit as `/name args`. Both shapes are copied from sibling hooks in
# this marketplace (candor/hooks/avert.sh, taskmaster/hooks/ultra.sh), not re-measured here.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
H="$PWD/plugins/code-review/hooks/review-debt.sh"
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

# This session exports CLAUDE_PROJECT_DIR (the marketplace repo); a user's own git config
# may sign commits or install hooks. Neither belongs in a fixture.
unset CLAUDE_PROJECT_DIR CC_REMIND CC_REVIEW_NUDGE
export HOME="$FX/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"
g() { git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }

R="$FX/repo"
mkdir -p "$R"
g init -q
printf 'readme\n' > "$R/README.md"
g add -A && g commit -qm init

TP1='/Users/x/.claude/projects/-Users-x-proj/11111111-aaaa.jsonl'
TP2='/Users/x/.claude/projects/-Users-x-proj/22222222-bbbb.jsonl'
TP3='/Users/x/.claude/projects/-Users-x-proj/33333333-cccc.jsonl'

say() { # cwd prompt transcript -> additionalContext ('' when silent)
  jq -nc --arg c "$1" --arg p "$2" --arg t "$3" \
    '{hook_event_name:"UserPromptSubmit",session_id:"sid-1",transcript_path:$t,cwd:$c,prompt:$p}' \
    | bash "$H" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
prompt() { say "$R" "proceed next recommended" "$TP1"; }
agent() { # subagent_type
  jq -nc --arg c "$R" --arg a "$1" --arg t "$TP1" \
    '{hook_event_name:"PostToolUse",tool_name:"Agent",session_id:"sid-1",transcript_path:$t,cwd:$c,
      tool_input:{subagent_type:$a,description:"x",prompt:"x"},tool_response:{}}' | bash "$H" >/dev/null 2>&1
}
skill() { # skill name
  jq -nc --arg c "$R" --arg s "$1" --arg t "$TP1" \
    '{hook_event_name:"PostToolUse",tool_name:"Skill",session_id:"sid-1",transcript_path:$t,cwd:$c,
      tool_input:{skill:$s},tool_response:{}}' | bash "$H" >/dev/null 2>&1
}
commit() { # msg path... — writes fresh content to each path, commits
  local m="$1" f; shift
  for f in "$@"; do mkdir -p "$R/$(dirname "$f")"; printf '%s %s\n' "$f" "$RANDOM$RANDOM" >> "$R/$f"; done
  g add -A && g commit -qm "$m"
}
silent() { # label output
  if [ -z "$2" ]; then echo "PASS: $1 (silent)"; else echo "FAIL: $1 — fired: $2"; rc=1; fi
}
fires() { # label output needle...
  local l="$1" o="$2" n; shift 2
  [ -n "$o" ] || { echo "FAIL: $l — silent"; rc=1; return; }
  for n in "$@"; do
    printf '%s' "$o" | grep -qF -- "$n" || { echo "FAIL: $l — missing '$n' in: $o"; rc=1; return; }
  done
  echo "PASS: $l"
}
base_of() { cat "$R/.claude/code-review/review-base-$(printf '%s' "$1" | cksum | cut -d' ' -f1)" 2>/dev/null; }

# ---- first prompt: record a base, say nothing --------------------------------------
silent "first prompt" "$(prompt)"
[ "$(base_of "$TP1")" = "$(g rev-parse HEAD)" ] \
  && echo "PASS: first prompt recorded HEAD as the base" \
  || { echo "FAIL: first prompt did not record HEAD as the base"; rc=1; }

# ---- 9 committed code files: nudge once, then not again at the same HEAD -----------
commit "nine" src/f1.ts src/f2.ts src/f3.ts src/f4.ts src/f5.ts src/f6.ts src/f7.ts src/f8.ts src/f9.ts
base1=$(base_of "$TP1"); short1=$(g rev-parse --short "$base1")
out=$(prompt)
fires "9 committed code files nudge" "$out" "9 changed files have had no review in this session since $short1" \
  "/code-review:review $short1..HEAD" "or say in one line why not" "CC_REVIEW_NUDGE=off"
printf '%s' "$out" | grep -q 'auth-surface' && { echo "FAIL: no auth path, yet an auth-surface clause"; rc=1; }
[ "$(printf '%s' "$out" | wc -l | tr -d ' ')" = "0" ] \
  && echo "PASS: the nudge is one line" || { echo "FAIL: the nudge spans lines: $out"; rc=1; }
printf '%s\n' "$out" > "$FX/nudge-count.txt"
silent "same HEAD, second prompt" "$(prompt)"

# ---- HEAD moves but the count does not grow: silent ---------------------------------
commit "touch one again" src/f1.ts
silent "new HEAD, same 9 files" "$(prompt)"

# ---- a non-reviewer agent does not move the base; growth past what fired re-fires ---
agent Explore
commit "tenth" src/f10.ts
fires "Explore is not a review; 10 > 9 re-fires" "$(prompt)" "10 changed files have had no review in this session since $short1"

# ---- a reviewer dispatch moves the base ---------------------------------------------
agent code-review:code-reviewer
[ "$(base_of "$TP1")" = "$(g rev-parse HEAD)" ] \
  && echo "PASS: reviewer Agent payload moved the base to HEAD" \
  || { echo "FAIL: reviewer Agent payload did not move the base"; rc=1; }
silent "prompt right after a review" "$(prompt)"
commit "one more" src/g1.ts
silent "one ordinary file after a review" "$(prompt)"

# ---- one auth-surface file is enough (after a `*reviewer` dispatch zeroes the count) --
agent web-dev:frontend-reviewer
commit "policy" app/Policies/PostPolicy.php
out=$(prompt)
fires "one changed file under app/Policies/ nudges" "$out" "1 changed file has had no review" \
  "auth-surface: app/Policies/PostPolicy.php"
printf '%s\n' "$out" > "$FX/nudge-auth.txt"

# ---- a Skill review moves the base; `author` is not `auth` ----------------------------
skill code-review:review
commit "author" app/Http/Controllers/AuthorController.php
silent "Skill code-review:review moved the base; AuthorController is not auth" "$(prompt)"

# ---- the user typing the review command moves the base too --------------------------
silent "typed /code-review:review" "$(say "$R" "/code-review:review src/" "$TP1")"
[ "$(base_of "$TP1")" = "$(g rev-parse HEAD)" ] \
  && echo "PASS: typed /code-review:review moved the base" \
  || { echo "FAIL: typed /code-review:review did not move the base"; rc=1; }

# ---- docs, lockfiles, taskmaster-docs, .claude, vendor: not code to review -----------
commit "docs" docs/a.md docs/b.md docs/c.md docs/d.md docs/e.md docs/f.md docs/g.md docs/h.md \
  composer.lock package-lock.json taskmaster-docs/spec/token.txt .claude/settings.json vendor/pkg/Auth.php
silent "docs-only change (8 .md + lockfiles + tooling dirs)" "$(prompt)"

# ---- under an active task-runner run: silent, and the run's diff is not charged later
mkdir -p "$R/.claude/task-runner" && printf '{}\n' > "$R/.claude/task-runner/active-run.json"
commit "run work" run/a.ts run/b.ts run/c.ts run/d.ts run/e.ts run/f.ts run/g.ts run/h.ts app/Http/Middleware/Tenant.php
silent "active-run.json present" "$(prompt)"
rm -f "$R/.claude/task-runner/active-run.json"
commit "after the run" src/after.ts
silent "first prompt after the run does not charge the run's 9 files" "$(prompt)"

# ---- off switches ---------------------------------------------------------------------
commit "impersonation" app/Http/Middleware/Impersonate.php
o=$(jq -nc --arg c "$R" --arg t "$TP1" \
      '{hook_event_name:"UserPromptSubmit",session_id:"sid-1",transcript_path:$t,cwd:$c,prompt:"go"}' \
    | CC_REVIEW_NUDGE=off bash "$H" 2>/dev/null)
silent "CC_REVIEW_NUDGE=off" "$o"
o=$(jq -nc --arg c "$R" --arg t "$TP1" \
      '{hook_event_name:"UserPromptSubmit",session_id:"sid-1",transcript_path:$t,cwd:$c,prompt:"go"}' \
    | CC_REMIND=off bash "$H" 2>/dev/null)
silent "CC_REMIND=off" "$o"
fires "the same state with the switches unset still nudges" "$(prompt)" "Impersonate.php"

# ---- subdirectory cwd: state at the repo root, one context across `cd` ----------------
commit "dirs" app/Enums/Status.php app/Models/User.php
silent "first prompt of a second context, cwd app/Enums" "$(say "$R/app/Enums" go "$TP2")"
[ -n "$(base_of "$TP2")" ] && echo "PASS: subdirectory cwd — state landed at the repo root" \
  || { echo "FAIL: subdirectory cwd — no state at the repo root"; rc=1; }
[ -e "$R/app/Enums/.claude" ] && { echo "FAIL: subdirectory cwd — a .claude/ appeared in app/Enums"; rc=1; } \
  || echo "PASS: subdirectory cwd — no .claude/ in the subdirectory"
commit "guard" app/Auth/TenantGuard.php
fires "cwd app/Models sees the same context's base" "$(say "$R/app/Models" go "$TP2")" "TenantGuard.php"
silent "cwd at the root, same HEAD: already judged" "$(say "$R" go "$TP2")"
[ -e "$R/app/Models/.claude" ] && { echo "FAIL: a .claude/ appeared in app/Models"; rc=1; }

# ---- a base that left HEAD's history (branch switch) resets instead of diffing across -
silent "first prompt of a third context" "$(say "$R" go "$TP3")"
g checkout -q -b side HEAD~6
commit "side work" app/Auth/SideGuard.php
silent "base no longer an ancestor of HEAD" "$(say "$R" go "$TP3")"
[ "$(base_of "$TP3")" = "$(g rev-parse HEAD)" ] \
  && echo "PASS: the orphaned base was reset to HEAD" \
  || { echo "FAIL: the orphaned base was not reset"; rc=1; }

# ---- outside git: silent, and no state written -----------------------------------------
mkdir -p "$FX/plain"
silent "outside a git repo" "$(say "$FX/plain" go "$TP1")"
[ -e "$FX/plain/.claude" ] && { echo "FAIL: outside git — a .claude/ was created"; rc=1; } \
  || echo "PASS: outside git — nothing written"

# ---- fail-open ----------------------------------------------------------------------------
if o=$(printf 'not json' | bash "$H" 2>/dev/null) && [ -z "$o" ]; then
  echo "PASS: garbage input exits 0 with no output"
else echo "FAIL: garbage input did not fail open"; rc=1; fi

echo
echo "nudge (count):  $(cat "$FX/nudge-count.txt")"
echo "nudge (auth):   $(cat "$FX/nudge-auth.txt")"
[ "$rc" -eq 0 ] && echo "review-debt.test: all cases passed" || echo "review-debt.test: FAILURES above"
exit "$rc"
