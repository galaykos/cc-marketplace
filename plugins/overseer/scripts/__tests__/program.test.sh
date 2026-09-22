#!/usr/bin/env bash
# Tests program.sh, announce.sh and capability-scan.sh against throwaway git repos.
# Asserts: init writes state + .gitignore; --hands-off needs --reason; --model is opus|auto (default opus); detached HEAD stores a base;
# milestone --size is S|M|L|XL (default M) and --rigour lean|standard|adversarial (unset draws a WARN per gated dispatch; a surface
# kind is never lean); set --size/--rigour needs --reason and lands in history; a dispatch needs a MODEL: line the tier allows and a
# worker never inherits even under --model auto; an M+ milestone's direct worker WARNs unless a taskmaster index registered after
# the milestone names it (touching the brief changes nothing); an Ultra:/Goal: index on a lean/standard milestone WARNs (hands-off: points at goal-lean; Goal: boost=off does not), an
# adversarial milestone with no marker or a boost=off one WARNs; `dispatch check` exit 0 records the file in dispatch/.gated and accept counts only
# gated, unchanged files whose pins EXIST; accept refuses evidence older than the last gated worker dispatch; accept prints sized vs actual;
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
WS=$(mktemp -d); FAKEHOME=$(mktemp -d); trap 'rm -rf "$WS" "$FAKEHOME"' EXIT
git -C "$WS" init -q -b main 2>/dev/null || git -C "$WS" init -q
export OVERSEER_ROOT="$WS"
SD="$WS/.claude/overseer"
# the session-root gate reads CLAUDE_CODE_SESSION_ID + ~/.claude/projects; the harness's project is a
# temp dir, so a real session id would (correctly) refuse every init — unset it, test the gate explicitly below
unset CLAUDE_CODE_SESSION_ID
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
expect 2 "init refuses an unknown model tier" -- "$PS" init --goal g --slug g --model fable
grep -q "opus auto" "$WS/err" && ok || bad "tier refusal lists the tiers"
expect 0 "init" -- "$PS" init --goal "Build a \"CRM\" ünïcode" --slug crm --base main
[ "$(cat "$SD/.gitignore")" = "*" ] && ok || bad ".gitignore holds *"
jq -e '.goal=="Build a \"CRM\" ünïcode" and .base_branch=="main" and (.milestones|length)==0' "$SD/program.json" >/dev/null && ok || bad "init state"
[ "$(jq -r .model "$SD/program.json")" = "opus" ] && ok || bad "init defaults the model tier to opus (nothing above opus unless asked)"
grep -q "ASSUMED" "$SD/decisions.md" && ok || bad "decisions.md explains ASSUMED rows"
expect 0 "init again with no milestones is allowed" -- "$PS" init --goal "Build a CRM" --slug crm --base main

# the canonical preamble fixture and a pinnable skill, used by dispatch check below and by the gated dispatches accept needs
PRE="$WS/preamble.md"; cat > "$PRE" <<'EOF'
# Portable discipline preamble
1. Restate the card as discrete ordered steps; one change per step.
2. Inner loop: implement → run the card's **exact** `Verify` command.
3. Three failed fix cycles on one card → **halt**.
4. Touch **only** the allowed-files named in this dispatch prompt;
   an out-of-set edit reclaims the card.
EOF
export OVERSEER_PREAMBLE="$PRE"
mkdir -p "$WS/skills/x"; printf 'x' > "$WS/skills/x/SKILL.md"
# wprompt <file> <skill-path>… : a complete worker prompt; rprompt: a complete read-only reviewer prompt
wprompt() { local f="$1"; shift; { cat "$PRE"; printf 'TOUCH ONLY: %s/a.php\n' "$WS"; for sk in "$@"; do printf 'READ FIRST: %s\n' "$sk"; done; printf 'VERIFY: make test\nMODEL: opus\n'; } > "$f"; }
rprompt() { local f="$1"; shift; { cat "$PRE"; for sk in "$@"; do printf 'READ FIRST: %s\n' "$sk"; done; printf 'You WRITE NO FILES.\nRETURN (max 40 lines): findings\nMODEL: opus\n'; } > "$f"; }

# ---- milestones --------------------------------------------------------------------------
expect 2 "bad milestone id" -- "$PS" milestone add --id one --title t --branch b
expect 0 "add m1" -- "$PS" milestone add --id m1 --title "Skeleton" --branch ov/m1
expect 2 "duplicate m1" -- "$PS" milestone add --id m1 --title "Skeleton" --branch ov/m1
expect 2 "unknown milestone kind" -- "$PS" milestone add --id m9 --title x --branch ov/m9 --kind vibes
grep -q "marketing-page" "$WS/err" && ok || bad "unknown kind lists the known ones"
[ "$(jq -r '.milestones[0].kind' "$SD/program.json")" = feature ] && ok || bad "kind defaults to feature"
expect 2 "unknown milestone size" -- "$PS" milestone add --id m9 --title x --branch ov/m9 --size XXL
[ "$(jq -r '.milestones[]|select(.id=="m1")|.size' "$SD/program.json")" = "M" ] && ok || bad "milestone size defaults to M"
expect 2 "milestone set --size needs --reason" -- "$PS" milestone set --id m1 --size S
expect 0 "milestone set --size with a reason" -- "$PS" milestone set --id m1 --size L --reason "brief shows five cards"
jq -e '.milestones[0] | .size=="L" and (.history|last|.size=="L" and .reason=="brief shows five cards")' "$SD/program.json" >/dev/null && ok || bad "re-size lands in size and history"
"$PS" milestone set --id m1 --size M --reason "back for the status test" >/dev/null
expect 2 "milestone add refuses an unknown rigour" -- "$PS" milestone add --id m9 --title x --branch ov/m9 --rigour extreme
expect 2 "milestone set --rigour needs --reason" -- "$PS" milestone set --id m1 --rigour lean
expect 0 "milestone set --rigour with a reason" -- "$PS" milestone set --id m1 --rigour standard --reason "numeric contract, no surface"
[ "$(jq -r '.milestones[0].rigour' "$SD/program.json")" = standard ] && ok || bad "rigour stored"
expect 3 "milestone set rejects --kind" -- "$PS" milestone set --id m1 --kind crud
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
# read-before-record (0.4.0): hooks/track-read.sh ledgers every Read while a program is open; a file kind
# needs a row from this session at or after the file's last change. The payload carries transcript_path
# because the host does; the hook keys nothing on it (session_id is a ledger field).
TR="$(dirname "$PS")/../hooks/track-read.sh"
mkfile "$WS/shot.png"; mkfile "$WS/unread.png"
payload() { printf '{"session_id":"%s","transcript_path":"%s/t.jsonl","cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"%s"}}' "$1" "$WS" "$2" "$3"; }
out=$(payload s1 "$WS" "$WS/shot.png" | bash "$TR"); [ -z "$out" ] && ok || bad "track-read prints nothing: $out"
grep -qE "^[0-9]+	s1	$(cd "$WS" && pwd -P)/shot\.png$" "$SD/.reads" && ok || bad "track-read ledgers epoch, session, physical path: $(cat "$SD/.reads" 2>/dev/null)"
payload s1 "$FAKEHOME" "$WS/shot.png" | bash "$TR"; [ ! -f "$FAKEHOME/.claude/overseer/.reads" ] && ok || bad "no program open → no ledger"
payload s1 "$WS" "rel-nope.png" | bash "$TR"; grep -q "rel-nope" "$SD/.reads" && bad "a missing file is not ledgered" || ok
expect 0 "evidence add passes a file this session Read" -- env CLAUDE_CODE_SESSION_ID=s1 "$PS" evidence add --id m1 --kind browser-happy --note "looked" --file "$WS/shot.png"
grep -q "read gate inactive" "$WS/err" && bad "no WARN when the session has rows" || ok
expect 2 "evidence add refuses a file this session never Read" -- env CLAUDE_CODE_SESSION_ID=s1 "$PS" evidence add --id m1 --kind browser-happy --note "claimed" --file "$WS/unread.png"
grep -q "was not Read in this session" "$WS/err" && ok || bad "refusal names the read gate: $(head -1 "$WS/err")"
sleep 1; printf 'recaptured\n' >> "$WS/shot.png"
expect 2 "evidence add refuses a file changed after its last Read" -- env CLAUDE_CODE_SESSION_ID=s1 "$PS" evidence add --id m1 --kind browser-happy --note "stale look" --file "$WS/shot.png"
payload s1 "$WS" "$WS/shot.png" | bash "$TR"
expect 0 "evidence add passes again once re-Read" -- env CLAUDE_CODE_SESSION_ID=s1 "$PS" evidence add --id m1 --kind browser-happy --note "looked again" --file "$WS/shot.png"
expect 0 "evidence add fails open for a session with no tracked Read" -- env CLAUDE_CODE_SESSION_ID=s2 "$PS" evidence add --id m1 --kind browser-happy --note "no hook" --file "$WS/unread.png"
grep -q "read gate inactive" "$WS/err" && ok || bad "fail-open is said: $(head -1 "$WS/err")"
expect 0 "evidence add without a session id skips the gate silently" -- "$PS" evidence add --id m1 --kind browser-happy --note "terminal" --file "$WS/unread.png"
grep -q "read gate" "$WS/err" && bad "no session id → no gate talk" || ok
expect 0 "an optional kind without --file is outside the gate" -- env CLAUDE_CODE_SESSION_ID=s1 "$PS" evidence add --id m1 --kind review --note "clean"

# gated dispatches: accept counts only files `dispatch check` passed (dispatch/.gated) and that are unchanged since
mkdir -p "$SD/milestones/m1/dispatch" "$WS/.claude/skills/laravel-best-practices" "$FAKEHOME/.claude/plugins/cache/mkt/testing/1.0.0/skills/testing-best-practices"
printf 'x' > "$WS/.claude/skills/laravel-best-practices/SKILL.md"; printf 'x' > "$FAKEHOME/.claude/plugins/cache/mkt/testing/1.0.0/skills/testing-best-practices/SKILL.md"
TESTSK="$FAKEHOME/.claude/plugins/cache/mkt/testing/1.0.0/skills/testing-best-practices/SKILL.md"; STACKSK="$WS/.claude/skills/laravel-best-practices/SKILL.md"
printf 'READ FIRST: %s\nREAD FIRST: %s\n' "$STACKSK" "$TESTSK" > "$SD/milestones/m1/dispatch/0-hand.md"
expect 2 "accept refuses with no gated dispatch (a hand-written file pinning everything does not count)" -- env HOME="$FAKEHOME" "$PS" accept --id m1
grep -q "no gated dispatch" "$WS/err" && ok || bad "refusal names the gated-dispatch rule: $(head -1 "$WS/err")"
sleep 1; wprompt "$SD/milestones/m1/dispatch/1-backend.md" "$STACKSK"
expect 0 "dispatch check gates a milestone worker file" -- env HOME="$FAKEHOME" "$PS" dispatch check "$SD/milestones/m1/dispatch/1-backend.md" --kind worker --milestone m1
grep -qE "^[0-9]+ worker 1-backend\.md$" "$SD/milestones/m1/dispatch/.gated" && ok || bad ".gated records checksum, kind, file: $(cat "$SD/milestones/m1/dispatch/.gated")"
# kind routing: m1 is 'feature' → needs stack + testing pinned, by paths that exist, in some gated dispatch
expect 2 "accept refuses: kind feature has no testing skill pinned in any gated dispatch" -- env HOME="$FAKEHOME" "$PS" accept --id m1
grep -q "testing:testing-best-practices" "$WS/err" && ok || bad "accept names the unpinned group"
rprompt "$SD/milestones/m1/dispatch/2-review-nowhere.md" "$WS/skills/x/SKILL.md" "/nowhere/.claude/plugins/cache/mkt/testing/1.0.0/skills/testing-best-practices/SKILL.md"
expect 0 "a gated reviewer may pin a path that does not exist beside one that does" -- env HOME="$FAKEHOME" "$PS" dispatch check "$SD/milestones/m1/dispatch/2-review-nowhere.md" --kind reviewer --milestone m1
expect 2 "accept refuses: the testing pin is a path that does not exist" -- env HOME="$FAKEHOME" "$PS" accept --id m1
grep -q "testing:testing-best-practices" "$WS/err" && ok || bad "a text-only pin does not satisfy the group"
rprompt "$SD/milestones/m1/dispatch/3-review-tests.md" "$TESTSK"
env HOME="$FAKEHOME" "$PS" dispatch check "$SD/milestones/m1/dispatch/3-review-tests.md" --kind reviewer --milestone m1 >/dev/null 2>&1
printf '\nedited after the check\n' >> "$SD/milestones/m1/dispatch/3-review-tests.md"
expect 2 "accept refuses: the only testing pin is in a file edited after its check" -- env HOME="$FAKEHOME" "$PS" accept --id m1
grep -q "testing:testing-best-practices" "$WS/err" && ok || bad "an edited-since-check file is not gated"
env HOME="$FAKEHOME" "$PS" dispatch check "$SD/milestones/m1/dispatch/3-review-tests.md" --kind reviewer --milestone m1 >/dev/null 2>&1
# every required evidence row was recorded before 1-backend.md (a worker) — the walk is of older code
expect 2 "accept refuses evidence older than the last gated worker dispatch" -- env HOME="$FAKEHOME" "$PS" accept --id m1
grep -q "recorded before the last gated worker" "$WS/err" && grep -q " tests" "$WS/err" && ok || bad "stale-evidence refusal names the kinds: $(head -1 "$WS/err")"
sleep 1
rewalk() { for k in tests browser-happy browser-error viewport:mobile viewport:tablet viewport:desktop keyboard motion; do
  f="$WS/$k.png"; [ "$k" = tests ] && f="$WS/rel.txt"; "$PS" evidence add --id m1 --kind "$k" --note "re-walked" --file "$f" >/dev/null; done
"$PS" evidence add --id m1 --kind console-clean --note "re-walked" --file "$WS/console.txt" >/dev/null; }
rewalk
# a follow-up to a live worker is a dispatch too: gated in .gated, and a walk older than it is stale (0.3.2 — the
# followup branch used to exit before the record, so no fix cycle ever moved the stale-evidence line)
sleep 1
printf 'Fix cycle 2 — same preamble and rules as your card %s/dispatch/1-backend.md; same TOUCH ONLY set; same VERIFY; same RETURN shape.\n1. do y\n' "$SD/milestones/m1" > "$SD/milestones/m1/dispatch/1-followup.md"
expect 0 "dispatch check --kind followup inside dispatch/" -- env HOME="$FAKEHOME" "$PS" dispatch check "$SD/milestones/m1/dispatch/1-followup.md" --kind followup
grep -qE "^[0-9]+ followup 1-followup\.md$" "$SD/milestones/m1/dispatch/.gated" && ok || bad "a gated follow-up is recorded in .gated: $(cat "$SD/milestones/m1/dispatch/.gated")"
expect 2 "accept refuses evidence older than a gated follow-up" -- env HOME="$FAKEHOME" "$PS" accept --id m1
grep -q "recorded before the last gated worker" "$WS/err" && ok || bad "a follow-up moves the stale-evidence line: $(head -1 "$WS/err")"
sleep 1; rewalk
expect 0 "accept m1" -- env HOME="$FAKEHOME" "$PS" accept --id m1
grep -qE "^next: m2 \(.*\) — ask once: continue now" "$WS/out" && ok || bad "accept prints the next runnable milestone and the interactive rule: $(grep next "$WS/out")"
grep -qE "^sized M · actual: 4 gated dispatches \(2 worker/follow-up\)" "$WS/out" && ok || bad "accept prints sized vs actual: $(grep sized "$WS/out")"
grep -q "same file" "$WS/err" && bad "distinct evidence files drew the one-file WARN" || ok
grep -q "no gated reviewer" "$WS/err" && bad "a gated reviewer exists yet the no-reviewer WARN fired" || ok
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
"$PS" status > "$WS/out"; grep -q "model: opus" "$WS/out" && grep -qE "^m1	[a-z]+	feature	M	" "$WS/out" && ok || bad "status shows the model tier and each milestone's size: $(head -4 "$WS/out")"
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
mkdir -p "$SD/milestones/m1/dispatch"; wprompt "$SD/milestones/m1/dispatch/1.md" "$STACKSK" "$TESTSK"
env HOME="$FAKEHOME" "$PS" dispatch check "$SD/milestones/m1/dispatch/1.md" --milestone m1 >/dev/null 2>&1 || bad "hands-off worker dispatch gates"
for k in tests browser-happy browser-error viewport:mobile viewport:tablet viewport:desktop console-clean keyboard motion; do
  "$PS" evidence add --id m1 --kind "$k" --note n --file "$WS/console.txt" >/dev/null
done
expect 2 "hands-off accept refused without ASSUMED decision" -- env HOME="$FAKEHOME" "$PS" accept --id m1
grep -q "ASSUMED" "$WS/err" && ok || bad "refusal names ASSUMED"
"$PS" decision add --assumed --text a --alternative b --rationale c >/dev/null
expect 0 "hands-off accept passes with ASSUMED decision" -- env HOME="$FAKEHOME" "$PS" accept --id m1
grep -qE "^next: none runnable — program.sh close" "$WS/out" && ok || bad "hands-off accept with nothing left prints the close hint: $(grep next "$WS/out")"
grep -q "every evidence row points at the same file" "$WS/err" && ok || bad "nine kinds behind one file draws the WARN: $(cat "$WS/err")"
grep -q "no gated reviewer dispatch" "$WS/err" && ok || bad "no reviewer dispatch draws the WARN"
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
printf 'Do the thing.\nVERIFY: make test\n' > "$WS/p1.md"
expect 2 "dispatch check refuses bare prompt" -- "$PS" dispatch check "$WS/p1.md"
grep -q "preamble clause" "$WS/err" && grep -q "TOUCH ONLY" "$WS/err" && grep -q "skill pinned" "$WS/err" && ok || bad "dispatch check names every miss"
{ cat "$PRE"; printf 'TOUCH ONLY: %s/a.php\nREAD FIRST: %s/skills/x/SKILL.md\nVERIFY: make test\n' "$WS" "$WS"; } > "$WS/p2-nomodel.md"
expect 2 "dispatch check refuses a prompt with no MODEL: line" -- "$PS" dispatch check "$WS/p2-nomodel.md"
grep -q "no MODEL: line" "$WS/err" && ok || bad "refusal names the missing MODEL line"
{ cat "$WS/p2-nomodel.md"; printf 'MODEL: opus\n'; } > "$WS/p2.md"
expect 0 "dispatch check passes complete prompt" -- "$PS" dispatch check "$WS/p2.md"
{ cat "$WS/p2-nomodel.md"; printf 'MODEL: inherit\n'; } > "$WS/p2-inherit.md"
expect 2 "tier opus refuses MODEL: inherit" -- "$PS" dispatch check "$WS/p2-inherit.md"
grep -q "above the program tier 'opus'" "$WS/err" && ok || bad "refusal names the tier"
{ cat "$WS/p2-nomodel.md"; printf 'MODEL: sonnet\n'; } > "$WS/p2-sonnet.md"
expect 0 "tier opus allows a model below opus" -- "$PS" dispatch check "$WS/p2-sonnet.md"
# tier auto: a seat may inherit the session model — a separate program, initialised with --model auto
W5=$(mktemp -d); git -C "$W5" init -q -b main 2>/dev/null || git -C "$W5" init -q
OVERSEER_ROOT="$W5" "$PS" init --goal g --slug g --model auto >/dev/null 2>&1
[ "$(jq -r .model "$W5/.claude/overseer/program.json")" = "auto" ] && ok || bad "init stores --model auto"
expect 2 "tier auto still refuses MODEL: inherit on a worker" -- env OVERSEER_ROOT="$W5" "$PS" dispatch check "$WS/p2-inherit.md"
grep -q "for a worker seat" "$WS/err" && ok || bad "refusal says the seat, not only the tier: $(cat "$WS/err")"
{ cat "$PRE"; printf 'READ FIRST: %s/skills/x/SKILL.md\nYou WRITE NO FILES.\nRETURN (max 40 lines): a document\nMODEL: inherit\n' "$WS"; } > "$WS/p5-inherit.md"
expect 0 "tier auto allows MODEL: inherit on a reader" -- env OVERSEER_ROOT="$W5" "$PS" dispatch check "$WS/p5-inherit.md" --kind reader
OVERSEER_ROOT="$W5" "$PS" status | grep -q "model: auto" && ok || bad "status shows model: auto"
rm -rf "$W5"
sed 's/one change per step/one change per step, roughly/' "$WS/p2.md" > "$WS/p3.md"
expect 2 "dispatch check refuses a reworded clause" -- "$PS" dispatch check "$WS/p3.md"
sed 's/an out-of-set edit reclaims the card/an out-of-set edit is fine/' "$WS/p2.md" > "$WS/p3b.md"
expect 2 "dispatch check refuses a reworded SECOND line of a clause" -- "$PS" dispatch check "$WS/p3b.md"
grep -q "preamble clause 4" "$WS/err" && ok || bad "refusal names the clause: $(cat "$WS/err")"
awk 'NR==5{printf "%s ", $0; next} NR==6{sub(/^ +/, ""); print; next} {print}' "$WS/p2.md" > "$WS/p3c.md"
expect 0 "a reflowed clause (same words, one line) still passes" -- "$PS" dispatch check "$WS/p3c.md"
sed "s#$WS/skills/x/SKILL.md#/nonexistent/SKILL.md#" "$WS/p2.md" > "$WS/p4.md"
expect 2 "dispatch check refuses a skill path that does not exist" -- "$PS" dispatch check "$WS/p4.md"
expect 3 "dispatch check on missing file" -- "$PS" dispatch check "$WS/nope.md"
# reader kind: no scope/verify needed, RETURN + "write no file" needed
{ cat "$PRE"; printf 'READ FIRST: %s/skills/x/SKILL.md\nYou WRITE NO FILES.\nRETURN (max 40 lines): a document\nMODEL: opus\n' "$WS"; } > "$WS/p5.md"
expect 0 "dispatch check --kind reader passes a read-only prompt" -- "$PS" dispatch check "$WS/p5.md" --kind reader
expect 2 "dispatch check (worker) refuses the same read-only prompt" -- "$PS" dispatch check "$WS/p5.md"
{ cat "$PRE"; printf 'READ FIRST: %s/skills/x/SKILL.md\nRETURN: findings\n' "$WS"; } > "$WS/p6.md"
expect 2 "dispatch check --kind reviewer needs the read-only statement" -- "$PS" dispatch check "$WS/p6.md" --kind reviewer
expect 2 "dispatch check rejects an unknown kind" -- "$PS" dispatch check "$WS/p2.md" --kind boss
# the preamble is worker discipline: a reviewer/reader prompt carries none (0.3.2 — the gate used to demand "run the
# full check suite" verbatim in a prompt that also had to say "you write no file"); the SKILL's reviewer template is the fixture
printf 'Review the diff `git diff main...ov/m1` against %s/skills/x/SKILL.md.\nYou are read-only: you write no file and run no command that changes the tree.\nMODEL: opus\nOne line per finding. RETURN `CLEAN` when none.\n' "$WS" > "$WS/p7r.md"
expect 0 "dispatch check --kind reviewer passes the SKILL's template with no preamble" -- "$PS" dispatch check "$WS/p7r.md" --kind reviewer
expect 0 "dispatch check --kind reader passes with no preamble" -- "$PS" dispatch check "$WS/p7r.md" --kind reader
expect 2 "dispatch check (worker) still refuses a prompt with no preamble" -- "$PS" dispatch check "$WS/p7r.md"
grep -q "preamble clause" "$WS/err" && ok || bad "worker refusal names the preamble"
# followup kind: a message to a live worker — no preamble text, but it must say the preamble binds,
# keep TOUCH ONLY / VERIFY / RETURN and name the dispatch file it continues
printf 'Fix cycle 3 — same preamble and rules as your card %s/dispatch/3-fix-1.md; same TOUCH ONLY set plus b.php; same VERIFY; same RETURN shape.\n1. do x\n' "$WS" > "$WS/p8.md"
expect 0 "dispatch check --kind followup passes a complete follow-up" -- "$PS" dispatch check "$WS/p8.md" --kind followup
expect 2 "dispatch check (worker) refuses the same follow-up (no preamble text)" -- "$PS" dispatch check "$WS/p8.md"
printf 'Fix cycle 3 — three more items, same TOUCH ONLY, same VERIFY, same RETURN.\n1. do x\n' > "$WS/p9.md"
expect 2 "dispatch check --kind followup refuses one that neither names the preamble nor the dispatch file" -- "$PS" dispatch check "$WS/p9.md" --kind followup
grep -q "preamble still applies" "$WS/err" && grep -q "dispatch file it continues" "$WS/err" && ok || bad "followup refusal names both misses"
# --milestone: WARN per unpinned group of the milestone's kind; uninstalled group is a different WARN
"$PS" milestone add --id m4 --title Board --branch ov/m4 --kind board >/dev/null 2>&1
expect 0 "dispatch check --milestone passes with warnings" -- env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m4
grep -q "kind board" "$WS/err" && grep -q "not installed" "$WS/err" && ok || bad "kind WARNs name the kind and the uninstalled groups: $(head -3 "$WS/err")"
grep -q "m4 has no rigour profile" "$WS/err" && ok || bad "an unset rigour WARNs on every gated dispatch: $(grep rigour "$WS/err")"
# size routes the pipeline: an M milestone with no taskmaster index registered after it that names it WARNs on a direct worker; S does not
grep -q "size M: m4 is briefed to taskmaster" "$WS/err" && ok || bad "direct worker on an M milestone WARNs about the skipped pipeline: $(grep size "$WS/err")"
mkdir -p "$SD/milestones/m4"; printf 'brief' > "$SD/milestones/m4/brief.md"; sleep 1; mkdir -p "$SD/../../taskmaster-docs/tasks/2026-09-12-m40-other"; printf '# m40 other\n' > "$SD/../../taskmaster-docs/tasks/2026-09-12-m40-other/00-INDEX.md"
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m4 2> "$WS/err" >/dev/null
grep -q "size M" "$WS/err" && ok || bad "a newer index for ANOTHER milestone (m40) must not cover m4"
mkdir -p "$SD/../../taskmaster-docs/tasks/2026-09-12-landing"; printf '# m4 landing — task index\n' > "$SD/../../taskmaster-docs/tasks/2026-09-12-landing/00-INDEX.md"
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m4 2> "$WS/err" >/dev/null
grep -q "size M" "$WS/err" && bad "index registered after m4 whose heading names m4 still WARNs" || ok
grep -q "marker" "$WS/err" && bad "an index without a marker on an unset-rigour milestone draws a marker WARN" || ok
touch "$SD/milestones/m4/brief.md"
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m4 2> "$WS/err" >/dev/null
grep -q "size M" "$WS/err" && bad "amending the brief after the index must not revive the pipeline-skipped WARN" || ok
# rigour vs the index marker: a boosted index on a lean/standard milestone WARNs; an unboosted one on adversarial WARNs
"$PS" milestone set --id m4 --rigour standard --reason "one novel signal" >/dev/null
printf '# m4 landing — task index\n\nUltra: true (model=auto, effort=xhigh)\nGoal: true (model=auto, effort=xhigh)\n' > "$SD/../../taskmaster-docs/tasks/2026-09-12-landing/00-INDEX.md"
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m4 2> "$WS/err" >/dev/null
# this program is hands-off (init Third above): the WARN names the residual, not a wrong token
grep -q "brief /taskmaster:task goal-lean" "$WS/err" && ok || bad "boosted index on a standard hands-off milestone points at goal-lean: $(grep -i rigour "$WS/err")"
printf '# m4 landing — task index\n\nGoal: true (boost=off) — requires task-runner >=0.32.0\n' > "$SD/../../taskmaster-docs/tasks/2026-09-12-landing/00-INDEX.md"
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m4 2> "$WS/err" >/dev/null
grep -q "marker" "$WS/err" && bad "a Goal: boost=off index on a standard milestone must not WARN" || ok
grep -q "briefed to taskmaster" "$WS/err" && bad "a Goal: boost=off index still proves the pipeline ran" || ok
printf '# m4 landing — task index\n\nUltra: true (model=auto, effort=xhigh)\nGoal: true (model=auto, effort=xhigh)\n' > "$SD/../../taskmaster-docs/tasks/2026-09-12-landing/00-INDEX.md"
W6=$(mktemp -d); git -C "$W6" init -q -b main 2>/dev/null || git -C "$W6" init -q
OVERSEER_ROOT="$W6" "$PS" init --goal g --slug g >/dev/null 2>&1; OVERSEER_ROOT="$W6" "$PS" milestone add --id m1 --title t --branch b --rigour standard >/dev/null
mkdir -p "$W6/taskmaster-docs/tasks/2026-09-12-m1-x"; printf '# m1 x\nUltra: true (model=auto, effort=xhigh)\n' > "$W6/taskmaster-docs/tasks/2026-09-12-m1-x/00-INDEX.md"
env HOME="$FAKEHOME" OVERSEER_ROOT="$W6" "$PS" dispatch check "$WS/p2.md" --milestone m1 2> "$WS/err" >/dev/null
grep -q "code red-team was bought where the profile says not to" "$WS/err" && ok || bad "boosted index on a standard interactive milestone WARNs: $(grep -i rigour "$WS/err")"
rm -rf "$W6"
grep -q "briefed to taskmaster" "$WS/err" && bad "the marker WARN must not also claim the pipeline was skipped" || ok
grep -q "no rigour profile" "$WS/err" && bad "a set rigour still draws the unset WARN" || ok
"$PS" milestone set --id m4 --rigour adversarial --reason "money maths" >/dev/null
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m4 2> "$WS/err" >/dev/null
grep -q "marker" "$WS/err" && bad "boosted index on an adversarial milestone must not WARN" || ok
printf '# m4 landing — task index\n' > "$SD/../../taskmaster-docs/tasks/2026-09-12-landing/00-INDEX.md"
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m4 2> "$WS/err" >/dev/null
grep -q "carries no Ultra: marker" "$WS/err" && ok || bad "unboosted index on an adversarial milestone WARNs: $(grep -i marker "$WS/err")"
printf '# m4 landing — task index\n\nGoal: true (boost=off)\n' > "$SD/../../taskmaster-docs/tasks/2026-09-12-landing/00-INDEX.md"
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m4 2> "$WS/err" >/dev/null
grep -q "never goal-lean" "$WS/err" && ok || bad "a Goal: boost=off index on an adversarial milestone WARNs: $(grep -i marker "$WS/err")"
rm -rf "$SD/../../taskmaster-docs"
"$PS" milestone add --id m5 --title Small --branch ov/m5 --size S >/dev/null 2>&1
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m5 2> "$WS/err" >/dev/null
grep -q "size S" "$WS/err" && bad "an S milestone WARNs on a direct worker" || ok
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p5.md" --kind reader --milestone m4 2> "$WS/err" >/dev/null
grep -q "briefed to taskmaster" "$WS/err" && bad "a reader dispatch draws the size WARN" || ok
"$PS" milestone add --id m7 --title Login --branch ov/m7 --kind auth --rigour lean >/dev/null 2>&1
env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m7 2> "$WS/err" >/dev/null
grep -q "kind auth is never lean" "$WS/err" && ok || bad "a lean surface kind WARNs: $(grep -i lean "$WS/err")"
# a file under milestones/<id>/dispatch/ names its milestone without --milestone, and is recorded in .gated
mkdir -p "$SD/milestones/m5/dispatch"; cp "$WS/p2.md" "$SD/milestones/m5/dispatch/9.md"
expect 0 "dispatch check derives the milestone from the file's path" -- env HOME="$FAKEHOME" "$PS" dispatch check "$SD/milestones/m5/dispatch/9.md"
grep -q "m5 has no rigour profile" "$WS/err" && ok || bad "path-derived milestone draws the milestone WARNs: $(cat "$WS/err")"
grep -qE "^[0-9]+ worker 9\.md$" "$SD/milestones/m5/dispatch/.gated" && ok || bad "path-derived dispatch is recorded in .gated"
[ ! -f "$WS/.gated" ] && ok || bad "a prompt outside a dispatch dir is not recorded"
expect 2 "dispatch check --milestone unknown id" -- "$PS" dispatch check "$WS/p2.md" --milestone m77
# dense card WARN: the fixture preamble clauses + 20 items
{ cat "$WS/p2.md"; for i in $(seq 1 20); do printf '%s. do thing %s\n' "$i" "$i"; done; } > "$WS/p10.md"
expect 0 "dense card still passes" -- "$PS" dispatch check "$WS/p10.md"
grep -q "dense card" "$WS/err" && ok || bad "dense card WARN"
expect 0 "twelve items is not dense" -- "$PS" dispatch check "$WS/p2.md"
grep -q "dense card" "$WS/err" && bad "false dense WARN on a normal card" || ok
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
# CLI route: the list carries every project's rows; only THIS project's (or a user-scope) row may win
FAKEBIN=$(mktemp -d); mkdir -p "$FAKEHOME/here" "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.10.0/skills/s"; printf x > "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.10.0/skills/s/SKILL.md"
cat > "$FAKEBIN/claude" <<EOS
#!/bin/sh
cat <<'J'
[{"id":"pl@mkt","version":"0.10.0","scope":"local","enabled":true,"installPath":"$FAKEHOME/.claude/plugins/cache/mkt/pl/0.10.0","projectPath":"$FAKEHOME/elsewhere"},
 {"id":"pl@mkt","version":"0.9.0","scope":"local","enabled":true,"installPath":"$FAKEHOME/.claude/plugins/cache/mkt/pl/0.9.0","projectPath":"$FAKEHOME/here"},
 {"id":"pl@mkt","version":"0.2.0","scope":"user","enabled":true,"installPath":"$FAKEHOME/.claude/plugins/cache/mkt/pl/0.2.0"}]
J
EOS
chmod +x "$FAKEBIN/claude"; JQDIR=$(dirname "$(command -v jq)")
got=$(HOME="$FAKEHOME" PATH="$FAKEBIN:$JQDIR:/usr/bin:/bin" bash "$SP" pl s --project "$FAKEHOME/here" 2>/dev/null)
[ "$got" = "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.9.0/skills/s/SKILL.md" ] && ok || bad "skill-path CLI route picks THIS project's row (0.9.0), not another project's newer 0.10.0: $got"
got=$(cd "$FAKEHOME/here" && HOME="$FAKEHOME" PATH="$FAKEBIN:$JQDIR:/usr/bin:/bin" bash "$SP" pl s 2>/dev/null)
[ "$got" = "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.9.0/skills/s/SKILL.md" ] && ok || bad "skill-path CLI route resolves the project from the cwd: $got"
got=$(cd "$FAKEHOME" && HOME="$FAKEHOME" PATH="$FAKEBIN:$JQDIR:/usr/bin:/bin" bash "$SP" pl s 2>/dev/null)
[ "$got" = "$FAKEHOME/.claude/plugins/cache/mkt/pl/0.2.0/skills/s/SKILL.md" ] && ok || bad "skill-path CLI route falls to the user-scope row outside any listed project, never another project's: $got"
rm -rf "$FAKEHOME" "$FAKEBIN"

# ---- capability-scan: CI mismatch, no unknown sentinel ------------------------------------------
W3=$(mktemp -d); git -C "$W3" init -q -b master 2>/dev/null || git -C "$W3" init -q
mkdir -p "$W3/.github/workflows"; printf 'on:\n  push:\n    branches: [main]\n  pull_request:\n    branches: [main]\njobs: {}\n' > "$W3/.github/workflows/tests.yml"
out=$(PATH=/usr/bin:/bin HOME="$W3" "$SCAN" --root "$W3" 2>/dev/null)
printf '%s' "$out" | grep -q "does not trigger on base 'master'" && ok || bad "scan flags CI branch mismatch: $out"
printf '%s' "$out" | grep "^# install" | grep -q "playwright" && bad "scan still lists playwright as installable" || ok
js=$(PATH=/usr/bin:/bin HOME="$W3" "$SCAN" --root "$W3" --json 2>/dev/null)
printf '%s' "$js" | jq -e '(.phases|map(.installed[])|index("unknown"))==null and .cli_available==false and (.ci[0].triggers_on_base==false)' >/dev/null && ok || bad "scan --json: no unknown, ci parsed: $js"
rm -rf "$W3"

# ---- session-root gate ------------------------------------------------------------------------
SESS=deadbeef-0000; ENC_OTHER="-Users-someone-other-project"; ENC_HERE=$(printf '%s' "$WS" | sed 's#[^A-Za-z0-9]#-#g')
mkdir -p "$FAKEHOME/.claude/projects/$ENC_OTHER"; printf '{}\n' > "$FAKEHOME/.claude/projects/$ENC_OTHER/$SESS.jsonl"
rm -f "$SD/program.json"
expect 2 "init refused from a session opened in another project" -- env HOME="$FAKEHOME" CLAUDE_CODE_SESSION_ID="$SESS" "$PS" init --goal g --slug g
grep -q "transcript dir -Users-someone-other-project" "$WS/err" && grep -q "foreign-session" "$WS/err" && ok || bad "refusal names the session's project and the override: $(head -2 "$WS/err")"
expect 0 "init with --foreign-session records the reason" -- env HOME="$FAKEHOME" CLAUDE_CODE_SESSION_ID="$SESS" "$PS" init --goal g --slug g --foreign-session "simulation from the marketplace"
[ "$(jq -r .foreign_session_reason "$SD/program.json")" = "simulation from the marketplace" ] && ok || bad "foreign reason stored"
"$PS" milestone add --id m1 --title t --branch b >/dev/null
expect 0 "dispatch check --milestone on a foreign program passes with a WARN" -- env HOME="$FAKEHOME" "$PS" dispatch check "$WS/p2.md" --milestone m1
grep -q "foreign session" "$WS/err" && ok || bad "foreign session WARN on dispatch"
rm -f "$SD/program.json"; mkdir -p "$FAKEHOME/.claude/projects/$ENC_HERE"; printf '{}\n' > "$FAKEHOME/.claude/projects/$ENC_HERE/$SESS.jsonl"; rm -rf "$FAKEHOME/.claude/projects/$ENC_OTHER"
expect 0 "init allowed when the session's project is this root" -- env HOME="$FAKEHOME" CLAUDE_CODE_SESSION_ID="$SESS" "$PS" init --goal g --slug g
expect 0 "init fail-open when the session id has no transcript" -- env HOME="$FAKEHOME" CLAUDE_CODE_SESSION_ID="unknown-id" "$PS" init --goal g --slug g

# ---- history, log, suggestions, close divergence, plugins-used ----------------------------------
W2=$(mktemp -d); git -C "$W2" init -q -b main 2>/dev/null || git -C "$W2" init -q
git -C "$W2" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
git -C "$W2" branch ov/a; git -C "$W2" branch ov/b
git -C "$W2" -c user.email=t@t -c user.name=t commit -q --allow-empty -m tip-a && git -C "$W2" branch -f ov/a HEAD && git -C "$W2" checkout -q main
git -C "$W2" checkout -q ov/b && git -C "$W2" -c user.email=t@t -c user.name=t commit -q --allow-empty -m tip-b && git -C "$W2" checkout -q main
P2() { env OVERSEER_ROOT="$W2" "$PS" "$@"; }
P2 init --goal g2 --slug g2 >/dev/null
expect 0 "add a (board)" -- env OVERSEER_ROOT="$W2" "$PS" milestone add --id m1 --title A --branch ov/a --kind board
expect 0 "add b" -- env OVERSEER_ROOT="$W2" "$PS" milestone add --id m2 --title B --branch ov/b
[ "$(jq -r '.milestones[0].history[0].status' "$W2/.claude/overseer/program.json")" = queued ] && ok || bad "history starts at queued"
P2 milestone set --id m1 --status building >/dev/null; P2 milestone set --id m2 --status building >/dev/null
jq -e '.milestones[0].history|length==2 and .[1].status=="building"' "$W2/.claude/overseer/program.json" >/dev/null && ok || bad "history records set"
expect 0 "suggestion add" -- env OVERSEER_ROOT="$W2" "$PS" suggestion add --text "pagination on the index" --from m1
grep -q "pagination on the index" "$W2/.claude/overseer/suggestions.md" && ok || bad "suggestion row written"
expect 0 "log" -- env OVERSEER_ROOT="$W2" "$PS" log
grep -q "status → building" "$WS/out" && grep -q "suggestion" "$WS/out" && head -1 "$WS/out" | grep -q "^at" && ok || bad "log lists status changes and suggestions in order: $(head -3 "$WS/out")"
P2 decision add --text "keep vanilla css" --rationale "one screen" >/dev/null
expect 0 "log again" -- env OVERSEER_ROOT="$W2" "$PS" log
grep -qE "^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9:]+Z	-	decision keep vanilla css$" "$WS/out" && grep -qE "^20[0-9]{2}-[^	]+	m1	suggestion pagination on the index$" "$WS/out" && ok || bad "log parses decision and suggestion rows into at/milestone/event: $(grep -E 'decision|suggestion' "$WS/out")"
# force both done through the state file (accept needs nine evidence files; the divergence gate is what is under test)
jq '(.milestones[]) |= (.status="done" | .history = [{status:"queued",at:"2026-01-01T00:00:00Z"},{status:"building",at:"2026-01-01T00:05:00Z"},{status:"done",at:"2026-01-01T01:00:00Z"}])' "$W2/.claude/overseer/program.json" > "$W2/pj" && mv "$W2/pj" "$W2/.claude/overseer/program.json"
expect 0 "status shows wall time" -- env OVERSEER_ROOT="$W2" "$PS" status
grep -q "55 min" "$WS/out" && ok || bad "wall column (want 55 min): $(sed -n 4,6p "$WS/out")"
expect 2 "close refuses divergent done branches" -- env OVERSEER_ROOT="$W2" "$PS" close
grep -q "ov/a<->ov/b" "$WS/err" && grep -q "integration" "$WS/err" && ok || bad "refusal names the pair and the integration route: $(head -2 "$WS/err")"
printf 'phase\tinstalled\tmissing\nbuild\tlaravel,ui-ux,testing\t-\nreview\tcode-review\t-\n' > "$W2/.claude/overseer/capabilities.tsv"
mkdir -p "$W2/.claude/overseer/milestones/m1/dispatch/.claude/candor"; printf 'READ: /x/.claude/plugins/cache/mkt/ui-ux/1.0.0/skills/a11y-audit/SKILL.md\nAGENT: code-review:code-reviewer\n' > "$W2/.claude/overseer/milestones/m1/dispatch/1.md"; printf 'x' > "$W2/.claude/overseer/milestones/m1/dispatch/.claude/candor/last"
expect 0 "close --divergent-ok passes and records" -- env OVERSEER_ROOT="$W2" "$PS" close --divergent-ok "user merges after review"
grep -q "closed with divergent done branches" "$W2/.claude/overseer/decisions.md" && ok || bad "divergent-ok decision row"
grep -q "installed per the scan: 4" "$WS/out" && grep -q "pinned in a dispatch: 2" "$WS/out" && grep -q "never pinned: laravel testing" "$WS/out" && ok || bad "plugins-used line counts AGENT lines too: $(grep 'plugins' "$WS/out")"
[ ! -d "$W2"/.claude/overseer/archive/g2-*/milestones/m1/dispatch/.claude ] && ok || bad "foreign hook scratch dirs pruned from the archive"
grep -q "deferred suggestions (1)" "$WS/out" && grep -qx "  m1: pagination on the index" "$WS/out" && ok || bad "suggestions printed at close without a trailing pipe: $(grep -A1 'deferred' "$WS/out")"
ls "$W2"/.claude/overseer/archive/g2-*/suggestions.md >/dev/null 2>&1 && ok || bad "suggestions.md archived"
# integration kind lifts the gate
P2 init --goal g3 --slug g3 >/dev/null
P2 milestone add --id m1 --title A --branch ov/a >/dev/null; P2 milestone add --id m2 --title B --branch ov/b >/dev/null; P2 milestone add --id m3 --title I --branch main --kind integration >/dev/null
jq '(.milestones[]) |= (.status="done")' "$W2/.claude/overseer/program.json" > "$W2/pj" && mv "$W2/pj" "$W2/.claude/overseer/program.json"
expect 0 "close passes with a done integration milestone" -- env OVERSEER_ROOT="$W2" "$PS" close
rm -rf "$W2"

# ---- a project root with a space (0.3.2: word-split file lists and a space-free pin regex made accept impossible) ----
W8="$(mktemp -d)/my proj"; mkdir -p "$W8/.claude/skills/stacky"; printf 'x' > "$W8/.claude/skills/stacky/SKILL.md"
git -C "$W8" init -q -b main 2>/dev/null || git -C "$W8" init -q
env OVERSEER_ROOT="$W8" "$PS" init --goal g --slug g >/dev/null 2>&1
env OVERSEER_ROOT="$W8" "$PS" milestone add --id m1 --title t --branch ov/m1 --rigour standard >/dev/null 2>&1; env OVERSEER_ROOT="$W8" "$PS" milestone set --id m1 --status building >/dev/null 2>&1
S8="$W8/.claude/overseer/milestones/m1/dispatch"; mkdir -p "$S8"
{ cat "$PRE"; printf 'TOUCH ONLY: %s/a.php\nREAD FIRST: %s/.claude/skills/stacky/SKILL.md\nREAD FIRST: %s\nVERIFY: make test\nMODEL: opus\n' "$W8" "$W8" "$TESTSK"; } > "$S8/1.md"
expect 0 "dispatch check pins a project skill under a path with a space" -- env OVERSEER_ROOT="$W8" HOME="$FAKEHOME" "$PS" dispatch check "$S8/1.md" --kind worker --milestone m1
grep -q "no gated dispatch for m1 pins" "$WS/err" && bad "spaced root: kind groups read from the gated file: $(cat "$WS/err")" || ok
{ printf 'READ FIRST: %s/.claude/skills/stacky/SKILL.md\nYou WRITE NO FILES.\nRETURN: findings\nMODEL: opus\n' "$W8"; } > "$S8/2-review-x.md"
env OVERSEER_ROOT="$W8" HOME="$FAKEHOME" "$PS" dispatch check "$S8/2-review-x.md" --kind reviewer >/dev/null 2>&1
sleep 1
for k in tests browser-happy browser-error viewport:mobile viewport:tablet viewport:desktop keyboard motion console-clean; do
  f="$W8/$k.txt"; mkfile "$f"; env OVERSEER_ROOT="$W8" "$PS" evidence add --id m1 --kind "$k" --note n --file "$f" >/dev/null 2>&1; done
expect 0 "accept passes under a project root with a space" -- env OVERSEER_ROOT="$W8" HOME="$FAKEHOME" "$PS" accept --id m1
rm -rf "$(dirname "$W8")"

# ---- evidence profiles: a milestone kind with no screen (kinds.tsv column 4) --------------------
# the required evidence set used to be one global list of nine browser kinds, so an audit, research
# or CLI/library milestone could never satisfy accept — there is no viewport to walk — and every one
# of them ended parked. accept now reads the required set from the milestone kind's profile.
W9=$(mktemp -d); git -C "$W9" init -q -b main 2>/dev/null || git -C "$W9" init -q
mkdir -p "$W9/.claude/skills/proj"; printf 'x' > "$W9/.claude/skills/proj/SKILL.md"
PROJSK="$W9/.claude/skills/proj/SKILL.md"; S9="$W9/.claude/overseer"
# the home whose plugin cache holds the testing skill fixture: an uninstalled group is a WARN,
# so the library case below can only prove its REFUSAL with testing installed and unpinned
H9="${TESTSK%%/.claude/plugins/*}"
P9() { env OVERSEER_ROOT="$W9" HOME="$H9" "$PS" "$@"; }
P9 init --goal "audit this repo" --slug prof >/dev/null 2>&1
expect 0 "milestone add --kind audit" -- P9 milestone add --id m1 --title "Gate audit" --branch ov/m1 --kind audit --size S
expect 0 "milestone add --kind library" -- P9 milestone add --id m2 --title "CLI flag" --branch ov/m2 --kind library --size S
P9 milestone set --id m1 --status building >/dev/null
expect 2 "accept refuses a headless milestone with no evidence" -- P9 accept --id m1
grep -q "evidence profile headless" "$WS/err" && grep -q "run-log" "$WS/err" && ok || bad "the refusal names the profile and run-log: $(head -1 "$WS/err")"
grep -qE "viewport|browser-happy|keyboard" "$WS/err" && bad "a headless milestone was asked for browser evidence: $(head -1 "$WS/err")" || ok
expect 2 "run-log is a file kind: no --file is refused" -- P9 evidence add --id m1 --kind run-log --note "ran it"
expect 2 "run-log --file must exist" -- P9 evidence add --id m1 --kind run-log --note "ran it" --file "$W9/nope.txt"
: > "$W9/empty.log"
expect 2 "run-log --file must be non-empty" -- P9 evidence add --id m1 --kind run-log --note "ran it" --file "$W9/empty.log"
mkdir -p "$S9/milestones/m1/dispatch"; wprompt "$S9/milestones/m1/dispatch/1.md" "$PROJSK"
expect 0 "audit worker dispatch gates on the stack pin alone" -- P9 dispatch check "$S9/milestones/m1/dispatch/1.md" --kind worker --milestone m1
sleep 1; mkfile "$W9/suite.txt"; mkfile "$W9/run.txt"
expect 0 "evidence add --kind run-log" -- P9 evidence add --id m1 --kind run-log --note "./gate.sh --check, exit 0" --file "$W9/run.txt"
expect 0 "evidence add --kind tests on a headless milestone" -- P9 evidence add --id m1 --kind tests --note "suite + lint" --file "$W9/suite.txt"
expect 0 "accept closes an audit milestone on tests + run-log alone" -- P9 accept --id m1
grep -q "testing:testing-best-practices" "$WS/err" && bad "kind audit demanded a testing pin it does not declare: $(head -1 "$WS/err")" || ok
grep -q "same file" "$WS/err" && bad "two distinct files drew the one-file WARN" || ok
jq -e '.milestones[]|select(.id=="m1")|.status=="done"' "$S9/program.json" >/dev/null && ok || bad "the audit milestone is done"
# library is headless too, but its row declares the testing group: the evidence set and the skill
# groups are separate gates, and a headless profile lifts neither
P9 milestone set --id m2 --status building >/dev/null
mkdir -p "$S9/milestones/m2/dispatch"; wprompt "$S9/milestones/m2/dispatch/1.md" "$PROJSK"
P9 dispatch check "$S9/milestones/m2/dispatch/1.md" --kind worker --milestone m2 >/dev/null 2>&1
sleep 1
P9 evidence add --id m2 --kind tests --note "suite" --file "$W9/suite.txt" >/dev/null 2>&1
P9 evidence add --id m2 --kind run-log --note "npx tool --help" --file "$W9/run.txt" >/dev/null 2>&1
expect 2 "a library milestone with both evidence kinds still needs its testing pin" -- P9 accept --id m2
grep -q "testing:testing-best-practices" "$WS/err" && ok || bad "the unpinned group is named on a headless kind too: $(head -1 "$WS/err")"
rprompt "$S9/milestones/m2/dispatch/2-review.md" "$TESTSK"
P9 dispatch check "$S9/milestones/m2/dispatch/2-review.md" --kind reviewer --milestone m2 >/dev/null 2>&1
expect 0 "accept closes a library milestone once the testing group is pinned" -- P9 accept --id m2
# the headless set does not leak into a kind that HAS a screen
expect 0 "add a feature milestone" -- P9 milestone add --id m3 --title "Clients list" --branch ov/m3 --kind feature --size S
P9 milestone set --id m3 --status building >/dev/null
expect 0 "run-log is recordable on a ui-profile milestone" -- P9 evidence add --id m3 --kind run-log --note "artisan test" --file "$W9/run.txt"
P9 evidence add --id m3 --kind tests --note "suite" --file "$W9/suite.txt" >/dev/null 2>&1
expect 2 "a feature milestone is still refused without the browser evidence" -- P9 accept --id m3
grep -q "evidence profile ui" "$WS/err" && grep -q "browser-happy" "$WS/err" && grep -q "viewport:mobile" "$WS/err" && grep -q "motion" "$WS/err" && ok || bad "the ui profile still demands the nine: $(head -1 "$WS/err")"
grep -q " run-log" "$WS/err" && bad "run-log was demanded of a ui-profile milestone" || ok
# run-log is a FILE kind, so the read-before-record gate covers it like any screenshot: a captured
# run nobody opened proves as little as a screenshot nobody opened
mkfile "$W9/unread.log"
payload s9 "$W9" "$W9/run.txt" | bash "$TR"
expect 0 "run-log passes the read gate for a file this session Read" -- env OVERSEER_ROOT="$W9" HOME="$H9" CLAUDE_CODE_SESSION_ID=s9 "$PS" evidence add --id m3 --kind run-log --note "looked" --file "$W9/run.txt"
expect 2 "run-log is refused for a file this session never Read" -- env OVERSEER_ROOT="$W9" HOME="$H9" CLAUDE_CODE_SESSION_ID=s9 "$PS" evidence add --id m3 --kind run-log --note "claimed" --file "$W9/unread.log"
# a profile word kinds.tsv does not define is refused at milestone add — a typo would silently fall
# back to the nine browser kinds, which is the failure this column exists to fix
PLUG="$W9/plug"; mkdir -p "$PLUG/scripts"; cp "$PS" "$PLUG/scripts/program.sh"; cp "$here/../../kinds.tsv" "$PLUG/kinds.tsv"
printf 'ghost\tstack\ta kind whose profile word is a typo\thedless\n' >> "$PLUG/kinds.tsv"
expect 2 "milestone add refuses a kind whose kinds.tsv profile is not a profile" -- env OVERSEER_ROOT="$W9" HOME="$H9" bash "$PLUG/scripts/program.sh" milestone add --id m8 --title t --branch b --kind ghost
grep -q "ui headless" "$WS/err" && ok || bad "the refusal names the known profiles: $(head -1 "$WS/err")"
printf 'ghost2\tstack\ta kind added at runtime with a real profile\theadless\n' >> "$PLUG/kinds.tsv"
expect 0 "a kinds.tsv row carrying a valid profile is accepted (the column is data, not hard-coded)" -- env OVERSEER_ROOT="$W9" HOME="$H9" bash "$PLUG/scripts/program.sh" milestone add --id m9 --title t --branch b --kind ghost2
rm -rf "$W9"

echo "program.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
