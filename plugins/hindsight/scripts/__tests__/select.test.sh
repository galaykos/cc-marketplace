#!/usr/bin/env bash
# Fixture tests for select.sh — ranking, one candidate per transcript, mined and
# missing transcripts dropped, the no-row fallback, --top, --since, --all-projects,
# and --mark on a ledgered and an unledgered transcript. Synthetic HOME throughout.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/select.sh"
export HOME="$(mktemp -d)"; trap 'rm -rf "$HOME"' EXIT
pass=0; fail=0
ok()   { pass=$((pass+1)); }
bad()  { echo "FAIL $1"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok; else bad "$1"; fi; }

proj="/tmp/proj-select"
slug=$(printf '%s' "$proj" | tr -c '[:alnum:]' '-')
tdir="$HOME/.claude/projects/$slug"; mkdir -p "$tdir"
ldir="$HOME/.claude/hindsight/$slug"; mkdir -p "$ldir"
ledger="$ldir/ledger.jsonl"
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

for s in aaaa bbbb cccc ffff; do echo '{"type":"assistant"}' > "$tdir/$s.jsonl"; done
mkdir -p "$tdir/aaaa/subagents"
echo '{"type":"assistant"}' > "$tdir/aaaa/subagents/agent-zz.jsonl"
printf '{"agentType":"code-review:code-reviewer"}\n' > "$tdir/aaaa/subagents/agent-zz.meta.json"

row() { printf '{"v":1,"session_id":"%s","ts_end":"%s","turns":%s,"friction_events":%s,"errors":%s,"transcript_path":"%s","mined":%s}\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7"; }
{
  row aaaa "$now" 2 5 1 "$tdir/aaaa.jsonl" false
  row bbbb "2020-01-01T00:00:00Z" 1 0 0 "$tdir/bbbb.jsonl" false
  echo 'not json at all'
  row bbbb "2020-01-01T00:05:00Z" 4 1 0 "$tdir/bbbb.jsonl" false
  row cccc "$now" 9 9 9 "$tdir/cccc.jsonl" true
  row eeee "$now" 9 9 9 "$tdir/eeee.jsonl" false
} > "$ledger"

out=$(bash "$SCRIPT" --top all "$proj" 2>"$HOME/err")
paths=$(printf '%s\n' "$out" | tail -n +2 | awk -F'\t' '{print $5}')
check "header line"                 'printf "%s\n" "$out" | head -1 | grep -q "^score	kind	agent_type	ts_end	transcript$"'
check "highest score first"         '[ "$(printf "%s\n" "$paths" | sed -n 1p)" = "$tdir/aaaa.jsonl" ]'
check "score is 3f+2e+turns"        'printf "%s\n" "$out" | grep -q "^19	session	-	.*aaaa.jsonl$"'
check "resumed session: one row"    '[ "$(printf "%s\n" "$paths" | grep -c "bbbb.jsonl")" = 1 ]'
check "resumed session: last row"   'printf "%s\n" "$out" | grep -q "^7	session	-	2020-01-01T00:05:00Z	"'
check "mined row dropped"           '! printf "%s\n" "$paths" | grep -q "cccc.jsonl"'
check "missing transcript dropped"  '! printf "%s\n" "$paths" | grep -q "eeee.jsonl"'
check "missing transcript counted"  'grep -q "1 dropped" "$HOME/err"'
check "no-row session is fallback"  'printf "%s\n" "$out" | grep -q "^-	session	-	-	.*ffff.jsonl$"'
check "no-row agent carries type"   'printf "%s\n" "$out" | grep -q "^-	agent	code-review:code-reviewer	-	.*agent-zz.jsonl$"'
check "fallback ranks below ledger" '[ "$(printf "%s\n" "$paths" | sed -n 2p)" = "$tdir/bbbb.jsonl" ]'

out=$(bash "$SCRIPT" --top 1 "$proj" 2>/dev/null)
check "--top 1 prints one candidate" '[ "$(printf "%s\n" "$out" | wc -l | tr -d " ")" = 2 ]'

out=$(bash "$SCRIPT" --top all --since 30 "$proj" 2>/dev/null)
check "--since drops an old row"    '! printf "%s\n" "$out" | grep -q "bbbb.jsonl"'
check "--since keeps a new row"     'printf "%s\n" "$out" | grep -q "aaaa.jsonl"'

# A second project is invisible by default and listed under --all-projects.
other="$HOME/.claude/projects/-tmp-other"; mkdir -p "$other"
echo '{"type":"assistant"}' > "$other/oooo.jsonl"
out=$(bash "$SCRIPT" --top all "$proj" 2>/dev/null)
check "other project not listed"    '! printf "%s\n" "$out" | grep -q "oooo.jsonl"'
out=$(bash "$SCRIPT" --top all --all-projects 2>/dev/null)
check "--all-projects lists it"     'printf "%s\n" "$out" | grep -q "oooo.jsonl"'

# --mark: every row of a ledgered transcript, a new row for an unledgered one, junk kept.
msg=$(bash "$SCRIPT" --mark "$tdir/bbbb.jsonl" "$tdir/ffff.jsonl" "$tdir/aaaa/subagents/agent-zz.jsonl" /elsewhere/x.jsonl 2>"$HOME/err")
check "mark reports the count"      '[ "$msg" = "select: marked 3 transcript(s) mined" ]'
check "mark refuses a foreign path" 'grep -q "not under" "$HOME/err"'
check "both bbbb rows marked"       '[ "$(grep bbbb.jsonl "$ledger" | grep -c "\"mined\":true")" = 2 ]'
check "aaaa row untouched"          'grep "aaaa.jsonl" "$ledger" | grep -q "\"mined\":false"'
check "malformed line preserved"    'grep -qx "not json at all" "$ledger"'
check "unledgered session gets row" 'grep "ffff.jsonl" "$ledger" | grep -q "\"session_id\":\"ffff\".*\"mined\":true"'
check "unledgered agent gets row"   'grep "agent-zz.jsonl" "$ledger" | grep -q "\"kind\":\"agent\".*\"session_id\":\"aaaa\".*\"agent_id\":\"agent-zz\""'
out=$(bash "$SCRIPT" --top all "$proj" 2>/dev/null)
check "marked ones no longer listed" '[ "$(printf "%s\n" "$out" | tail -n +2 | awk -F"\t" "{print \$5}")" = "$tdir/aaaa.jsonl" ]'

# A fork opens with its parent's first message: one candidate, and marking either marks both.
fk="/tmp/proj-fork"; fslug=$(printf '%s' "$fk" | tr -c '[:alnum:]' '-')
fdir="$HOME/.claude/projects/$fslug"; mkdir -p "$fdir"
printf '{"type":"user","uuid":"u-1"}\n{"type":"assistant","uuid":"u-2"}\n' > "$fdir/parent.jsonl"
printf '{"type":"user","uuid":"u-1"}\n' > "$fdir/fork.jsonl"
printf '{"type":"user","uuid":"u-9"}\n' > "$fdir/solo.jsonl"
out=$(bash "$SCRIPT" --top all "$fk" 2>"$HOME/err")
check "fork folded into one row"    '[ "$(printf "%s\n" "$out" | grep -c "parent.jsonl\|fork.jsonl")" = 1 ]'
check "unrelated session kept"      'printf "%s\n" "$out" | grep -q "solo.jsonl"'
check "fold counted on stderr"      'grep -q "1 fork(s) folded" "$HOME/err"'
bash "$SCRIPT" --mark "$fdir/parent.jsonl" >/dev/null 2>&1
fled="$HOME/.claude/hindsight/$fslug/ledger.jsonl"
check "mark reaches the fork"       'grep -q "fork.jsonl" "$fled" && grep -q "parent.jsonl" "$fled"'
check "mark leaves the unrelated"   '! grep -q "solo.jsonl" "$fled"'

# Bad flags and an empty machine exit 0 with nothing ranked.
check "bad --top exits 0"           'bash "$SCRIPT" --top lots "$proj" >/dev/null 2>&1'
check "no data exits 0"             'HOME="$HOME/empty" bash "$SCRIPT" /nowhere >/dev/null 2>&1'

echo "select tests: $pass passed, $fail failed"
[ "$fail" = 0 ]
