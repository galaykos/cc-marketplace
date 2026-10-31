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

# 3c) env-notes.md: seeded once with the .env rule, then the run's own, kept across registrations
grep -q 'Never read, grep or print `.env`' "$TR/env-notes.md" 2>/dev/null \
  && ok "seeds env-notes.md with the never-read-.env rule" || bad "seeds env-notes.md" "$(cat "$TR/env-notes.md" 2>&1)"
printf -- '- host node: /opt/node/bin\n' >> "$TR/env-notes.md"
(cd "$REPO" && bash "$RR" --index "$IDX" --fresh >/dev/null 2>&1)
grep -q 'host node' "$TR/env-notes.md" && ok "a fresh registration keeps the notes a run added" || bad "env-notes kept" "$(cat "$TR/env-notes.md")"

# 3d) a tag with the branch's name made --abbrev-ref record `heads/feature`, so every reader that
# asks git for the branch name read the run as another branch's
git -C "$REPO" tag feature
(cd "$REPO" && bash "$RR" --index "$IDX" --fresh >/dev/null 2>&1)
[ "$(jq -r .branch "$SENT")" = feature ] && ok "a tag named like the branch: the sentinel still names branch feature" \
  || bad "a tag named like the branch: the sentinel still names branch feature" "branch=$(jq -r .branch "$SENT")"
git -C "$REPO" tag -d feature >/dev/null
# 3e) symbolic-ref failing with an exit other than 1 (dubious ownership, a broken git env) is not a
# detached head: recording `HEAD` there made every reader stand the run down once git worked again.
SHIM="$WS/shim"; mkdir -p "$SHIM"
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = symbolic-ref ] && exit 128; done\nexec %s "$@"\n' "$(command -v git)" > "$SHIM/git"; chmod +x "$SHIM/git"
(cd "$REPO" && PATH="$SHIM:$PATH" bash "$RR" --index "$IDX" --fresh >/dev/null 2>&1)
[ "$(jq -r .branch "$SENT")" = "" ] && ok "symbolic-ref exiting 128: the sentinel names no branch" \
  || bad "symbolic-ref exiting 128: the sentinel names no branch" "branch=$(jq -r .branch "$SENT")"
git -C "$REPO" checkout -q --detach
(cd "$REPO" && bash "$RR" --index "$IDX" --fresh >/dev/null 2>&1)
[ "$(jq -r .branch "$SENT")" = HEAD ] && ok "a detached head is recorded as HEAD" || bad "a detached head is recorded as HEAD" "branch=$(jq -r .branch "$SENT")"
git -C "$REPO" checkout -q feature
(cd "$REPO" && bash "$RR" --index "$IDX" --fresh >/dev/null 2>&1)

# 3f) an installed copy sits at <cache>/<marketplace>/<plugin>/<version>/, where the dev-tree sibling
# never exists, and `find | sort -V` over full paths sorts by marketplace name first (2026-10-31).
CACHE="$HOME/.claude/plugins/cache"; INST="$CACHE/cc-plugins-marketplace/task-runner/0.49.10/scripts"
mkdir -p "$INST" "$CACHE/lonely/task-runner/1.0.0/scripts"
cp "$RR" "$INST/register-run.sh"; cp "$RR" "$CACHE/lonely/task-runner/1.0.0/scripts/register-run.sh"
for v in zz-other/taskmaster/9.9.9 cc-plugins-marketplace/taskmaster/0.50.6 cc-plugins-marketplace/taskmaster/0.50.10; do
  mkdir -p "$CACHE/$v/scripts"; printf '#!/bin/sh\necho %s > "%s"\n' "$v" "$WS/picked" > "$CACHE/$v/scripts/phase-sentinel.sh"
done
NOCLI=$(printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r d; do [ -x "$d/claude" ] || printf '%s:' "$d"; done); NOCLI=${NOCLI%:}
pick() { rm -f "$WS/picked"; (cd "$REPO" && PATH="$1" bash "$2" --index "$IDX" --fresh >/dev/null 2>"$WS/err"); cat "$WS/picked" 2>/dev/null; }
if PATH="$NOCLI" command -v claude >/dev/null 2>&1; then bad "installed copy, no CLI" "claude still on the filtered PATH"
else
  got=$(pick "$NOCLI" "$INST/register-run.sh")
  [ "$got" = cc-plugins-marketplace/taskmaster/0.50.10 ] && ok "installed, no CLI: runs its own marketplace's newest taskmaster, not another marketplace's" \
    || bad "installed, no CLI: runs its own marketplace's newest taskmaster" "picked=<$got>"
  got=$(pick "$NOCLI" "$CACHE/lonely/task-runner/1.0.0/scripts/register-run.sh")
  [ "$got" = zz-other/taskmaster/9.9.9 ] && grep -q 'may not be the copy' "$WS/err" \
    && ok "no taskmaster in its own marketplace: the cache-wide copy runs and stderr says it may not be the loaded one" \
    || bad "cache-wide fallback says so on stderr" "picked=<$got> err=<$(cat "$WS/err")>"
fi
STUB="$WS/stub"; mkdir -p "$STUB"
jq -n --arg z "$CACHE/zz-other/taskmaster/9.9.9" --arg c "$CACHE/cc-plugins-marketplace/taskmaster/0.50.6" '[
  {id:"taskmaster@zz-other",enabled:true,scope:"project",projectPath:"/elsewhere",installPath:$z},
  {id:"taskmaster@zz-other",enabled:false,scope:"user",installPath:$z},
  {id:"taskmaster@cc-plugins-marketplace",enabled:true,scope:"user",installPath:$c}]' > "$WS/list.json"
printf '#!/bin/sh\n[ "$*" = "plugin list --json" ] && cat "%s"\n' "$WS/list.json" > "$STUB/claude"; chmod +x "$STUB/claude"
got=$(pick "$STUB:$NOCLI" "$INST/register-run.sh")
[ "$got" = cc-plugins-marketplace/taskmaster/0.50.6 ] && ok "installed, with the CLI: runs the enabled install's installPath, not the newest on disk or another project's" \
  || bad "installed, with the CLI: runs the enabled install's installPath" "picked=<$got>"

# 4) refusals
(cd "$REPO" && bash "$RR" --index nope/00-INDEX.md >/dev/null 2>&1); r=$?
[ "$r" = 3 ] && ok "an index that does not exist is a usage error (3)" || bad "missing index" "rc=$r"
mkdir -p "$WS/plain"; (cd "$WS/plain" && bash "$RR" >/dev/null 2>&1); r=$?
[ "$r" = 5 ] && ok "outside a git work tree exits 5" || bad "outside git" "rc=$r"

exit $rc
