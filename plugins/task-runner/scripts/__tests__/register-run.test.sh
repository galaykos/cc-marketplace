#!/usr/bin/env bash
# Tests for scripts/register-run.sh, and the pin that every entry route calls it.
#
# Why: registration was prose in /task-runner:run step 1 only. A handoff that invoked the
# task-execution skill directly ran unregistered, so the review observer, candor's completion
# clause and the closing gate were all silently off (session retro 2026-10-13, V-19).
set -u
# A runner inside Claude Code carries its own session id; the ownership cases set theirs.
unset CLAUDE_PROJECT_DIR CLAUDE_CODE_SESSION_ID

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

REPO="$WS/repo"; mkdir -p "$REPO/app/Models" "$REPO/.cc-artifacts/taskmaster/tasks/2026-01-01-demo"
git -C "$REPO" init -q -b main && git -C "$REPO" config user.email t@t.t && git -C "$REPO" config user.name t
echo a > "$REPO/a.txt"; git -C "$REPO" add -A && git -C "$REPO" commit -qm init
git -C "$REPO" checkout -q -b feature; echo b >> "$REPO/a.txt"; git -C "$REPO" commit -qam two
HEAD=$(git -C "$REPO" rev-parse HEAD); BASE=$(git -C "$REPO" rev-parse main)
IDX="$REPO/.cc-artifacts/taskmaster/tasks/2026-01-01-demo/00-INDEX.md"; echo '| 01 | x | pending |' > "$IDX"
TR="$REPO/.cc-artifacts/task-runner"; SENT="$TR/active-run.json"
mkdir -p "$TR/bg"
printf '{"head":"%s"}' "$HEAD" > "$TR/gate-pass.json"
printf '{}' > "$TR/bg/bg-$HEAD.json"; printf '{}' > "$TR/closed-run.json"

# 1) fresh, from a subdirectory with a cwd-relative index path
out=$(cd "$REPO/app/Models" && bash "$RR" --index ../../.cc-artifacts/taskmaster/tasks/2026-01-01-demo/00-INDEX.md --session s-1 2>&1); r=$?
[ "$r" = 0 ] && ok "registers (exit 0)" || bad "registers (exit 0)" "rc=$r out=<$out>"
got=$(jq -c '[.slug,.base,.branch,.start_sha,.index_path]' "$SENT" 2>/dev/null)
want=$(jq -cn --arg b "$BASE" --arg h "$HEAD" '["2026-01-01-demo",$b,"feature",$h,".cc-artifacts/taskmaster/tasks/2026-01-01-demo/00-INDEX.md"]')
[ "$got" = "$want" ] && ok "active-run.json carries slug, merge-base, branch, start_sha and a root-relative index_path" \
  || bad "active-run.json fields" "got=$got want=$want"
[ ! -e "$TR/gate-pass.json" ] && [ ! -e "$TR/bg/bg-$HEAD.json" ] && [ ! -e "$TR/closed-run.json" ] \
  && ok "stale gate-pass, bg-<HEAD> and closed-run records are deleted" || bad "stale records deleted" "$(ls -R "$TR")"
for d in rv rt bg nc reductions; do [ -d "$TR/$d" ] || bad "creates $d/" "missing"; done
[ "$(cat "$TR/.gitignore" 2>/dev/null)" = '*' ] && ok "creates the record dirs and a self-ignoring .gitignore" || bad ".gitignore" "missing"
[ ! -e "$REPO/app/Models/.claude" ] && [ ! -e "$REPO/app/Models/.cc-artifacts" ] && ok "writes nothing under the shell's subdirectory" || bad "subdir state" "found .claude or .cc-artifacts"
ph=$(jq -c '[.phase,.owner,.session_id]' "$REPO/.cc-artifacts/cc-phase/s-1.json" 2>/dev/null)
[ "$ph" = '["build","task-runner:run","s-1"]' ] && ok "writes the build phase sentinel under this session's own key" || bad "phase sentinel" "got=$ph"

# 2) resume: the same index on the same branch keeps the registration (its mtime is the record cutoff)
REF="$WS/ref"; touch -t 200101010000 "$REF"; touch -t 200001010000 "$SENT"; before=$(cat "$SENT"); printf '{"head":"%s"}' "$HEAD" > "$TR/gate-pass.json"
out=$(cd "$REPO" && bash "$RR" --index "$IDX" --session s-2 2>/dev/null)
[ "$(cat "$SENT")" = "$before" ] && [ -z "$(find "$SENT" -newer "$REF")" ] && [ -e "$TR/gate-pass.json" ] \
  && ok "a second call for the same run resumes it untouched" || bad "resume" "out=<$out>"
case "$out" in resumed*) ok "says it resumed" ;; *) bad "says it resumed" "out=<$out>" ;; esac
[ "$(jq -r '.phase + "|" + .session_id' "$REPO/.cc-artifacts/cc-phase/s-2.json" 2>/dev/null)" = "build|s-2" ] \
  && [ "$(jq -r .session_id "$REPO/.cc-artifacts/cc-phase/s-1.json" 2>/dev/null)" = s-1 ] \
  && ok "a resume writes the new session its own build sentinel and leaves the first session's" \
  || bad "resume phase sentinel" "$(ls "$REPO/.cc-artifacts/cc-phase" 2>/dev/null | tr '\n' ' ')"

# 3) --fresh, and a different list, both register anew
rm -rf "$REPO/.cc-artifacts/cc-phase"
err=$(cd "$REPO" && bash "$RR" --index "$IDX" --fresh 2>&1 >/dev/null); r=$?
[ -n "$(find "$SENT" -newer "$REF")" ] && [ ! -e "$TR/gate-pass.json" ] && ok "--fresh registers anew" || bad "--fresh" "sentinel not rewritten"
[ "$r" = 0 ] && [ -z "$(ls "$REPO/.cc-artifacts/cc-phase" "$REPO/.claude/cc-phase" 2>/dev/null)" ] && [ ! -e "$REPO/.claude/cc-phase.json" ] \
  && ok "no --session: registers, and writes no phase sentinel any session would read" || bad "no --session phase" "rc=$r $(ls -a "$REPO/.cc-artifacts")"
case "$err" in *"no --session"*) ok "no --session: says no sentinel was written" ;; *) bad "no --session notice" "err=<$err>" ;; esac
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
pick() { rm -f "$WS/picked"; (cd "$REPO" && PATH="$1" bash "$2" --index "$IDX" --fresh --session s-p >/dev/null 2>"$WS/err"); cat "$WS/picked" 2>/dev/null; }
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
# An older taskmaster exits 0 without the new per-session file (these stubs write none): register-run writes it.
[ "$(jq -r '.phase + "|" + .session_id' "$REPO/.cc-artifacts/cc-phase/s-p.json" 2>/dev/null)" = "build|s-p" ] \
  && grep -q 'wrote no per-session sentinel' "$WS/err" \
  && ok "a writer that exits 0 without the per-session file: register-run writes it and says so" \
  || bad "old-writer fallback" "err=<$(cat "$WS/err")> files=<$(ls -a "$REPO/.cc-artifacts/cc-phase" 2>/dev/null | tr '\n' ' ')>"

# 5) ownership (0.56.0): the run names the session that registered it, the one candor's Stop gate holds. Before it, a
# second session in the repo was held by a run it never registered and told the run file might be left over.
own() { jq -r '.session_id // "none"' "$SENT" 2>/dev/null; }
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=sess-A bash "$RR" --index "$IDX" --fresh --session typed-by-model >/dev/null 2>&1)
[ "$(own)" = sess-A ] && ok "a fresh registration records the host's CLAUDE_CODE_SESSION_ID as owner, not the --session argument" \
  || bad "fresh registration records the owner" "$(cat "$SENT")"
touch -t 200001010000 "$SENT"; before=$(cat "$SENT")
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=sess-A bash "$RR" --index "$IDX" 2>/dev/null)
[ "$(cat "$SENT")" = "$before" ] && [ -z "$(find "$SENT" -newer "$REF")" ] && case "$out" in resumed*) ! grep -q 'now owned' <<<"$out" ;; *) false ;; esac \
  && ok "the owner's own resume leaves the run untouched and claims nothing" || bad "owner's resume" "out=<$out> $(cat "$SENT")"
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=sess-B bash "$RR" --index "$IDX" 2>/dev/null)
[ "$(own)" = sess-B ] && [ -z "$(find "$SENT" -newer "$REF")" ] \
  && [ "$(jq -cS 'del(.session_id)' "$SENT")" = "$(jq -cS 'del(.session_id)' <<<"$before")" ] && grep -q 'now owned by this session' <<<"$out" \
  && ok "a resume from another session re-claims the run, keeping its mtime and every other field" \
  || bad "a resume from another session re-claims the run" "out=<$out> mtime-moved=<$(find "$SENT" -newer "$REF")> $(cat "$SENT")"
(cd "$REPO" && bash "$RR" --index "$IDX" --session s-9 >/dev/null 2>&1)
[ "$(own)" = none ] && [ -z "$(find "$SENT" -newer "$REF")" ] \
  && ok "a resume with no host session id drops the owner, so every session is held as before" || bad "resume without a session id" "$(cat "$SENT")"
(cd "$REPO" && CLAUDE_CODE_SESSION_ID='a"b c' bash "$RR" --index "$IDX" --fresh >/dev/null 2>&1)
[ "$(own)" = none ] && jq empty "$SENT" 2>/dev/null && ok "a session id outside [A-Za-z0-9._-] records no owner" || bad "malformed session id" "$(cat "$SENT")"
(cd "$REPO" && bash "$RR" --index "$IDX" --fresh --session s-1 >/dev/null 2>&1)
[ "$(jq -r 'has("session_id")' "$SENT")" = false ] && ok "with no host session id a fresh run names no owner (the pre-0.56.0 shape)" \
  || bad "no host session id" "$(cat "$SENT")"

# 6) a run registered before 2026-11-14 sits in .claude/task-runner/ with its index under taskmaster-docs/: the next call copies the dir
# once, mtimes kept and iso/ (git worktrees) left out, resumes from the copy and leaves the old dir as it was; a sentinel this session
# left in .claude/cc-phase/ is cleared with the new one written.
L="$WS/legacy"; mkdir -p "$L/taskmaster-docs/tasks/old-run" "$L/.claude/task-runner/rv" "$L/.claude/task-runner/iso/bg.1/tree" "$L/.claude/cc-phase"
git -C "$L" init -q -b feature && git -C "$L" config user.email t@t.t && git -C "$L" config user.name t
echo a > "$L/a.txt"; git -C "$L" add a.txt && git -C "$L" commit -qm init
LI="$L/taskmaster-docs/tasks/old-run/00-INDEX.md"; echo '| 01 | x | pending |' > "$LI"
LH=$(git -C "$L" rev-parse HEAD)
printf '{"slug":"old-run","base":"%s","branch":"feature","start_sha":"%s","index_path":"taskmaster-docs/tasks/old-run/00-INDEX.md"}\n' "$LH" "$LH" > "$L/.claude/task-runner/active-run.json"
printf '{"id":"01","dispatched":true}\n' > "$L/.claude/task-runner/rv/rv-seen-01.json"
printf '# Run environment notes\n- host node: /opt/node/bin\n' > "$L/.claude/task-runner/env-notes.md"
printf '{"phase":"build","session_id":"s-l"}\n' > "$L/.claude/cc-phase/s-l.json"
find "$L/.claude" -exec touch -t 200001010000 {} +
old=$(cd "$L/.claude/task-runner" && find . -type f -exec cksum {} + | sort)
out=$(cd "$L" && bash "$RR" --index "$LI" --session s-l 2>/dev/null); r=$?
LT="$L/.cc-artifacts/task-runner"
case "$out" in resumed*) [ "$r" = 0 ] && ok "a run registered under .claude/task-runner/ resumes, its taskmaster-docs/ index_path matching" ;;
  *) bad "legacy resume" "rc=$r out=<$out>" ;; esac
[ -f "$LT/rv/rv-seen-01.json" ] && grep -q 'host node' "$LT/env-notes.md" && [ ! -e "$LT/iso" ] && [ -z "$(find "$LT/active-run.json" -newer "$REF")" ] \
  && ok "its records and notes are copied to .cc-artifacts/task-runner/ with the registration's mtime, iso/ left out" || bad "legacy copy" "$(ls -AR "$LT" 2>&1)"
[ "$(cd "$L/.claude/task-runner" && find . -type f -exec cksum {} + | sort)" = "$old" ] && [ -z "$(find "$L/.claude/task-runner" -newer "$REF")" ] \
  && ok "the old .claude/task-runner/ is left as it was" || bad "legacy dir untouched" "$(find "$L/.claude/task-runner" -newer "$REF")"
[ ! -e "$L/.claude/cc-phase/s-l.json" ] && [ "$(jq -r .phase "$L/.cc-artifacts/cc-phase/s-l.json" 2>/dev/null)" = build ] \
  && ok "the session's sentinel is written under .cc-artifacts/cc-phase/ and its .claude/cc-phase/ copy cleared" || bad "legacy sentinel" "$(ls -A "$L/.claude/cc-phase" "$L/.cc-artifacts/cc-phase" 2>&1)"

# 4) refusals
(cd "$REPO" && bash "$RR" --index nope/00-INDEX.md >/dev/null 2>&1); r=$?
[ "$r" = 3 ] && ok "an index that does not exist is a usage error (3)" || bad "missing index" "rc=$r"
mkdir -p "$WS/plain"; (cd "$WS/plain" && bash "$RR" >/dev/null 2>&1); r=$?
[ "$r" = 5 ] && ok "outside a git work tree exits 5" || bad "outside git" "rc=$r"

exit $rc
