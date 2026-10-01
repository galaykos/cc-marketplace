#!/usr/bin/env bash
# done-gate harness: proves scripts/done-gate.sh, this repo's Stop hook, blocks a silent
# turn that ends with a changed plugin failing a per-plugin check, blocks one red state
# once, and lets acknowledged, clean, switched-off, re-entrant and WARN-only turns
# through — and that a copy with its `exit 2` turned into `exit 0` fails the same
# "is blocked" predicate, so this proof cannot stay green on a gate that stopped
# blocking. Also asserts the three allow_md copies (done-gate.sh, validate.sh,
# authoring-guard.sh) are byte-identical, and calls pc_frontmatter and pc_hook_exec
# directly on fixtures.
# CI step: .github/workflows/validate.yml "done-gate Stop hook smoke tests".
#
# DOES NOT PROVE: that the host honours exit 2 from a Stop hook (no live model runs
# here); that the gate finishes inside its 60 s Stop timeout on any machine — case 2's
# seconds are printed, never asserted; or any blocking check other than jargon,
# plugin.json validity, hook timeouts and the dependencies key.
#
# RUN AGAINST A MIRROR, NEVER THE LIVE TREE (role-floors-check.sh's rule). The gate
# writes .claude/done-gate-last into its project dir, so CLAUDE_PROJECT_DIR is always
# the mirror, and the mirror's own copy of done-gate.sh is what runs.
set -u
LIVE="$(cd "$(dirname "$0")/../.." && pwd)" || exit 2
cd "$LIVE" || exit 2
. scripts/lib/plugin-checks.sh || exit 2
command -v jq >/dev/null 2>&1 || {
  [ -n "${CI:-}" ] && { echo "FAIL: jq missing on the CI runner"; exit 1; }
  echo "SKIP: jq not installed"; exit 0
}
unset CRAFT_DONE_GATE
# Run from a git hook these are inherited, and the mirror's `git init` lands in the caller's repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
rc=0
T=$(mktemp -d) || exit 2
cleanup() {
  bad=0
  leak=$(find "$LIVE/scripts" -name done-gate-mutant.sh 2>/dev/null)
  [ -n "$leak" ] && { echo "FAIL: mutant leaked into the live tree: $leak"; bad=1; }
  cd / 2>/dev/null || true
  rm -rf "$T"
  [ "$bad" -eq 0 ] || exit 1
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

M="$T/mirror"; mkdir -p "$M"
for _d in plugins scripts templates .claude-plugin; do
  [ -e "$LIVE/$_d" ] && cp -R "$LIVE/$_d" "$M/" 2>/dev/null
done
for _f in CLAUDE.md README.md skills-lock.json .gitignore; do
  [ -f "$LIVE/$_f" ] && cp "$LIVE/$_f" "$M/" 2>/dev/null
done
git -C "$M" init -q && git -C "$M" add -A \
  && git -C "$M" -c user.name=harness -c user.email=harness@localhost -c commit.gpgsign=false \
       commit -q --no-verify -m mirror \
  || { echo "FAIL: could not build and commit the mirror"; exit 1; }

GATE="$M/scripts/done-gate.sh"
README="$M/plugins/debugging/README.md"
FINDING='jargon: plugins/debugging/README.md [card 07]'
TR="$T/transcript.jsonl"
ERR="$T/stderr"
g=0

say() { # $1: the only text the assistant wrote this turn
  jq -cn '{type:"user",message:{role:"user",content:"Tidy the debugging README."}}' > "$TR"
  jq -cn --arg t "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$t}]}}' >> "$TR"
}
gate() { # $1: gate script, $2: stop_hook_active; sets g, stderr lands in $ERR
  jq -cn --arg tp "$TR" --arg cwd "$M" --argjson a "$2" \
     '{session_id:"done-gate-harness",transcript_path:$tp,cwd:$cwd,hook_event_name:"Stop",stop_hook_active:$a}' \
    | CLAUDE_PROJECT_DIR="$M" "$1" >/dev/null 2>"$ERR"
  g=$?
}
reset() {
  git -C "$M" checkout -q -- plugins
  rm -f "$M/.claude/done-gate-last"
}
red() { printf 'Resolve card 07 before continuing.\n' >> "$README"; }
blocked() { # $1: the finding wanted on stderr, default $FINDING
  [ "$g" -eq 2 ] && grep -qF '{"decision":"block"' "$ERR" && grep -qF "${1:-$FINDING}" "$ERR"
}
let_through() { [ "$g" -eq 0 ] && ! grep -qF '{"decision":"block"' "$ERR"; }
report() { # $1: label; the predicate's status is $?
  if [ "$2" -eq 0 ]; then echo "PASS: $1"
  else echo "FAIL: $1 — exit $g, stderr: $(head -c 400 "$ERR")"; rc=1; fi
}

# 1
say "Updated the README."; gate "$GATE" false
let_through; report "a clean tree exits 0" $?

# 2
reset; red; say "Updated the README."
start=$SECONDS; gate "$GATE" false; secs=$((SECONDS - start))
blocked; report "a silent turn on a red per-plugin check is blocked" $?
echo "time: the blocking run took ${secs}s (printed, not asserted)"

# 3 — the marker case 2 wrote stays in place
gate "$GATE" false
let_through; report "the same red state blocks only once" $?
printf 'Then card 08.\n' >> "$README"; gate "$GATE" false
blocked 'jargon: plugins/debugging/README.md [card 07,card 08]'
report "a different red change after a block blocks again" $?

# 4
reset; red; say "validate.sh is failing; halting with evidence."; gate "$GATE" false
let_through; report "an acknowledged turn is not blocked" $?

# 5
reset; red; say "Updated the README."; gate "$GATE" true
let_through; report "stop_hook_active never re-enters" $?

# 6
reset; red; say "Updated the README."; CRAFT_DONE_GATE=off gate "$GATE" false
let_through; report "CRAFT_DONE_GATE=off disables the gate" $?

# 7
reset; printf '\n' >> "$README"; say "Updated the README."; gate "$GATE" false
let_through; report "a changed plugin that passes every check exits 0" $?

# 8 — validate.sh only WARNs on a plugin.json description over 700 chars
reset
pj="$M/plugins/debugging/.claude-plugin/plugin.json"
long=$(printf '%0720d' 0 | tr 0 x)
jq --arg d "$long" '.description = $d' "$pj" > "$T/pj" && mv "$T/pj" "$pj"
if [ "$(jq -r '.description | length' "$pj" 2>/dev/null)" = 720 ]; then
  echo "PASS: case 8 plant is in place"
else
  echo "FAIL: case 8 plant is in place — $pj does not carry the 720-char description"; rc=1
fi
say "Updated the README."; gate "$GATE" false
let_through; report "a WARN-tier problem never blocks" $?

# 9 — the mutant must still reach the block branch, or its exit 0 proves nothing
reset
MUT="$M/scripts/done-gate-mutant.sh"
awk '/^[[:space:]]*exit 2[[:space:]]*$/ { print "exit 0"; next } { print }' "$GATE" > "$MUT"
chmod +x "$MUT"
if cmp -s "$GATE" "$MUT"; then
  echo "FAIL: mutant not built"; rc=1
else
  red; say "Updated the README."; gate "$MUT" false
  if blocked; then
    echo "FAIL: a mutant with the block removed is caught — the is-blocked predicate held for it (exit $g)"; rc=1
  elif ! grep -qF "$FINDING" "$ERR"; then
    echo "FAIL: a mutant with the block removed is caught — the mutant never reached the block branch (exit $g)"; rc=1
  else
    echo "PASS: a mutant with the block removed is caught"
  fi
fi
rm -f "$MUT"
reset

# 10
copy() { sed -n "s/^[[:space:]]*allow_md='\(.*\)'[[:space:]]*\$/\1/p" "$LIVE/scripts/$1"; }
a=$(copy done-gate.sh); b=$(copy validate.sh); c=$(copy authoring-guard.sh)
if [ -n "$a" ] && [ "$a" = "$b" ] && [ "$a" = "$c" ]; then
  echo "PASS: all three doc-location regex copies agree"
else
  echo "FAIL: all three doc-location regex copies agree — done-gate: ${a:-<none>} | validate.sh: ${b:-<none>} | authoring-guard: ${c:-<none>}"; rc=1
fi

# 11
FX="$T/fx/plugins/fx"
mkdir -p "$FX/skills/fx" "$FX/hooks"
check() { # $1: label, $2: want status, $3: an exact output line wanted ('' = no output), $4: got status, $5: got output
  local ok=1
  if [ -z "$3" ]; then [ -z "$5" ] && ok=0
  else printf '%s\n' "$5" | grep -qxF "$3" && ok=0; fi
  if [ "$4" -eq "$2" ] && [ "$ok" -eq 0 ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 — status $4, output: $5"; rc=1
  fi
}
printf -- '---\nname: fx\n---\n\nBody.\n' > "$FX/skills/fx/SKILL.md"
out=$(pc_frontmatter "$FX/skills/fx/SKILL.md"); s=$?
check "pc_frontmatter names a missing description" 1 "$FX/skills/fx/SKILL.md: frontmatter missing description:" "$s" "$out"
printf -- '---\nname: fx\ndescription: Use when a harness needs a well-formed skill fixture.\n---\n\nBody.\n' > "$FX/skills/fx/SKILL.md"
out=$(pc_frontmatter "$FX/skills/fx/SKILL.md"); s=$?
check "pc_frontmatter passes a well-formed skill" 0 "" "$s" "$out"
printf '%s\n' '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}/hooks/h.sh\"","timeout":5}]}]}}' \
  > "$FX/hooks/hooks.json"
printf '#!/bin/bash\nexit 0\n' > "$FX/hooks/h.sh"; chmod 644 "$FX/hooks/h.sh"
out=$(pc_hook_exec "$FX"); s=$?
check "pc_hook_exec names a non-executable hook script" 1 \
  "$FX/hooks/hooks.json: hook script $FX/hooks/h.sh missing or not executable" "$s" "$out"
chmod +x "$FX/hooks/h.sh"
out=$(pc_hook_exec "$FX"); s=$?
check "pc_hook_exec passes an executable one" 0 "" "$s" "$out"

# 12
reset; printf '{]\n' > "$pj"; say "Updated the README."; gate "$GATE" false
blocked 'plugin-json: plugins/debugging/.claude-plugin/plugin.json'
report "an invalid plugin.json is blocked" $?

# 13
reset
hj="$M/plugins/debugging/hooks/hooks.json"
jq 'del(.hooks[][].hooks[].timeout)' "$hj" > "$T/hj" && mv "$T/hj" "$hj"
say "Updated the README."; gate "$GATE" false
blocked 'hook-timeout: debugging:'; report "a hook without a timeout is blocked" $?

# 14
reset
jq '.dependencies = ["testing"]' "$pj" > "$T/pj" && mv "$T/pj" "$pj"
say "Updated the README."; gate "$GATE" false
blocked 'dependencies: debugging testing'; report "a dependencies key is blocked" $?

# 15 — the red state is committed in a plugin this turn did not touch
reset
jq '.dependencies = ["debugging"]' "$M/plugins/testing/.claude-plugin/plugin.json" > "$T/pj" \
  && mv "$T/pj" "$M/plugins/testing/.claude-plugin/plugin.json" && git -C "$M" add -A \
  && git -C "$M" -c user.name=harness -c user.email=harness@localhost -c commit.gpgsign=false \
       commit -q --no-verify --amend -m mirror \
  || { echo "FAIL: could not plant the committed red state"; rc=1; }
printf 'A plain line.\n' >> "$README"; say "Updated the README."; gate "$GATE" false
let_through; report "an unchanged plugin's red state does not block" $?

[ "$rc" -eq 0 ] && echo "done-gate-tests: all PASS"
exit "$rc"
