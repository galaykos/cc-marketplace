#!/usr/bin/env bash
# scripts/smoke/prompt-route-tests.sh
#
# The skill-router's tool-fit check (hooks/route-prompt.sh).
#
# SCOPE, stated up front so nobody reads this harness as more than it is: the hook
# does not choose a command. It builds the catalog of installed commands and injects
# the rules for judging; the routing verdict is the MODEL's, and a judgment cannot be
# asserted by a shell test. What is gated here is the mechanism around the judgment —
# that the catalog is built, correct, and installed-scoped; that the directive carries
# the discipline that keeps it from nagging; that every guard silences the hook; that
# it costs its tokens once per session. Which command the model then picks is
# agent-graded, per CLAUDE.md's has-teeth convention. Do not add a test here that
# claims otherwise.
#
# Half B covers the two validate.sh gates that keep the mechanism honest: no literal
# command token in the hook, and no second routing pattern growing back in shell.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CHASSIS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
cd "$ROOT" || exit 2
BASH_BIN="$(command -v bash)"

SR="plugins/skill-router"
HOOK="$ROOT/$SR/hooks/route-prompt.sh"
[ -f "$HOOK" ] || { printf 'prompt-route-tests: no %s\n' "$HOOK" >&2; exit 2; }

WORK="$(mktemp -d)" || exit 2
HB="$WORK/route-prompt.sh.bak"
cp "$HOOK" "$HB" || exit 2
cleanup() {
  [ -f "$HB" ] && cp "$HB" "$HOOK"
  if [ -f "$HB" ] && ! cmp -s "$HB" "$HOOK"; then
    printf 'FAIL  %s not restored\n' "$HOOK"; rm -rf "$WORK"; exit 1
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM HUP

rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; rc=1; }

NOJQ="$WORK/nojq-bin"; mkdir -p "$NOJQ"
for u in cat grep sed awk tr head cut env sh expr dirname basename printf mkdir find cksum; do
  p="$(command -v "$u" 2>/dev/null)" && ln -s "$p" "$NOJQ/$u" 2>/dev/null
done
if PATH="$NOJQ" command -v jq >/dev/null 2>&1; then
  printf 'prompt-route-tests: could not build a jq-free PATH; aborting\n' >&2; exit 2
fi

# Every call needs its OWN session id and TMPDIR: the hook injects once per session,
# so a shared session would silence every case after the first. The counter lives in a
# FILE, not a variable — run_hook is called inside $( ), and a variable incremented in a
# subshell never reaches the parent (which is exactly how the first draft of this
# harness reported three false silences).
COUNTER="$WORK/n"; printf '0' > "$COUNTER"
run_hook() { # run_hook <prompt> <root> [env...] -> hook stdout
  local prompt="$1" root="$2"; shift 2
  local n; n=$(( $(cat "$COUNTER") + 1 )); printf '%s' "$n" > "$COUNTER"
  local box="$WORK/box-$n"; mkdir -p "$box"
  printf '%s' "$prompt" | jq -Rs --arg s "sess-$n" '{prompt:., session_id:$s}' \
    | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$root" "$@" "$BASH_BIN" "$HOOK" 2>/dev/null
}

want_fires() { # desc  prompt
  local out; out="$(run_hook "$2" "$ROOT/$SR")"
  [ -n "$out" ] && pass "$1" || fail "$1" "wanted the catalog, hook stayed silent"
}
want_silent() { # desc  prompt  [env...]
  local desc="$1" prompt="$2"; shift 2
  local out; out="$(run_hook "$prompt" "$ROOT/$SR" "$@")"
  [ -z "$out" ] && pass "$desc" || fail "$desc" "wanted silence, spoke ${#out} bytes"
}

printf '== half A: when it fires ==\n'
want_fires "work-shaped: build"    "build a landing page for a B2B marketing agency"
want_fires "work-shaped: fix"      "fix the crash on checkout submit"
want_fires "work-shaped: review"   "review my diff before I push"
want_fires "names a tool"          "run taskmaster: create a marketing landing page"

printf '== half A: guards ==\n'
want_silent "not work-shaped"     "what time does the standup start"
want_silent "slash prompt"        "/taskmaster:task build a landing page"
want_silent "meta: about the hook" "disable the router hook that injects the catalog"
want_silent "own output echoed"   "[skill-router] Tool-fit check (once this session)."
want_silent "CC_ROUTE=off"        "build a landing page" CC_ROUTE=off
want_silent "CC_REMIND=off"       "build a landing page" CC_REMIND=off

box="$WORK/nojq-box"; mkdir -p "$box"
out=$(printf '{"prompt":"build a landing page","session_id":"nojq"}' \
  | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" PATH="$NOJQ" "$BASH_BIN" "$HOOK" 2>/dev/null); jrc=$?
if [ "$jrc" -eq 0 ] && [ -z "$out" ]; then pass "no-jq fail-open"; else fail "no-jq fail-open" "exit $jrc, out: ${out:0:60}"; fi

# once per session: same session id, same TMPDIR — the catalog is context-resident
# after the first injection, so a second copy is pure waste.
box="$WORK/once"; mkdir -p "$box"
J='{"prompt":"build a landing page","session_id":"once"}'
o1=$(printf '%s' "$J" | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" "$BASH_BIN" "$HOOK" 2>/dev/null)
o2=$(printf '%s' "$J" | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -n "$o1" ] && pass "first prompt injects" || fail "first prompt injects" "silent"
[ -z "$o2" ] && pass "second prompt yields" || fail "second prompt yields" "injected twice"

printf '== half A: catalog content ==\n'
cat_out="$(run_hook "build a landing page for a B2B marketing agency" "$ROOT/$SR")"
lines=$(printf '%s' "$cat_out" | grep -c '^- /' || true)
[ "$lines" -ge 20 ] && pass "catalog has $lines command lines" \
  || fail "catalog line count" "only $lines lines — expected the installed commands"

# every catalog line must name a command that actually exists on disk
bad=""
while IFS= read -r line; do
  tok=${line#- }; tok=${tok%% *}
  p=${tok#/}; p=${p%%:*}; c=${tok##*:}
  [ -f "plugins/$p/commands/$c.md" ] || bad="$bad $tok"
done <<EOF_LINES
$(printf '%s' "$cat_out" | grep '^- /')
EOF_LINES
[ -z "$bad" ] && pass "every catalog entry resolves to a command file" \
  || fail "catalog entries resolve" "no such command:$bad"

# the directive must carry the anti-nag discipline — these are the rules that stop a
# catalog from turning every prompt into a suggestion
for phrase in "Silence is the default" "AskUserQuestion" "(Recommended)" "as asked" \
              "one picker per named tool per session" "goal ledger"; do
  printf '%s' "$cat_out" | grep -qF "$phrase" \
    && pass "directive carries: $phrase" || fail "directive carries: $phrase" "missing"
done

# installed-scoping: a tree holding two plugins must yield a catalog of only those
SOLO="$WORK/solo/plugins"; mkdir -p "$SOLO/skill-router/hooks"
cp -R plugins/a11y "$SOLO/a11y"
cp "$HOOK" "$SOLO/skill-router/hooks/route-prompt.sh"
solo_out="$(run_hook "audit this for accessibility problems and fix them" "$SOLO/skill-router")"
solo_lines=$(printf '%s' "$solo_out" | grep -c '^- /' || true)
foreign=$(printf '%s' "$solo_out" | grep '^- /' | grep -vc '^- /a11y:' || true)
if [ "$solo_lines" -ge 1 ] && [ "$foreign" -eq 0 ]; then
  pass "catalog is installed-scoped ($solo_lines entries, all a11y)"
else
  fail "catalog is installed-scoped" "$solo_lines entries, $foreign from uninstalled plugins"
fi

printf '== half B: validate.sh gates ==\n'
want_err() { printf '%s\n' "$vout" | grep -qF "$2" && pass "$1" || fail "$1 did not fire" "wanted: $2"; }

printf 'echo /taskmaster:task\n' >> "$HOOK"
vout=$(bash scripts/validate.sh 2>&1)
cp "$HB" "$HOOK"
want_err "literal command token" "carries literal command token(s)"

# a fifth prompt-matching grep = a routing table regrowing in shell
printf '%s\n' 'printf '"'"'%s'"'"' "$head" | grep -qiE "landing page" && exit 0' >> "$HOOK"
vout=$(bash scripts/validate.sh 2>&1)
cp "$HB" "$HOOK"
want_err "extra prompt pattern" "a fifth is a routing table regrowing in shell"

vout=$(bash scripts/validate.sh 2>&1)
printf '%s\n' "$vout" | grep -qF 'route-prompt.sh' \
  && fail "clean tree is clean" "validate still reports route-prompt problems after restore" \
  || pass "clean tree is clean"

if [ "$rc" -eq 0 ]; then
  printf '\nAll tool-fit check cases passed (mechanism only — the routing verdict is agent-graded).\n'
else
  printf '\nSome tool-fit check cases FAILED.\n'
fi
exit $rc
