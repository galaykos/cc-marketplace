#!/usr/bin/env bash
# scripts/smoke/prompt-route-tests.sh
#
# Two halves, one subject: the skill-router's prompt→command router.
#
# Half A — the hook. Feeds prompts to hooks/route-prompt.sh and asserts WHICH command
# comes back, not merely that something did. The load-bearing case is priority: a prompt
# matching both a specialist row and the generic fallback must return the specialist.
# That is the whole reason this router exists — the reminder hooks resolve exactly that
# tie by scheduling order, which is not a routing decision.
#
# Half B — the validate.sh gate. Plants malformed rows in prompt-rules.tsv, asserts each
# FAIL string actually fires, then restores and proves the file is byte-identical. A gate
# nobody has watched fail is a gate nobody knows works.
#
# Every hook case runs with a sandboxed TMPDIR: the router claims the shared per-prompt
# reminder marker, so without isolation one case would silence the next.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CHASSIS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
cd "$ROOT" || exit 2
BASH_BIN="$(command -v bash)"

SR="plugins/skill-router"
HOOK="$ROOT/$SR/hooks/route-prompt.sh"
PR="$ROOT/$SR/prompt-rules.tsv"
[ -f "$HOOK" ] || { printf 'prompt-route-tests: no %s\n' "$HOOK" >&2; exit 2; }
[ -f "$PR" ] || { printf 'prompt-route-tests: no %s\n' "$PR" >&2; exit 2; }

WORK="$(mktemp -d)" || exit 2
BAK="$WORK/prompt-rules.tsv.bak"
cp "$PR" "$BAK" || exit 2
cleanup() {
  [ -f "$BAK" ] && cp "$BAK" "$PR"
  if [ -f "$BAK" ] && ! cmp -s "$BAK" "$PR"; then
    printf 'FAIL  %s not restored\n' "$PR"; rm -rf "$WORK"; exit 1
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM HUP

rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; rc=1; }

# clean bin: coreutils the hook may need, jq deliberately excluded
NOJQ="$WORK/nojq-bin"; mkdir -p "$NOJQ"
for u in cat grep sed awk tr head cut env sh expr dirname basename printf mkdir find cksum; do
  p="$(command -v "$u" 2>/dev/null)" && ln -s "$p" "$NOJQ/$u" 2>/dev/null
done
if PATH="$NOJQ" command -v jq >/dev/null 2>&1; then
  printf 'prompt-route-tests: could not build a jq-free PATH; aborting\n' >&2; exit 2
fi

n=0
run_hook() { # run_hook <prompt> [env assignments...] -> echoes hook stdout
  n=$((n + 1))
  local prompt="$1"; shift
  local box="$WORK/tmp-$n"; mkdir -p "$box"
  printf '%s' "$prompt" | jq -Rs '{prompt:., session_id:"smoke"}' \
    | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" "$@" "$BASH_BIN" "$HOOK" 2>/dev/null
}

want_cmd() { # desc  expected-command  prompt
  local desc="$1" want="$2" prompt="$3" out
  out="$(run_hook "$prompt")"
  case "$out" in
    *"$want"*) pass "$desc" ;;
    "")        fail "$desc" "wanted $want, hook stayed silent" ;;
    *)         fail "$desc" "wanted $want, got: $out" ;;
  esac
}

want_silent() { # desc  prompt  [env assignments...]
  local desc="$1" prompt="$2"; shift 2
  local out; out="$(run_hook "$prompt" "$@")"
  [ -z "$out" ] && pass "$desc" || fail "$desc" "wanted silence, spoke: $out"
}

printf '== half A: routing ==\n'
want_cmd "landing page -> craft"      "/craft-layer:craft" "build a landing page for a B2B marketing agency"
want_cmd "theme swap -> ui-ux:theme"  "/ui-ux:theme"       "I need a colour change on this shadcn project"
want_cmd "generic build -> taskmaster" "/taskmaster:task"  "implement invoicing for the orders module"
want_cmd "bug report -> debugging"    "/debugging:debug"   "the checkout crashes with a stack trace on submit"
want_cmd "review ask -> code-review"  "/code-review:review" "review my diff before I push it"

# THE regression this router exists for: both rows match, priority must decide.
want_cmd "priority beats row order"   "/craft-layer:craft" "create a landing page for our marketing site"
want_cmd "priority: theme over build" "/ui-ux:theme"       "build a re-theme of the dashboard with new design tokens"

printf '== half A: guards ==\n'
want_silent "slash prompt"        "/taskmaster:task build a landing page"
want_silent "meta: about the hook" "disable the router hook that suggests a landing page command"
want_silent "own output echoed"   "[skill-router] visual-craft work — /craft-layer:craft."
want_silent "no match at all"     "what time does the standup start"
want_silent "CC_ROUTE=off"        "build a landing page for a B2B marketing agency" CC_ROUTE=off
want_silent "CC_REMIND=off"       "build a landing page for a B2B marketing agency" CC_REMIND=off

# no-jq: fail open, silent, exit 0
box="$WORK/nojq-box"; mkdir -p "$box"
out=$(printf '{"prompt":"build a landing page","session_id":"smoke"}' \
  | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" PATH="$NOJQ" "$BASH_BIN" "$HOOK" 2>/dev/null); jrc=$?
if [ "$jrc" -eq 0 ] && [ -z "$out" ]; then pass "no-jq fail-open"; else fail "no-jq fail-open" "exit $jrc, out: $out"; fi

# per-prompt budget: same prompt + session + TMPDIR speaks once, then yields
box="$WORK/budget"; mkdir -p "$box"
J='{"prompt":"build a landing page for a B2B marketing agency","session_id":"budget"}'
o1=$(printf '%s' "$J" | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" "$BASH_BIN" "$HOOK" 2>/dev/null)
o2=$(printf '%s' "$J" | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$ROOT/$SR" "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -n "$o1" ] && pass "budget: first call speaks" || fail "budget: first call speaks" "silent"
[ -z "$o2" ] && pass "budget: second call yields" || fail "budget: second call yields" "spoke twice: $o2"

# uninstalled owning_plugin is skipped: point CLAUDE_PLUGIN_ROOT at a lone-plugin tree
SOLO="$WORK/solo/plugins"; mkdir -p "$SOLO/skill-router" "$SOLO/taskmaster"
cp "$PR" "$SOLO/skill-router/prompt-rules.tsv"
box="$WORK/solo-box"; mkdir -p "$box"
out=$(printf '{"prompt":"build a landing page for a B2B marketing agency","session_id":"solo"}' \
  | env TMPDIR="$box" CLAUDE_PLUGIN_ROOT="$SOLO/skill-router" "$BASH_BIN" "$HOOK" 2>/dev/null)
case "$out" in
  *"/taskmaster:task"*) pass "uninstalled plugin skipped, falls through" ;;
  *) fail "uninstalled plugin skipped, falls through" "wanted the taskmaster fallback, got: ${out:-<silence>}" ;;
esac

printf '== half B: validate.sh gate ==\n'
want_err() { # desc  exact-substring
  printf '%s\n' "$vout" | grep -qF "$2" && pass "$1" || fail "$1 did not fire" "wanted: $2"
}

# Assert by presence, never by absence-of-other-FAILs: validate.sh reports every
# problem it finds and a planted row can trip more than one check.
{ cat "$BAK"
  printf 'landing page\t/nosuch:command\tcraft-layer\t50\tbogus command\n'
  printf 'theme thing\t/ui-ux:theme\tdebugging\t50\tplugin mismatch\n'
  printf 'slow thing\t/performance:review\tperformance\thigh\tbad priority\n'
  printf 'short row\t/a11y:audit\ta11y\t50\n'
} > "$PR"
vout=$(bash scripts/validate.sh 2>&1)
want_err "bogus command"   "command '/nosuch:command' resolves to no plugins/nosuch/commands/command.md"
want_err "plugin mismatch" "belongs to 'ui-ux' but the installed-filter column says 'debugging'"
want_err "bad priority"    "priority 'high' is not a non-negative integer"
want_err "short row"       "needs five tab-separated fields"
cp "$BAK" "$PR"

# the table-driven gate: a literal command token in the hook must fail the build
HB="$WORK/route-prompt.sh.bak"; cp "$HOOK" "$HB"
printf 'echo /taskmaster:task\n' >> "$HOOK"
vout=$(bash scripts/validate.sh 2>&1)
cp "$HB" "$HOOK"
want_err "hook literal command" "route-prompt.sh carries literal command token(s)"
cmp -s "$HB" "$HOOK" || { fail "hook restored" "route-prompt.sh differs from its backup"; }

vout=$(bash scripts/validate.sh 2>&1)
printf '%s\n' "$vout" | grep -qF 'prompt-rules.tsv' \
  && { fail "clean tree is clean" "validate still reports prompt-rules problems after restore"; } \
  || pass "clean tree is clean"

if [ "$rc" -eq 0 ]; then
  printf '\nAll prompt-router cases passed (routing, guards, and gate fixtures).\n'
else
  printf '\nSome prompt-router cases FAILED.\n'
fi
exit $rc
