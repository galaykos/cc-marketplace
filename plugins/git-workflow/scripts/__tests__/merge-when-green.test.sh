#!/usr/bin/env bash
# Drives merge-when-green.sh against a fake `gh` that answers `pr view` from a queue of recorded rollups (shape of a live
# `gh pr view --json state,headRefOid,statusCheckRollup`, gh 2.46, 2026-11-12): green, pending-then-green, red, no checks, lookup errors, a moved head, refusal.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)" || exit 1; s="$here/merge-when-green.sh"
BASH_BIN="$(command -v bash)"
command -v jq >/dev/null 2>&1 || { printf 'SKIP: jq not installed\n'; exit 0; }
tmp=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
has() { grep -qF -- "$2" <<<"$out" && ok || bad "$1" "missing: $2 in: $out"; }
code() { [ "$rc" -eq "$1" ] && ok || bad "$2: want exit $1, got $rc" "$out"; }
merges() { grep -c '^pr merge' "$FAKE_LOG" 2>/dev/null || true; }

mkdir -p "$tmp/bin" "$tmp/nogh"
cat > "$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_LOG"
case "$1 $2" in
  "pr view") n=$(cat "$FAKE_N" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$FAKE_N"
             total=$(wc -l < "$FAKE_SEQ"); [ "$n" -gt "$total" ] && n=$total
             line=$(sed -n "${n}p" "$FAKE_SEQ")
             [ "$line" = ERR ] && { echo "HTTP 502: Bad Gateway" >&2; exit 1; }
             printf '%s\n' "$line"; exit 0 ;;
  "pr merge") [ "${FAKE_MERGE_RC:-0}" = 0 ] || { echo "Pull request is not mergeable: review required" >&2; exit 1; }
              exit 0 ;;
esac
exit 1
STUB
chmod +x "$tmp/bin/gh"
export FAKE_LOG="$tmp/gh.log" FAKE_SEQ="$tmp/seq" FAKE_N="$tmp/n"

run_check() { jq -cn --arg n "$1" --arg s "$2" --arg c "$3" '{__typename:"CheckRun", name:$n, status:$s, conclusion:$c}'; }
ctx() { jq -cn --arg n "$1" --arg s "$2" '{__typename:"StatusContext", context:$n, state:$s}'; }
# view <state> <sha> <check JSON>…
view() { local st=$1 sha=$2; shift 2; printf '%s\n' "$@" | jq -cs --arg st "$st" --arg sha "$sha" '{state:$st, headRefOid:$sha, statusCheckRollup:.}'; }
empty() { jq -cn --arg sha "$1" '{state:"OPEN", headRefOid:$sha, statusCheckRollup:[]}'; }
# go <args…> — the queue is whatever $FAKE_SEQ holds
go() { : > "$FAKE_LOG"; echo 0 > "$FAKE_N"; out=$(PATH="$tmp/bin:$PATH" "$BASH_BIN" "$s" --interval 0 "$@" 2>&1); rc=$?; }

A=aaaaaaaaaaaa1111111111111111111111111111 B=bbbbbbbbbbbb2222222222222222222222222222
G=$(run_check validate COMPLETED SUCCESS); P=$(run_check validate IN_PROGRESS ""); Q=$(run_check shard QUEUED "")
F=$(run_check validate COMPLETED FAILURE); C=$(run_check shard COMPLETED CANCELLED); S=$(run_check docs COMPLETED SKIPPED)

printf '== green\n'
view OPEN $A "$G" "$S" > "$FAKE_SEQ"; go --pr 7
code 0 "all checks passed or skipped"; has "reports the merge" "merged PR #7 at aaaaaaaaaaaa (merge, 2 checks green)"
grep -qxF "pr merge 7 --merge --match-head-commit $A" "$FAKE_LOG" && ok || bad "merges the head it saw green, with --merge" "$(cat "$FAKE_LOG")"
grep -q -- '--auto\|--delete-branch' "$FAKE_LOG" && bad "never --auto, never --delete-branch" "$(cat "$FAKE_LOG")" || ok
go --pr '#7' --repo o/r --method squash
grep -qxF "pr merge 7 -R o/r --squash --match-head-commit $A" "$FAKE_LOG" && ok || bad "--repo and --method reach gh" "$(cat "$FAKE_LOG")"

printf '== waits\n'
{ view OPEN $A "$P" "$Q"; view OPEN $A "$G" "$Q"; view OPEN $A "$G" "$G"; } > "$FAKE_SEQ"; go --pr 7
code 0 "pending, pending, green"; [ "$(grep -c '^pr view' "$FAKE_LOG")" = 3 ] && ok || bad "polls until nothing is pending" "$(cat "$FAKE_LOG")"
{ empty $A; empty $A; view OPEN $A "$G"; } > "$FAKE_SEQ"; go --pr 7
code 0 "no checks yet is not green: it waits for the first check"
{ view OPEN $A "$P"; view OPEN $B "$P"; view OPEN $B "$G"; } > "$FAKE_SEQ"; go --pr 7
grep -qxF "pr merge 7 --merge --match-head-commit $B" "$FAKE_LOG" && ok || bad "a push while waiting: merges the new head, after its checks" "$(cat "$FAKE_LOG")"
{ echo ERR; echo ERR; view OPEN $A "$G"; } > "$FAKE_SEQ"; go --pr 7
code 0 "two failed lookups (a 502) then green"
{ view OPEN $A "$(ctx ci/legacy PENDING)"; view OPEN $A "$(ctx ci/legacy SUCCESS)"; } > "$FAKE_SEQ"; go --pr 7
code 0 "a commit status (StatusContext) pending then success"

printf '== refuses\n'
view OPEN $A "$G" "$F" > "$FAKE_SEQ"; go --pr 7
code 1 "a failed check"; has "names the failed check" "PR #7 is red: validate; nothing was merged"; [ "$(merges)" = 0 ] && ok || bad "red never merges" "$(cat "$FAKE_LOG")"
view OPEN $A "$P" "$C" > "$FAKE_SEQ"; go --pr 7
code 1 "a cancelled check is red even while another runs"; has "names the cancelled check" "red: shard"
view OPEN $A "$(ctx ci/legacy ERROR)" > "$FAKE_SEQ"; go --pr 7
code 1 "a commit status in error"
empty $A > "$FAKE_SEQ"; go --pr 7 --grace 0
code 5 "no checks within --grace"; [ "$(merges)" = 0 ] && ok || bad "no checks never merges" "$(cat "$FAKE_LOG")"
view OPEN $A "$P" > "$FAKE_SEQ"; go --pr 7 --timeout 0
code 6 "still pending at --timeout"; [ "$(merges)" = 0 ] && ok || bad "a timeout never merges" "$(cat "$FAKE_LOG")"
echo ERR > "$FAKE_SEQ"; go --pr 7
code 4 "five failed lookups in a row"; [ "$(grep -c '^pr view' "$FAKE_LOG")" = 5 ] && ok || bad "stops at the fifth" "$(cat "$FAKE_LOG")"
view MERGED $A "$G" > "$FAKE_SEQ"; go --pr 7
code 4 "a PR that is not open"; has "says the state" "PR #7 is MERGED, not open"
view OPEN $A "$G" > "$FAKE_SEQ"; FAKE_MERGE_RC=1 go --pr 7
code 7 "gh refuses the merge"; has "carries gh's reason" "review required"
view OPEN $A "$G" > "$FAKE_SEQ"; go --pr 7 --dry-run
code 0 "--dry-run on green"; has "says it did not merge" "--dry-run, not merged"; [ "$(merges)" = 0 ] && ok || bad "--dry-run never merges" "$(cat "$FAKE_LOG")"

printf '== usage\n'
for a in "" "--pr" "--pr abc" "--pr 0" "--pr 7 --method auto" "--pr 7 --timeout 5m" "--pr 7 --repo bad" "--pr 7 --auto"; do
  # shellcheck disable=SC2086
  go $a; code 2 "usage: '$a'"
done
[ "$(merges)" = 0 ] && ok || bad "a usage error never reaches gh" "$(cat "$FAKE_LOG")"
ln -s "$(command -v jq)" "$tmp/nogh/jq"
out=$(PATH="$tmp/nogh" "$BASH_BIN" "$s" --pr 7 2>&1); rc=$?
code 3 "gh missing"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
