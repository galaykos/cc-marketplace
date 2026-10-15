#!/usr/bin/env bash
# Tests for scripts/register-run.sh, and the pin that every entry route calls it.
#
# Why: registration was prose in /task-runner:run step 1 only. A handoff that invoked the
# task-execution skill directly ran unregistered, so the review observer, candor's completion
# clause and the closing gate were all silently off (session retro 2026-10-13, V-19).
set -u
unset CLAUDE_PROJECT_DIR

here=$(cd "$(dirname "$0")" && pwd)
PLUGIN=$(cd "$here/../.." && pwd)
RR="$PLUGIN/scripts/register-run.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit 0; }

rc=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1 — $2"; rc=1; }
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
export HOME="$WS/home"; mkdir -p "$HOME"   # the installed-copy fallback must not find the runner's own cache

# The pin: each route a run can start from names the script. A route that registers in prose
# instead is the gap V-19 measured.
for f in commands/run.md commands/plan.md skills/task-execution/SKILL.md; do
  grep -q 'scripts/register-run\.sh' "$PLUGIN/$f" \
    && ok "$f calls scripts/register-run.sh" || bad "$f calls scripts/register-run.sh" "no call found"
done
grep -qE '^## Step 1: register the run' "$PLUGIN/skills/task-execution/SKILL.md" \
  && ok "the task-execution skill's step 1 is the registration" || bad "the task-execution skill's step 1 is the registration" "no such heading"
# --tracks registers on the run branch: registered on main first, the sentinel named main, and on
# the run branch the spawn cap asked at #20 and candor's clause stood down (2026-10-15).
awk '/^\*\*`--tracks/,/^$/' "$PLUGIN/commands/run.md" | tr '\n' ' ' | grep -qE 'establish the run branch first.*register-run\.sh' \
  && ok "run.md --tracks establishes the run branch before registering" \
  || bad "run.md --tracks establishes the run branch before registering" "the paragraph registers first, or names no run branch"

REPO="$WS/repo"; mkdir -p "$REPO/app/Models" "$REPO/taskmaster-docs/tasks/2026-01-01-demo"
git -C "$REPO" init -q -b main && git -C "$REPO" config user.email t@t.t && git -C "$REPO" config user.name t
echo a > "$REPO/a.txt"; git -C "$REPO" add -A && git -C "$REPO" commit -qm init
git -C "$REPO" checkout -q -b feature; echo b >> "$REPO/a.txt"; git -C "$REPO" commit -qam two
HEAD=$(git -C "$REPO" rev-parse HEAD); BASE=$(git -C "$REPO" rev-parse main)
IDX="$REPO/taskmaster-docs/tasks/2026-01-01-demo/00-INDEX.md"; echo '| 01 | x | pending |' > "$IDX"
TR="$REPO/.claude/task-runner"; SENT="$TR/active-run.json"
mkdir -p "$TR/bg"
printf '{"head":"%s"}' "$HEAD" > "$TR/gate-pass.json"
printf '{}' > "$TR/bg/bg-$HEAD.json"; printf '{}' > "$TR/closed-run.json"

# 1) fresh, from a subdirectory with a cwd-relative index path
out=$(cd "$REPO/app/Models" && bash "$RR" --index ../../taskmaster-docs/tasks/2026-01-01-demo/00-INDEX.md --session s-1 2>&1); r=$?
[ "$r" = 0 ] && ok "registers (exit 0)" || bad "registers (exit 0)" "rc=$r out=<$out>"
got=$(jq -c '[.slug,.base,.branch,.start_sha,.index_path]' "$SENT" 2>/dev/null)
want=$(jq -cn --arg b "$BASE" --arg h "$HEAD" '["2026-01-01-demo",$b,"feature",$h,"taskmaster-docs/tasks/2026-01-01-demo/00-INDEX.md"]')
[ "$got" = "$want" ] && ok "active-run.json carries slug, merge-base, branch, start_sha and a root-relative index_path" \
  || bad "active-run.json fields" "got=$got want=$want"
[ ! -e "$TR/gate-pass.json" ] && [ ! -e "$TR/bg/bg-$HEAD.json" ] && [ ! -e "$TR/closed-run.json" ] \
  && ok "stale gate-pass, bg-<HEAD> and closed-run records are deleted" || bad "stale records deleted" "$(ls -R "$TR")"
for d in rv rt bg nc reductions; do [ -d "$TR/$d" ] || bad "creates $d/" "missing"; done
[ "$(cat "$TR/.gitignore" 2>/dev/null)" = '*' ] && ok "creates the record dirs and a self-ignoring .gitignore" || bad ".gitignore" "missing"
[ ! -e "$REPO/app/Models/.claude" ] && ok "writes nothing under the shell's subdirectory" || bad "subdir state" "found .claude"
ph=$(jq -c '[.phase,.owner,.session_id]' "$REPO/.claude/cc-phase.json" 2>/dev/null)
[ "$ph" = '["build","task-runner:run","s-1"]' ] && ok "writes the build phase sentinel for this session" || bad "phase sentinel" "got=$ph"

# 2) resume: the same index on the same branch keeps the registration (its mtime is the record cutoff)
REF="$WS/ref"; touch -t 200101010000 "$REF"; touch -t 200001010000 "$SENT"; before=$(cat "$SENT"); printf '{"head":"%s"}' "$HEAD" > "$TR/gate-pass.json"
out=$(cd "$REPO" && bash "$RR" --index "$IDX" --session s-2 2>/dev/null)
[ "$(cat "$SENT")" = "$before" ] && [ -z "$(find "$SENT" -newer "$REF")" ] && [ -e "$TR/gate-pass.json" ] \
  && ok "a second call for the same run resumes it untouched" || bad "resume" "out=<$out>"
case "$out" in resumed*) ok "says it resumed" ;; *) bad "says it resumed" "out=<$out>" ;; esac
[ "$(jq -r .session_id "$REPO/.claude/cc-phase.json")" = s-2 ] && ok "a resume re-claims the phase sentinel for the new session" \
  || bad "resume phase sentinel" "$(cat "$REPO/.claude/cc-phase.json")"

# 3) --fresh, and a different list, both register anew
(cd "$REPO" && bash "$RR" --index "$IDX" --fresh >/dev/null 2>&1)
[ -n "$(find "$SENT" -newer "$REF")" ] && [ ! -e "$TR/gate-pass.json" ] && ok "--fresh registers anew" || bad "--fresh" "sentinel not rewritten"
touch -t 200001010000 "$SENT"
(cd "$REPO" && bash "$RR" --slug inline-fixes >/dev/null 2>&1)
[ "$(jq -r '.slug + "|" + (.index_path // "none")' "$SENT")" = "inline-fixes|none" ] && ok "another list (an inline one) registers anew, without index_path" \
  || bad "inline list" "$(cat "$SENT")"

# 3b) an inline run never resumes: two flagless calls share the default slug `run`, and a match
# would hand the second run the first one's card records
for args in "" "--slug inline-fixes"; do
  (cd "$REPO" && bash "$RR" $args >/dev/null 2>&1); touch -t 200001010000 "$SENT"
  out=$(cd "$REPO" && bash "$RR" $args 2>/dev/null)
  case "$out" in registered*) [ -n "$(find "$SENT" -newer "$REF")" ] && ok "a second inline call (${args:-no flags}) registers anew" \
      || bad "inline re-register (${args:-no flags})" "sentinel not rewritten" ;;
    *) bad "inline re-register (${args:-no flags})" "out=<$out>" ;; esac
done

# 4) refusals
(cd "$REPO" && bash "$RR" --index nope/00-INDEX.md >/dev/null 2>&1); r=$?
[ "$r" = 3 ] && ok "an index that does not exist is a usage error (3)" || bad "missing index" "rc=$r"
mkdir -p "$WS/plain"; (cd "$WS/plain" && bash "$RR" >/dev/null 2>&1); r=$?
[ "$r" = 5 ] && ok "outside a git work tree exits 5" || bad "outside git" "rc=$r"

exit $rc
