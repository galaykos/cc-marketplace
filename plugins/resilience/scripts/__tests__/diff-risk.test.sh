#!/usr/bin/env bash
# diff-risk.test.sh — drives scripts/diff-risk.sh on a throwaway repo with dated commits: the formula and ranking, the branch's own commits
#   left out, untrusted subjects printed literally and never run, near-miss subjects not counted, --since, --json, both walk modes, exit codes.
# Why, limits, history: rationale/derivations/plugin-resilience.md § plugins/resilience/scripts/__tests__/diff-risk.test.sh
set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
S="$(cd "$(dirname "$0")/.." && pwd)/diff-risk.sh"
tmp=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
tmp=$(cd "$tmp" && pwd -P) || exit 1
trap 'rm -rf "$tmp"' EXIT
export GIT_CEILING_DIRECTORIES="$tmp" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/fixture.gitconfig"
printf '[user]\n\tname = t\n\temail = t@t\n[init]\n\tdefaultBranch = main\n[commit]\n\tgpgsign = false\n' >"$GIT_CONFIG_GLOBAL"
rc=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; rc=1; }
run() { out=$(cd "$tmp/repo" && bash "$S" "$@" 2>&1); got=$?; }
expect_rc() { # label want_rc args...
  local label=$1 want=$2; shift 2
  run "$@"
  if [ "$got" = "$want" ]; then pass "$label (rc=$got)"; else fail "$label — want rc=$want, got $got" "$out"; fi
}
row() { F=$1 awk '$1 ~ /^[0-9]+$/ && $NF == ENVIRON["F"]' <<<"$out"; }   # "score revert fix follow-up" row of file $1
expect_row() { # file "score revert fix follow-up" label
  local r; r=$(row "$1" | awk '{print $1, $2, $3, $4}')
  if [ "$r" = "$2" ]; then pass "$3 ($r)"; else fail "$3 — want '$2', got '${r:-no row}'" "$out"; fi
}
now=$(date +%s)
c() { # c <days ago> <file> <subject>
  local d="@$((now - $1 * 86400)) +0000"
  printf '%s\n' "$1 $3" >>"$2" && git add -- "$2" && GIT_AUTHOR_DATE=$d GIT_COMMITTER_DATE=$d git commit -qm "$3"
}

mkdir "$tmp/repo" && cd "$tmp/repo" && git init -q || { echo "FAIL: git init"; exit 1; }
META='fix: $(touch pwned_dollar) `touch pwned_tick`; touch pwned_semi | x && y > pwned_redir "dq" '"'sq'"' * \n %s %d'
ESC=$'fix: bell\033[31mred'
c 900 risky.txt "add risky"; c 900 calm.txt "add calm"; c 900 near.txt "add near"
c 800 calm.txt "fix: ancient calm"
c 60 risky.txt "add retry"
c 58 risky.txt 'Revert "add retry"'
c 40 risky.txt "fix(api): null check"
c 30 meta.txt "add meta"
c 20 'q"uote.txt' "hotfix(quote): the odd name"
c 10 risky.txt "Fixes #12 timeout"
c 8 near.txt "prefix fixture"
c 7 near.txt "fixed-width font"
c 6 near.txt "Reverting is hard: notes"
c 5 meta.txt "$META"
c 3 meta.txt "$ESC"
c 2 calm.txt "docs: tidy calm"
git switch -q -c feature
c 1 risky.txt "fix: the branch's own commit"
c 1 calm.txt "feature: calm"
c 1 near.txt "feature: near"
echo wip >>meta.txt
echo new >new.txt

# Pathspec walk: no touched name is C-quoted here.
expect_rc "default run on a branch exits 0" 0
expect_row risky.txt "8 1 2 1" "revert + two fixes + one follow-up scores 3+4+1; the branch's own fix is not history"
expect_row meta.txt "5 0 2 1" "uncommitted file scored; fix 2 days after a fix is a follow-up"
[ "$(awk '$1 ~ /^[0-9]+$/ {print $NF; exit}' <<<"$out")" = risky.txt ] && pass "risky.txt ranks first" \
  || fail "risky.txt does not rank first" "$out"
[ -z "$(row calm.txt)" ] && pass "calm.txt (no signal inside --since) is not listed" || fail "calm.txt listed" "$out"
[ -z "$(row near.txt)" ] && pass "near-miss subjects (prefix fixture, fixed-width font, Reverting is) do not count" \
  || fail "a near-miss subject counted" "$out"
grep -q '^overall: 2 of 5 touched files carry risk signals; highest risky.txt (8); total 13' <<<"$out" \
  && pass "overall line counts 5 touched (committed, uncommitted, untracked), 2 flagged" || fail "overall line wrong" "$out"
grep -qF -- "$META" <<<"$out" && pass "metacharacter subject printed literally" || fail "metacharacter subject not literal" "$out"
pw=$(find "$tmp" -name 'pwned_*' | head -1)
[ -z "$pw" ] && pass "no subject text was executed" || fail "a subject was executed: $pw"
case "$out" in *$'\033'*) fail "raw ESC byte reached the output" ;; *) pass "control byte in a subject printed as ?" ;; esac
grep -qF 'bell?[31mred' <<<"$out" || fail "sanitized ESC subject missing" "$out"

expect_rc "--since 3 years ago exits 0" 0 --since "3 years ago"
expect_row calm.txt "2 0 1 0" "--since widens the window to the 800-day-old fix"

expect_rc "--base HEAD exits 0" 0 --base HEAD
grep -q '^overall: 1 of 2 touched files' <<<"$out" && pass "--base HEAD scores only the uncommitted files" \
  || fail "--base HEAD touched set wrong" "$out"

expect_rc "--json exits 0" 0 --json
if command -v python3 >/dev/null 2>&1; then
  if DR_OUT=$out DR_META=$META python3 -c '
import json, os
d = json.loads(os.environ["DR_OUT"])
t = {f["path"]: f for f in d["top"]}
assert d["touched"] == 5 and d["flagged"] == 2 and d["total"] == 13, d
assert d["top"][0]["path"] == "risky.txt" and d["top"][0]["score"] == 8, d["top"][0]
assert "calm.txt" not in t and "near.txt" not in t
subs = [c["subject"] for c in t["meta.txt"]["commits"]]
assert os.environ["DR_META"] in subs, subs
assert [c["follow_up"] for c in t["risky.txt"]["commits"]] == [False, False, True], t["risky.txt"]
' 2>"$tmp/py.err"; then pass "--json parses; scores, ranking and the literal subject round-trip"
  else fail "--json content" "$(cat "$tmp/py.err") :: $out"; fi
elif command -v jq >/dev/null 2>&1; then
  jq -e '.top[0].path == "risky.txt" and .top[0].score == 8' <<<"$out" >/dev/null && pass "--json parses (jq)" || fail "--json (jq)" "$out"
else
  echo "SKIP: --json parse — neither python3 nor jq found"
fi

# Unfiltered walk: a C-quoted touched name turns the pathspec off; scores must not move.
echo wip >>'q"uote.txt'
expect_rc "run with a C-quoted touched name exits 0" 0
expect_row risky.txt "8 1 2 1" "unfiltered walk scores risky.txt the same"
expect_row '"q\"uote.txt"' "2 0 1 0" "a quoted file name is scored and shown C-quoted"

expect_rc "--help exits 0" 0 --help
expect_rc "unknown flag is a usage error" 2 --bogus
expect_rc "--base without a value is a usage error" 2 --base
expect_rc "--base that names no commit exits 2" 2 --base no-such-ref
expect_rc "--base that looks like a flag exits 2" 2 --base --json
expect_rc "--dir that does not exist exits 2" 2 --dir "$tmp/nope"
mkdir "$tmp/plain"
expect_rc "not a git work tree exits 3" 3 --dir "$tmp/plain"
git init -q -b trunk "$tmp/trunk" && (cd "$tmp/trunk" && c 1 a.txt "fix: a")
expect_rc "no origin/HEAD, main or master exits 2" 2 --dir "$tmp/trunk"
grep -q 'no base' <<<"$out" && pass "no-base message names the cause" || fail "no-base message" "$out"
expect_rc "the same repo with --base exits 0" 0 --dir "$tmp/trunk" --base HEAD
grep -q '^overall: no touched files vs [0-9a-f]*; nothing to score' <<<"$out" \
  && pass "nothing touched exits 0 and says nothing to score" || fail "nothing-touched overall line" "$out"
git init -q "$tmp/unborn"
expect_rc "a repo with no commits exits 2" 2 --dir "$tmp/unborn"

bash_bin=$(command -v bash)
out=$(cd "$tmp/repo" && PATH= "$bash_bin" "$S" 2>&1); got=$?
[ "$got" = 4 ] && grep -q 'git not found' <<<"$out" && pass "git missing (empty PATH) exits 4 (rc=$got)" \
  || fail "git missing — want rc=4 and 'git not found', got $got" "$out"
mkdir "$tmp/gitonly" && ln -s "$(command -v git)" "$tmp/gitonly/git"
out=$(cd "$tmp/repo" && PATH="$tmp/gitonly" "$bash_bin" "$S" 2>&1); got=$?
[ "$got" = 4 ] && grep -q 'awk not found' <<<"$out" && pass "awk missing (PATH holds only git) exits 4 (rc=$got)" \
  || fail "awk missing — want rc=4 and 'awk not found', got $got" "$out"

# A conventional revert subject, and a fix exactly 14 days (inside the window) and 15 days (outside) after the previous commit.
mkdir "$tmp/window" && (cd "$tmp/window" && git init -q && c 200 rv.txt "add rv" && c 100 rv.txt "revert: x" \
  && c 100 w14.txt "add w14" && c 86 w14.txt "fix: w14" && c 100 w15.txt "add w15" && c 85 w15.txt "fix: w15" \
  && echo wip >>rv.txt && echo wip >>w14.txt && echo wip >>w15.txt) || fail "window fixture"
expect_rc "window repo exits 0" 0 --dir "$tmp/window"
expect_row rv.txt "3 1 0 0" "a 'revert: x' subject counts as a revert"
expect_row w14.txt "3 0 1 1" "a fix exactly 14 days after the previous commit is a follow-up"
expect_row w15.txt "2 0 1 0" "a fix 15 days after the previous commit is not"

exit $rc
