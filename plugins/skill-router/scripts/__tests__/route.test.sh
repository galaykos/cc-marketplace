#!/usr/bin/env bash
# Author-time tests for hooks/route.sh — the PostToolUse file router — and for the
# state-root contract it shares with route-prompt.sh (flush) and summary.sh (ledger).
#
# Drives the hooks with host-shaped payloads (tool_name, session_id, transcript_path,
# cwd, tool_input) against temp GIT repos, because both halves of 0.20.0 depend on one:
# a Bash write routes only under the project root, and the project root is the git
# toplevel (rationale/2026-09-25-session-plugin-usage-review.md, findings 1 and 2).
# Every Bash case RUNS its command first, in the payload cwd — PostToolUse fires after
# the tool, and the hook reads the file the command left on disk.
#
# Asserts: a heredoc write routes the same skills an Edit of that file does, and its
# content signal reaches pending_low; a Bash call with no write target, with a target
# that is missing afterwards, or with a target outside the root is silent and creates
# no state; a payload cwd in a subdirectory keeps state at the repo root, leaves no
# `.claude/` in the subdirectory, and still matches `**/app/**` and reads the root's
# manifest; directory globs match the ROOT-relative path; the per-signal one-shot holds
# across an Edit then a Bash write; one envelope per call; the 8-target cap; CC_REMIND.
set -u
# This session exports it, pointing at the marketplace repo; cc_state_root honours it
# outside git, so a stray value would make a fixture look like part of this repo.
unset CLAUDE_PROJECT_DIR
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SR="$ROOT/plugins/skill-router"
HOOK="$SR/hooks/route.sh"
command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available (the state root is the git toplevel)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
NONZERO="$WS/nonzero"
ok()  { pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }

mkrepo() { # $1 dir — a Laravel-shaped git repo
  mkdir -p "$1/app/Http/Controllers" "$1/app/Enums" "$1/app/Models"
  git -C "$1" init -q
  printf '{"require":{"laravel/framework":"^11.0"}}\n' > "$1/composer.json"
}
hook() { # $1 hook path, stdin payload, [env...] after — records a non-zero exit
  local h="$1"; shift
  env CLAUDE_PLUGIN_ROOT="$SR" "$@" bash "$h" 2>/dev/null
  local rc=$?; [ "$rc" -eq 0 ] || echo "$h rc=$rc" >> "$NONZERO"
}
edit() { # cwd file transcript [env...]
  local c="$1" f="$2" t="$3"; shift 3
  jq -cn --arg c "$c" --arg f "$f" --arg tp "$t" \
    '{hook_event_name:"PostToolUse",tool_name:"Edit",session_id:"sess",transcript_path:$tp,cwd:$c,
      tool_input:{file_path:$f,old_string:"a",new_string:"b"},tool_response:{filePath:$f,success:true}}' \
    | hook "$HOOK" "$@"
}
bashw() { # cwd command transcript [env...] — runs the command, then the hook
  local c="$1" cmd="$2" t="$3"; shift 3
  (cd "$c" && bash -c "$cmd") >/dev/null 2>&1
  jq -cn --arg c "$c" --arg cmd "$cmd" --arg tp "$t" \
    '{hook_event_name:"PostToolUse",tool_name:"Bash",session_id:"sess",transcript_path:$tp,cwd:$c,
      tool_input:{command:$cmd,description:"write"},tool_response:{stdout:"",stderr:"",interrupted:false}}' \
    | hook "$HOOK" "$@"
}
skills()  { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null | grep -oE 'load the `[^`]+`' | sed 's/^load the `//; s/`$//' | sort -u; }
ctxof()   { printf '%s' "$1" | cksum | cut -d' ' -f1; }
statef()  { printf '%s/.claude/skill-router/fired-%s.json' "$1" "$(ctxof "$2")"; }
has_skill() { skills <<<"$1" | grep -qxF "$2"; }

CTRL='app/Http/Controllers/UserController.php'
HEREDOC="cat > $CTRL <<'PHP'
<?php
namespace App\\Http\\Controllers;
class UserController {
    public function show() { return \$this->user->token; }   // '->' and '=>' must not read as redirects
    private array \$map = ['a' => 1];
}
PHP"

# 1. a Bash heredoc routes exactly what an Edit of the same file routes
A="$WS/a"; mkrepo "$A"
out_b=$(bashw "$A" "$HEREDOC" "$WS/t-a-bash.jsonl")
[ -f "$A/$CTRL" ] || bad "fixture: heredoc did not create $CTRL"
out_e=$(edit "$A" "$A/$CTRL" "$WS/t-a-edit.jsonl")
has_skill "$out_b" laravel-best-practices && ok || bad "bash heredoc: laravel-best-practices not routed; got: ${out_b:0:200}"
sb=$(skills <<<"$out_b"); se=$(skills <<<"$out_e")
[ -n "$se" ] && [ "$sb" = "$se" ] && ok || bad "bash vs edit: skill sets differ — bash [$(echo $sb)] edit [$(echo $se)]"
[ "$(printf '%s\n' "$out_b" | grep -c .)" = 1 ] && printf '%s' "$out_b" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1 \
  && ok || bad "bash heredoc: not exactly one PostToolUse envelope: ${out_b:0:200}"
sf=$(statef "$A" "$WS/t-a-bash.jsonl")
jq -e --arg f "$A/$CTRL" '.pending_low | any(.skill == "security-review" and .file == $f)' "$sf" >/dev/null 2>&1 \
  && ok || bad "bash heredoc: content signal (token → security-review) not in pending_low of $sf"

# 2. Bash with no write target → silent, no state
B="$WS/b"; mkrepo "$B"
for cmd in 'git status' 'ls app > /dev/null 2>&1' 'echo hi 2>&1' 'grep -rn foo app | head -3'; do
  out=$(bashw "$B" "$cmd" "$WS/t-b.jsonl")
  [ -z "$out" ] && ok || bad "no target [$cmd]: expected silence, got: ${out:0:120}"
done
[ ! -e "$B/.claude" ] && ok || bad "no target: state dir created at $B/.claude"

# 3. a target missing afterwards, or outside the root → silent, no state
for cmd in 'echo x > app/Gone.php && rm app/Gone.php' \
           'echo x > nodir/deep/x.php' \
           "echo '<?php' > ../outside-rel.php" \
           "echo '<?php' > $WS/outside-abs.php"; do
  out=$(bashw "$B" "$cmd" "$WS/t-b.jsonl")
  [ -z "$out" ] && ok || bad "missing/outside [$cmd]: expected silence, got: ${out:0:120}"
done
[ -f "$WS/outside-rel.php" ] && [ -f "$WS/outside-abs.php" ] && ok || bad "fixture: outside-root files were not written, so the outside cases proved nothing"
[ ! -e "$B/.claude" ] && ok || bad "missing/outside: state dir created at $B/.claude"

# 4. payload cwd = a subdirectory: state at the repo root, nothing in the subdirectory,
#    `**/app/**` still matches a relative target, and the `?package.json` marker is read
#    at the ROOT (read under app/Enums it would be absent and suppress nextjs).
C="$WS/c"; mkrepo "$C"; printf '{"dependencies":{"next":"15.0.0"}}\n' > "$C/package.json"
TC="$WS/t-c.jsonl"
out=$(bashw "$C/app/Enums" "cat > Status.php <<'PHP'
<?php
enum Status: string { case Active = 'active'; }  // password reset flow
PHP" "$TC")
[ -f "$C/app/Enums/Status.php" ] || bad "fixture: subdir heredoc did not create Status.php"
has_skill "$out" laravel-best-practices && ok || bad "subdir: laravel-best-practices not routed; got: ${out:0:200}"
has_skill "$out" nextjs-best-practices && ok || bad "subdir: **/app/** + root package.json did not route nextjs-best-practices; got: ${out:0:200}"
[ -f "$(statef "$C" "$TC")" ] && ok || bad "subdir: no state file at the repo root"
[ ! -e "$C/app/Enums/.claude" ] && ok || bad "subdir: stray .claude/ created in app/Enums"
mkdir -p "$C/database/migrations"; : > "$C/database/migrations/2026_01_01_create_orders.php"
out=$(edit "$C/app/Models" "$C/database/migrations/2026_01_01_create_orders.php" "$TC")
has_skill "$out" sql-best-practices && ok || bad "subdir edit: sql-best-practices not routed; got: ${out:0:200}"
[ ! -e "$C/app/Models/.claude" ] && ok || bad "subdir edit: stray .claude/ created in app/Models"
jq -e '(.fired | index("laravel-best-practices")) and (.fired | index("sql-best-practices"))' "$(statef "$C" "$TC")" >/dev/null 2>&1 \
  && ok || bad "subdir: one context from two directories did not land in ONE root state file"

# 4b. the three-hook contract survives the drift: route-prompt flushes, from yet another
#     directory, what route.sh wrote from app/Enums; summary.sh finds and removes it and
#     files the ledger under the ROOT's slug.
fl=$(jq -cn --arg c "$C/app/Http" --arg tp "$TC" '{hook_event_name:"UserPromptSubmit",prompt:"ok thanks",session_id:"sess",transcript_path:$tp,cwd:$c}' \
  | hook "$SR/hooks/route-prompt.sh" TMPDIR="$WS")
grep -qF 'Signals from recent edits' <<<"$fl" && grep -qF 'Status.php' <<<"$fl" && ok \
  || bad "flush from another subdir: digest missing; got: ${fl:0:200}"
jq -cn --arg c "$C/app/Enums" --arg tp "$TC" '{hook_event_name:"SessionEnd",session_id:"sess",transcript_path:$tp,cwd:$c}' \
  | hook "$SR/hooks/summary.sh" HOME="$WS/home" >/dev/null
[ ! -e "$(statef "$C" "$TC")" ] && ok || bad "summary from subdir: root state file not removed"
slug=$(printf '%s' "$C" | tr -c '[:alnum:]' '-')
[ -s "$WS/home/.claude/skill-router/$slug/surfaced.jsonl" ] && [ "$(ls "$WS/home/.claude/skill-router" | wc -l | tr -d ' ')" = 1 ] \
  && ok || bad "summary from subdir: ledger not filed under the root slug alone: $(ls "$WS/home/.claude/skill-router" 2>/dev/null)"

# 4c. directory globs match the ROOT-relative path: a checkout that merely lives under a
#     directory named `tests/` must not draw the testing row on every file it edits.
D="$WS/tests/d"; mkdir -p "$D/src"; git -C "$D" init -q; printf 'package d\n' > "$D/src/thing.go"
out=$(edit "$D" "$D/src/thing.go" "$WS/t-d.jsonl")
has_skill "$out" low-cognitive-load && ok || bad "root-relative: *.go did not route at all; got: ${out:0:200}"
has_skill "$out" testing-best-practices && bad "root-relative: **/tests/** matched a directory ABOVE the repo root" || ok

# 5. the one-shot holds across an Edit then a Bash write of the same signal
E="$WS/e"; mkrepo "$E"; TE="$WS/t-e.jsonl"
printf '<?php\n' > "$E/$CTRL"
out=$(edit "$E" "$E/$CTRL" "$TE")
has_skill "$out" laravel-best-practices && ok || bad "one-shot: the Edit did not route laravel; got: ${out:0:200}"
out=$(bashw "$E" "cat > app/Http/Controllers/PostController.php <<'PHP'
<?php
PHP" "$TE")
has_skill "$out" laravel-best-practices && bad "one-shot: the Bash write re-nudged laravel-best-practices" || ok
out=$(bashw "$E" "printf 'select 1;\\n' > app/report.sql" "$TE")
has_skill "$out" sql-best-practices && ok || bad "one-shot: a NEW signal through Bash in the same context did not route; got: ${out:0:200}"

# 6. one command, three files → ONE envelope carrying every skill
F="$WS/f"; mkrepo "$F"
out=$(bashw "$F" "cat > app/Models/Order.php <<'A'
<?php
A
printf 'select 1;\\n' > app/orders.sql; echo 'package f' > app/f.go" "$WS/t-f.jsonl")
[ "$(printf '%s\n' "$out" | grep -c .)" = 1 ] && ok || bad "multi-file: expected one envelope line, got $(printf '%s\n' "$out" | grep -c .)"
for s in laravel-best-practices sql-best-practices low-cognitive-load; do
  has_skill "$out" "$s" && ok || bad "multi-file: $s missing from the envelope"
done

# 7. the cap: the first 8 targets are examined, a 9th is not
G="$WS/g"; mkrepo "$G"
seven='echo a > t1.txt; echo a > t2.txt; echo a > t3.txt; echo a > t4.txt; echo a > t5.txt; echo a > t6.txt; echo a > t7.txt'
out=$(bashw "$G" "$seven; printf 'select 1;\\n' > eighth.sql" "$WS/t-g8.jsonl")
has_skill "$out" sql-best-practices && ok || bad "cap: the 8th target did not route; got: ${out:0:160}"
out=$(bashw "$G" "$seven; echo a > t8.txt; printf 'select 1;\\n' > ninth.sql" "$WS/t-g9.jsonl")
[ -z "$out" ] && ok || bad "cap: a 9th target routed: ${out:0:160}"

# 8. CC_REMIND=off silences the Bash path too
H="$WS/h"; mkrepo "$H"
out=$(bashw "$H" "printf 'select 1;\\n' > q.sql" "$WS/t-h.jsonl" CC_REMIND=off)
[ -z "$out" ] && [ ! -e "$H/.claude" ] && ok || bad "CC_REMIND=off: Bash write still routed: ${out:0:120}"

# 9. every hook call exited 0 (fail-open contract)
[ ! -s "$NONZERO" ] && ok || { bad "non-zero hook exit(s):"; cat "$NONZERO"; }

echo "route: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
