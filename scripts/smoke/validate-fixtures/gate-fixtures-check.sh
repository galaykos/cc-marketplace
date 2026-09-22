#!/usr/bin/env bash
# Fixture harness for the three checks the 2026-09-22 specialist panel added to
# scripts/lib/plugin-checks.sh — pc_cwd_validated (#2), pc_offswitch_named (#5) and
# pc_version_stamp_tail (#21). Each gets BOTH arms: a planted violation that must be
# named, and a clean twin that must not be. A check that only ever runs against the live
# tree proves nothing on the day the tree is clean, which is the day it lands.
#
# Never touches plugins/ — every fixture is built under a temp root and the pc_*
# functions are called against that root directly.
set -u
cd "$(dirname "$0")/../../.." || exit 2   # repo root
. scripts/lib/plugin-checks.sh || { echo "FAIL: cannot source scripts/lib/plugin-checks.sh"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
rc=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 — $2"; rc=1; }

mkhook() { # <plugin> <script-name> <body-file-content on stdin>
  mkdir -p "$T/$1/hooks"
  cat > "$T/$1/hooks/$2"
  jq -n --arg c "\${CLAUDE_PLUGIN_ROOT}/hooks/$2" \
    '{hooks:{PreToolUse:[{matcher:"Write",hooks:[{type:"command",command:$c,timeout:5}]}]}}' \
    > "$T/$1/hooks/hooks.json"
}

# ---- pc_cwd_validated ----------------------------------------------------------
mkhook badcwd resurrect.sh <<'SH'
#!/bin/bash
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || exit 0
dir="$cwd/.claude/fixture"
mkdir -p "$dir" 2>/dev/null || exit 0
exit 0
SH
mkhook okcwd guarded.sh <<'SH'
#!/bin/bash
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
dir="$cwd/.claude/fixture"
mkdir -p "$dir" 2>/dev/null || exit 0
exit 0
SH
# The equivalent test: a read of a path INSIDE cwd proves the directory is there.
mkhook insidecwd inside.sh <<'SH'
#!/bin/bash
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -r "$cwd/.claude/fixture/run.json" ] || exit 0
d="$cwd/.claude/fixture/sub"
mkdir -p "$d" 2>/dev/null || exit 0
exit 0
SH
out=$(pc_cwd_validated "$T") || true
case "$out" in
  *"cwd-unvalidated badcwd:resurrect.sh"*) pass "cwd: unguarded mkdir on payload cwd is named" ;;
  *) fail "cwd: unguarded mkdir on payload cwd is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *okcwd*) fail "cwd: [ -d \"\$cwd\" ] arm stays clean" "flagged: $out" ;;
  *) pass "cwd: [ -d \"\$cwd\" ] arm stays clean" ;;
esac
case "$out" in
  *insidecwd*) fail "cwd: a test on a path inside cwd counts as validation" "flagged: $out" ;;
  *) pass "cwd: a test on a path inside cwd counts as validation" ;;
esac
printf '# cwd-mkdir-ok: fixture\n' >> "$T/badcwd/hooks/resurrect.sh"
out=$(pc_cwd_validated "$T") || true
case "$out" in
  *badcwd*) fail "cwd: '# cwd-mkdir-ok:' silences it" "still flagged: $out" ;;
  *) pass "cwd: '# cwd-mkdir-ok:' silences it" ;;
esac

# ---- pc_offswitch_named --------------------------------------------------------
mkhook badsw quiet-deny.sh <<'SH'
#!/bin/bash
# CC_FIXTURE_GUARD=off turns this off — said here, where a refused user never looks.
input=$(cat)
[ "${CC_FIXTURE_GUARD:-on}" = off ] && exit 0
jq -cn --arg r 'fixture: refused.' \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
SH
mkhook oksw loud-deny.sh <<'SH'
#!/bin/bash
input=$(cat)
[ "${CC_FIXTURE_GUARD:-on}" = off ] && exit 0
jq -cn --arg r 'fixture: refused. CC_FIXTURE_GUARD=off disables this for the session.' \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
SH
# A hook that cannot refuse is out of scope even with a switch and no prose.
mkhook advisorysw advise.sh <<'SH'
#!/bin/bash
input=$(cat)
[ "${CC_FIXTURE_ADVISORY:-on}" = off ] && exit 0
printf 'fixture: a suggestion.\n'
exit 0
SH
out=$(pc_offswitch_named "$T") || true
case "$out" in
  *"offswitch-unnamed badsw:quiet-deny.sh"*) pass "offswitch: a deny that names its switch nowhere is flagged" ;;
  *) fail "offswitch: a deny that names its switch nowhere is flagged" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *oksw*) fail "offswitch: naming it in the reason clears it" "flagged: $out" ;;
  *) pass "offswitch: naming it in the reason clears it" ;;
esac
case "$out" in
  *advisorysw*) fail "offswitch: an advisory hook is out of scope" "flagged: $out" ;;
  *) pass "offswitch: an advisory hook is out of scope" ;;
esac
printf '# offswitch-ok: fixture\n' >> "$T/badsw/hooks/quiet-deny.sh"
out=$(pc_offswitch_named "$T") || true
case "$out" in
  *badsw*) fail "offswitch: '# offswitch-ok:' silences it" "still flagged: $out" ;;
  *) pass "offswitch: '# offswitch-ok:' silences it" ;;
esac

# ---- pc_version_stamp_tail -----------------------------------------------------
mkskill() { mkdir -p "$T/$1/skills/$2"; cat > "$T/$1/skills/$2/SKILL.md"; }
mkskill badstamp pinner <<'MD'
---
name: pinner
description: Use when writing framework code — advice pinned to the installed version.
---

> Last verified: 2026-09-22 — https://example.invalid/releases

Body.
MD
mkskill okstamp pinner-tailed <<'MD'
---
name: pinner-tailed
description: Use when writing framework code — advice pinned to the installed version.
---

> Last verified: 2026-09-22 — https://example.invalid/releases — npm:example@9

Body.
MD
mkskill nostampclaim plain <<'MD'
---
name: plain
description: Use when doing a thing that makes no claim about versions at all.
---

Body.
MD
out=$(pc_version_stamp_tail "$T") || true
case "$out" in
  *"version-stamp-tail badstamp:pinner "*) pass "stamp-tail: a pinning claim with a tailless stamp is flagged" ;;
  *) fail "stamp-tail: a pinning claim with a tailless stamp is flagged" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *okstamp*) fail "stamp-tail: an npm: tail clears it" "flagged: $out" ;;
  *) pass "stamp-tail: an npm: tail clears it" ;;
esac
case "$out" in
  *nostampclaim*) fail "stamp-tail: a skill claiming no pinning is out of scope" "flagged: $out" ;;
  *) pass "stamp-tail: a skill claiming no pinning is out of scope" ;;
esac
printf '\n<!-- version-tail-ok: fixture -->\n' >> "$T/badstamp/skills/pinner/SKILL.md"
out=$(pc_version_stamp_tail "$T") || true
case "$out" in
  *badstamp*) fail "stamp-tail: '<!-- version-tail-ok: -->' silences it" "still flagged: $out" ;;
  *) pass "stamp-tail: '<!-- version-tail-ok: -->' silences it" ;;
esac

[ "$rc" -eq 0 ] && echo "All panel gate-fixture asserts passed."
exit "$rc"
