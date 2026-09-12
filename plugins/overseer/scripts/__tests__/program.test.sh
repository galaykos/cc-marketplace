#!/usr/bin/env bash
# Tests program.sh, announce.sh and capability-scan.sh against throwaway git repos.
# Asserts: init writes state + .gitignore; --hands-off needs --reason; detached HEAD stores a base;
# a second init over a program with milestones is refused (2); vocabularies are enforced (2);
# `done` cannot be set by hand (2); file kinds need --file, stored absolute, must be a non-empty
# regular file (2); accept refuses without the nine required kinds (2) and names the missing ones,
# refuses when an evidence file was deleted after recording (2), refuses a hands-off program with
# no ASSUMED decision (2), passes otherwise (0); `next` and the hook treat parked as closed and
# honour depends; a malformed state file exits 5 and leaves no temp file; 20 concurrent evidence
# adds all land; `dispatch check` refuses a prompt missing the preamble/scope/skill/verify (2) and
# passes a complete one (0), `--kind reader|reviewer` drops the scope/verify checks and demands a RETURN shape
# and a read-only statement, a relative state-file mention or an unstopped dev server is a WARN; skill-path.sh
# resolves the newest cache dir that has the file and a project skill; `close` refuses with open milestones (2), archives otherwise, and
# init may follow; capability-scan flags a CI trigger that misses the base branch and never emits
# `unknown` as an installed name. The harness never touches the live repo (mktemp only).
set -u
here=$(cd "$(dirname "$0")" && pwd)
PS="$here/../program.sh"; SCAN="$here/../capability-scan.sh"; HOOK="$here/../../hooks/announce.sh"
for x in "$PS" "$SCAN" "$HOOK"; do [ -x "$x" ] || { echo "FAIL: $x not executable"; exit 1; }; done
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq required"; exit 1; }
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
git -C "$WS" init -q -b main 2>/dev/null || git -C "$WS" init -q
export OVERSEER_ROOT="$WS"
SD="$WS/.claude/overseer"
pass=0; fail=0
ok()   { pass=$((pass+1)); }
bad()  { fail=$((fail+1)); echo "FAIL: $1"; }
expect() { # expect <code> <desc> -- cmd...
  local want="$1" desc="$2"; shift 3
  "$@" >"$WS/out" 2>"$WS/err"; local got=$?
  [ "$got" = "$want" ] && ok || bad "$desc (want $want, got $got): $(cat "$WS/err" "$WS/out" | head -3)"
}
mkfile() { printf 'x\n' > "$1"; }

# ---- init -------------------------------------------------------------------------------
expect 3 "status before init" -- "$PS" status
expect 2 "bad slug" -- "$PS" init --goal "g" --slug "Bad Slug"
expect 3 "flag without value" -- "$PS" init --slug g --goal
expect 2 "hands-off needs reason" -- "$PS" init --goal g --slug g --hands-off
expect 0 "init" -- "$PS" init --goal "Build a \"CRM\" ünïcode" --slug crm --base main
[ "$(cat "$SD/.gitignore")" = "*" ] && ok || bad ".gitignore holds *"
jq -e '.goal=="Build a \"CRM\" ünïcode" and .base_branch=="main" and (.milestones|length)==0' "$SD/program.json" >/dev/null && ok || bad "init state"
grep -q "ASSUMED" "$SD/decisions.md" && ok || bad "decisions.md explains ASSUMED rows"
expect 0 "init again with no milestones is allowed" -- "$PS" init --goal "Build a CRM" --slug crm --base main

# ---- milestones --------------------------------------------------------------------------
expect 2 "bad milestone id" -- "$PS" milestone add --id one --title t --branch b
expect 0 "add m1" -- "$PS" milestone add --id m1 --title "Skeleton" --branch ov/m1
expect 2 "duplicate m1" -- "$PS" milestone add --id m1 --title "Skeleton" --branch ov/m1
expect 2 "depends on missing" -- "$PS" milestone add --id m2 --title "Upload" --branch ov/m2 --depends m9
expect 2 "self dependency" -- "$PS" milestone add --id m2 --title "Upload" --branch ov/m2 --depends m2
expect 0 "add m2 depends m1,m1 (deduped)" -- "$PS" milestone add --id m2 --title "Upload" --branch ov/m2 --depends m1,m1
jq -e '.milestones[1].depends==["m1"]' "$SD/program.json" >/dev/null && ok || bad "depends deduped"
expect 2 "second init over program with milestones refused" -- "$PS" init --goal "x" --slug x
grep -q "program.sh close" "$WS/err" && ok || bad "refusal names close"
[ -d "$SD/milestones/m1/evidence" ] && [ -d "$SD/milestones/m1/dispatch" ] && ok || bad "milestone dirs"
[ "$("$PS" next | cut -f1)" = "m1" ] && ok || bad "next is m1"
expect 2 "bad status word" -- "$PS" milestone set --id m1 --status finished
expect 2 "done by hand refused" -- "$PS" milestone set --id m1 --status done
expect 2 "parked needs reason" -- "$PS" milestone set --id m1 --status parked
expect 3 "set rejects --title" -- "$PS" milestone set --id m1 --status building --title x
expect 0 "set building" -- "$PS" milestone set --id m1 --status building

# ---- hook: open program announces, resolves root from a subdir -------------------------------
mkdir -p "$WS/sub"
hook_out=$(printf '{"cwd":"%s"}' "$WS/sub" | "$HOOK")
printf '%s' "$hook_out" | grep -q 'next: m1 Skeleton (building)' && ok || bad "hook announces from subdir: $hook_out"
[ -z "$(printf '{"cwd":"/nonexistent"}' | "$HOOK")" ] && ok || bad "hook silent on missing cwd"
[ -z "$(printf 'not json' | "$HOOK")" ] && ok || bad "hook silent on malformed input"

# ---- evidence ---------------------------------------------------------------------------
expect 2 "accept without evidence" -- "$PS" accept --id m1
grep -q "viewport:mobile" "$WS/err" && grep -q "keyboard" "$WS/err" && grep -q "motion" "$WS/err" && ok || bad "missing kinds named (incl. keyboard, motion)"
expect 2 "bad evidence kind" -- "$PS" evidence add --id m1 --kind vibes --note n
expect 2 "evidence needs note" -- "$PS" evidence add --id m1 --kind tests
expect 2 "file kind needs --file" -- "$PS" evidence add --id m1 --kind tests --note n
expect 2 "evidence file must exist" -- "$PS" evidence add --id m1 --kind tests --note n --file "$WS/nope.txt"
: > "$WS/empty.txt"
expect 2 "evidence file must be non-empty" -- "$PS" evidence add --id m1 --kind tests --note n --file "$WS/empty.txt"
expect 2 "evidence file must be a regular file" -- "$PS" evidence add --id m1 --kind tests --note n --file "$WS/sub"
mkfile "$WS/rel.txt"
( cd "$WS" && "$PS" evidence add --id m1 --kind tests --note "suite" --file rel.txt >/dev/null 2>&1 ) && ok || bad "relative --file accepted"
jq -e --arg f "$WS/rel.txt" '.milestones[0].evidence[0].file==$f' "$SD/program.json" >/dev/null \
  || jq -e '.milestones[0].evidence[0].file|startswith("/")' "$SD/program.json" >/dev/null && ok || bad "file stored absolute"
expect 0 "optional kind without file" -- "$PS" evidence add --id m1 --kind review --note "clean"
for k in browser-happy browser-error viewport:mobile viewport:tablet viewport:desktop keyboard motion; do
  mkfile "$WS/$k.png"
  expect 0 "evidence $k" -- "$PS" evidence add --id m1 --kind "$k" --note "did $k" --file "$WS/$k.png"
done
expect 2 "accept still missing console-clean" -- "$PS" accept --id m1
grep -q "console-clean" "$WS/err" && ! grep -q "viewport:mobile" "$WS/err" && ok || bad "only console-clean missing"
mkfile "$WS/console.txt"
expect 0 "evidence console-clean with file" -- "$PS" evidence add --id m1 --kind console-clean --note clean --file "$WS/console.txt"
mv "$WS/motion.png" "$WS/motion.gone"
expect 2 "accept refuses when an evidence file vanished" -- "$PS" accept --id m1
grep -q "no longer exist" "$WS/err" && ok || bad "vanished file named"
mv "$WS/motion.gone" "$WS/motion.png"
expect 0 "accept m1" -- "$PS" accept --id m1
jq -e '.milestones[0].status=="done" and .milestones[0].accepted_at!=null' "$SD/program.json" >/dev/null && ok || bad "m1 done"
[ "$("$PS" next | cut -f1)" = "m2" ] && ok || bad "next advances to m2"
expect 2 "accept from queued refused" -- "$PS" accept --id m2
expect 0 "clear evidence" -- "$PS" evidence clear --id m1
jq -e '.milestones[0].evidence==[]' "$SD/program.json" >/dev/null && ok || bad "evidence cleared"

# ---- decisions ---------------------------------------------------------------------------
expect 0 "decision add" -- "$PS" decision add --text "shadcn" --rationale "already in tree" --options "shadcn | mui"
grep -q "| shadcn | shadcn | mui | already in tree |" "$SD/decisions.md" && ok || bad "decision row"
expect 2 "assumed needs alternative" -- "$PS" decision add --assumed --text "gallery" --rationale "r"
expect 0 "assumed decision" -- "$PS" decision add --assumed --text "team gallery" --alternative "profile avatar" --rationale "goal says users upload photos, plural"
grep -q "| ASSUMED: team gallery | not taken: profile avatar |" "$SD/decisions.md" && ok || bad "assumed row"
expect 0 "status prints" -- "$PS" status
grep -q "next: m2" "$WS/out" && grep -q "assumed decisions: 1" "$WS/out" && ok || bad "status names next and assumption count"

# ---- parked is closed, for next and for the hook ----------------------------------------------
expect 0 "parked with reason" -- "$PS" milestone set --id m2 --status parked --reason "branch missing"
[ "$("$PS" next)" = "none" ] && ok || bad "next none when parked"
[ -z "$(printf '{"cwd":"%s"}' "$WS" | "$HOOK")" ] && ok || bad "hook silent when all done/parked"
expect 0 "add m3 depends m2" -- "$PS" milestone add --id m3 --title "Polish" --branch ov/m3 --depends m2
hook_out=$(printf '{"cwd":"%s"}' "$WS" | "$HOOK")
printf '%s' "$hook_out" | grep -q 'none runnable' && ok || bad "hook says none runnable when dep parked: $hook_out"
[ "$("$PS" next)" = "none" ] && ok || bad "next none when dependency parked"

# ---- close / re-init / archive -----------------------------------------------------------------
expect 2 "close refuses with open m3" -- "$PS" close
expect 0 "park m3" -- "$PS" milestone set --id m3 --status parked --reason "dep parked"
mkdir -p "$SD/milestones/m1/evidence" && printf 'x' > "$SD/milestones/m1/evidence/in-dir.png"
expect 0 "evidence stored inside the program dir" -- "$PS" evidence add --id m1 --kind review --note "in dir" --file "$SD/milestones/m1/evidence/in-dir.png"
expect 0 "close" -- "$PS" close
[ ! -f "$SD/program.json" ] && ls -d "$SD"/archive/crm-*/milestones/m1 >/dev/null 2>&1 && [ -f "$SD/decisions.md" ] && ok || bad "archive layout"
arch_pj=$(ls "$SD"/archive/crm-*/program.json)
jq -e '[.milestones[].evidence[].file|select(contains("/archive/") and endswith("/milestones/m1/evidence/in-dir.png"))]|length==1' "$arch_pj" >/dev/null && ok || bad "an evidence path inside the program dir is rewritten to the archive"
jq -e 'all(.milestones[].evidence[].file; contains("/milestones/") and (contains("/archive/")|not)|not)' "$arch_pj" >/dev/null && ok || bad "no archived evidence path still points at the live milestones dir"
jq -r '.milestones[].evidence[].file' "$arch_pj" | while read -r f; do [ -f "$f" ] || { echo "dead: $f"; exit 1; }; done && ok || bad "every archived evidence file exists at its recorded path"
expect 0 "init after close" -- "$PS" init --goal "Second" --slug second
[ -z "$(printf '{"cwd":"%s"}' "$WS" | "$HOOK")" ] && ok || bad "hook silent on program with no milestones"
expect 0 "status on empty roadmap" -- "$PS" status
grep -q "no milestones registered" "$WS/out" && ok || bad "status explains empty roadmap"

# ---- hands-off accept gate ---------------------------------------------------------------------
"$PS" init --goal "Third" --slug third --hands-off --reason "headless" >/dev/null 2>&1
rm -f "$SD/decisions.md"; "$PS" init --goal "Third" --slug third --hands-off --reason "headless" >/dev/null 2>&1
"$PS" milestone add --id m1 --title t --branch b >/dev/null; "$PS" milestone set --id m1 --status building >/dev/null
for k in tests browser-happy browser-error viewport:mobile viewport:tablet viewport:desktop console-clean keyboard motion; do
  "$PS" evidence add --id m1 --kind "$k" --note n --file "$WS/console.txt" >/dev/null
done
expect 2 "hands-off accept refused without ASSUMED decision" -- "$PS" accept --id m1
grep -q "ASSUMED" "$WS/err" && ok || bad "refusal names ASSUMED"
"$PS" decision add --assumed --text a --alternative b --rationale c >/dev/null
expect 0 "hands-off accept passes with ASSUMED decision" -- "$PS" accept --id m1
"$PS" status > "$WS/out"; grep -q "hands-off (headless)" "$WS/out" && ok || bad "status shows hands-off reason"

# ---- malformed state / write failure ---------------------------------------------------------
cp "$SD/program.json" "$WS/good.json"
printf '{"milestones": [' > "$SD/program.json"
expect 5 "malformed state exits 5" -- "$PS" milestone add --id m2 --title t --branch b
[ -z "$(ls "$SD"/program.json.tmp.* 2>/dev/null)" ] && ok || bad "no temp file left behind"
cp "$WS/good.json" "$SD/program.json"

# ---- concurrency ---------------------------------------------------------------------------
"$PS" milestone add --id m2 --title t --branch b >/dev/null
for i in $(seq 1 20); do "$PS" evidence add --id m2 --kind a11y --note "n$i" >/dev/null 2>&1 & done; wait
n=$(jq '[.milestones[]|select(.id=="m2")|.evidence[]]|length' "$SD/program.json")
[ "$n" = "20" ] && ok || bad "20 concurrent evidence adds landed (got $n)"
[ ! -d "$SD/program.json.lock" ] && ok || bad "lock released"

# ---- detached HEAD ----------------------------------------------------------------------------
W2=$(mktemp -d); git -C "$W2" init -q -b main 2>/dev/null || git -C "$W2" init -q
git -C "$W2" -c user.name=t -c user.email=t@t commit -q --allow-empty -m i && git -C "$W2" checkout -q --detach
OVERSEER_ROOT="$W2" "$PS" init --goal g --slug g >/dev/null 2>&1
[ "$(jq -r .base_branch "$W2/.claude/overseer/program.json")" = "main" ] && ok || bad "detached HEAD base defaults to main"
rm -rf "$W2"

# ---- dispatch check ----------------------------------------------------------------------------
PRE="$WS/preamble.md"; cat > "$PRE" <<'EOF'
# Portable discipline preamble
1. Restate the card as discrete ordered steps; one change per step.
2. Inner loop: implement → run the card's **exact** `Verify` command.
3. Three failed fix cycles on one card → **halt**.
EOF
export OVERSEER_PREAMBLE="$PRE"
mkdir -p "$WS/skills/x"; printf 'x' > "$WS/skills/x/SKILL.md"
printf 'Do the thing.\nVERIFY: make test\n' > "$WS/p1.md"
expect 2 "dispatch check refuses bare prompt" -- "$PS" dispatch check "$WS/p1.md"
grep -q "preamble clause" "$WS/err" && grep -q "TOUCH ONLY" "$WS/err" && grep -q "skill pinned" "$WS/err" && ok || bad "dispatch check names every miss"
{ cat "$PRE"; printf 'TOUCH ONLY: %s/a.php\nREAD FIRST: %s/skills/x/SKILL.md\nVERIFY: make test\n' "$WS" "$WS"; } > "$WS/p2.md"
expect 0 "dispatch check passes complete prompt" -- "$PS" dispatch check "$WS/p2.md"
sed 's/one change per step/one change per step, roughly/' "$WS/p2.md" > "$WS/p3.md"
expect 2 "dispatch check refuses a reworded clause" -- "$PS" dispatch check "$WS/p3.md"
sed "s#$WS/skills/x/SKILL.md#/nonexistent/SKILL.md#" "$WS/p2.md" > "$WS/p4.md"
expect 2 "dispatch check refuses a skill path that does not exist" -- "$PS" dispatch check "$WS/p4.md"
expect 3 "dispatch check on missing file" -- "$PS" dispatch check "$WS/nope.md"
# reader kind: no scope/verify needed, RETURN + "write no file" needed
{ cat "$PRE"; printf 'READ FIRST: %s/skills/x/SKILL.md\nYou WRITE NO FILES.\nRETURN (max 40 lines): a document\n' "$WS"; } > "$WS/p5.md"
expect 0 "dispatch check --kind reader passes a read-only prompt" -- "$PS" dispatch check "$WS/p5.md" --kind reader
expect 2 "dispatch check (worker) refuses the same read-only prompt" -- "$PS" dispatch check "$WS/p5.md"
{ cat "$PRE"; printf 'READ FIRST: %s/skills/x/SKILL.md\nRETURN: findings\n' "$WS"; } > "$WS/p6.md"
expect 2 "dispatch check --kind reviewer needs the read-only statement" -- "$PS" dispatch check "$WS/p6.md" --kind reviewer
expect 2 "dispatch check rejects an unknown kind" -- "$PS" dispatch check "$WS/p2.md" --kind boss
# followup kind: a message to a live worker — no preamble text, but it must say the preamble binds,
# keep TOUCH ONLY / VERIFY / RETURN and name the dispatch file it continues
printf 'Fix cycle 3 — same preamble and rules as your card %s/dispatch/3-fix-1.md; same TOUCH ONLY set plus b.php; same VERIFY; same RETURN shape.\n1. do x\n' "$WS" > "$WS/p8.md"
expect 0 "dispatch check --kind followup passes a complete follow-up" -- "$PS" dispatch check "$WS/p8.md" --kind followup
expect 2 "dispatch check (worker) refuses the same follow-up (no preamble text)" -- "$PS" dispatch check "$WS/p8.md"
printf 'Fix cycle 3 — three more items, same TOUCH ONLY, same VERIFY, same RETURN.\n1. do x\n' > "$WS/p9.md"
expect 2 "dispatch check --kind followup refuses one that neither names the preamble nor the dispatch file" -- "$PS" dispatch check "$WS/p9.md" --kind followup
grep -q "preamble still applies" "$WS/err" && grep -q "dispatch file it continues" "$WS/err" && ok || bad "followup refusal names both misses"
{ cat "$WS/p2.md"; printf 'Apply the findings in findings.md and read decisions.md first.\nThen run npm run dev to check.\n' ; } > "$WS/p7.md"
expect 0 "dispatch check passes with warnings" -- "$PS" dispatch check "$WS/p7.md"
grep -q "findings.md is mentioned without an absolute path" "$WS/err" && grep -q "decisions.md is mentioned" "$WS/err" && grep -q "dev server" "$WS/err" && ok || bad "dispatch check warns on relative state files and an unstopped dev server: $(cat "$WS/err")"
# skill-path resolver: cache fallback picks the newest dir that HAS the file; missing → 1
SP="$here/../skill-path.sh"
FAKEHOME=$(mktemp -d); mkdir -p "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.9.0/skills/s" "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.10.0/skills/other" "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.2.0/skills/s"
printf x > "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.9.0/skills/s/SKILL.md"; printf x > "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.2.0/skills/s/SKILL.md"
got=$(HOME="$FAKEHOME" PATH=/usr/bin:/bin bash "$SP" pl s 2>/dev/null)
[ "$got" = "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.9.0/skills/s/SKILL.md" ] && ok || bad "skill-path picks 0.9.0 (newest dir with the file, not 0.10.0): $got"
HOME="$FAKEHOME" PATH=/usr/bin:/bin bash "$SP" pl s 2>&1 >/dev/null | grep -q "newest cache dir 0.9.0" && ok || bad "skill-path names the route it used"
expect 1 "skill-path missing skill exits 1" -- env HOME="$FAKEHOME" PATH=/usr/bin:/bin bash "$SP" pl nope
mkdir -p "$FAKEHOME/proj/.claude/skills/s"; printf x > "$FAKEHOME/proj/.claude/skills/s/SKILL.md"
[ "$(HOME="$FAKEHOME" PATH=/usr/bin:/bin bash "$SP" project s --project "$FAKEHOME/proj")" = "$FAKEHOME/proj/.claude/skills/s/SKILL.md" ] && ok || bad "skill-path resolves a project skill"
rm -rf "$FAKEHOME"

# ---- capability-scan: CI mismatch, no unknown sentinel ------------------------------------------
W3=$(mktemp -d); git -C "$W3" init -q -b master 2>/dev/null || git -C "$W3" init -q
mkdir -p "$W3/.github/workflows"; printf 'on:\n  push:\n    branches: [main]\n  pull_request:\n    branches: [main]\njobs: {}\n' > "$W3/.github/workflows/tests.yml"
out=$(PATH=/usr/bin:/bin HOME="$W3" "$SCAN" --root "$W3" 2>/dev/null)
printf '%s' "$out" | grep -q "does not trigger on base 'master'" && ok || bad "scan flags CI branch mismatch: $out"
printf '%s' "$out" | grep "^# install" | grep -q "playwright" && bad "scan still lists playwright as installable" || ok
js=$(PATH=/usr/bin:/bin HOME="$W3" "$SCAN" --root "$W3" --json 2>/dev/null)
printf '%s' "$js" | jq -e '(.phases|map(.installed[])|index("unknown"))==null and .cli_available==false and (.ci[0].triggers_on_base==false)' >/dev/null && ok || bad "scan --json: no unknown, ci parsed: $js"
rm -rf "$W3"

echo "program.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
