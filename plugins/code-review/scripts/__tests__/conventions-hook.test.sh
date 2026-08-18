#!/usr/bin/env bash
# Fixtures for plugins/code-review/hooks/conventions.sh.
#
# The load-bearing assertion is a NEGATIVE one: the hook must emit PATHS and must
# NOT emit a digest of what those files say. An earlier design summarised "the
# three settings most often violated", which is exactly the shape
# rationale/stack-skill-baselines.md measured as making a review WORSE — the agent
# that read three bullets returned findings that were a strict subset of what the
# blind control found by opening the file. A summary substitutes for a read, so the
# fixture below asserts that no setting VALUE appears in the output.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
H=plugins/code-review/hooks/conventions.sh
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

# ISOLATE THE ONCE-PER-SESSION MARKER. The hook records "already fired" as a
# directory under $TMPDIR keyed on the session id. Without a scratch TMPDIR these
# fixtures pass on a clean machine and fail on the second run — or, worse, on a
# machine where a real session happened to use the same id, which makes the
# harness order-dependent in a way nothing would explain. Same failure the
# context-budget dynamic meter hit.
mkdir -p "$FX/tmp"
export TMPDIR="$FX/tmp"

mkdir -p "$FX/repo/.github/workflows" "$FX/repo/src" "$FX/bare"
printf 'root = true\n[*]\nindent_style = tab\nquote_type = double\nmax_line_length = 120\n' > "$FX/repo/.editorconfig"
printf '{"formatter":{"enabled":true}}\n' > "$FX/repo/biome.json"
printf 'jobs:\n  ci:\n    steps:\n      - run: npx biome check .\n' > "$FX/repo/.github/workflows/ci.yml"

fire() { # file cwd session -> additionalContext (empty when silent)
  jq -nc --arg f "$1" --arg c "$2" --arg s "$3" \
    '{tool_name:"Edit",session_id:$s,cwd:$c,tool_input:{file_path:$f}}' \
  | bash "$H" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

out=$(fire "$FX/repo/src/a.ts" "$FX/repo" s1)

for want in ".editorconfig" "biome.json" "npx biome check"; do
  if printf '%s' "$out" | grep -qF "$want"; then echo "PASS: names $want"
  else echo "FAIL: did not name $want"; rc=1; fi
done

# THE negative assertion: values from inside the config must not be echoed.
leaked=0
for v in "indent_style" "tab" "double" "120"; do
  printf '%s' "$out" | grep -qF "$v" && { echo "FAIL: leaked config VALUE '$v' — this is the digest shape the doctrine measured as harmful"; leaked=1; rc=1; }
done
[ "$leaked" -eq 0 ] && echo "PASS: emits locations only, no distilled settings"

# CI authority is not derivable from any config file, so it must be stated.
if printf '%s' "$out" | grep -q 'CI actually invokes'; then
  echo "PASS: states that CI is authoritative"
else echo "FAIL: CI-authoritative rule missing"; rc=1; fi

silent() { # label file cwd session
  local o; o=$(fire "$2" "$3" "$4")
  if [ -z "$o" ]; then echo "PASS: $1 (silent)"; else echo "FAIL: $1 — fired"; rc=1; fi
}

silent "second write in the same session"  "$FX/repo/src/b.ts"    "$FX/repo" s1
silent "markdown is out of scope"          "$FX/repo/README.md"   "$FX/repo" s2
silent "json is out of scope"              "$FX/repo/data.json"   "$FX/repo" s3
silent "repo with no convention configs"   "$FX/bare/x.ts"        "$FX/bare" s4

o=$(jq -nc --arg f "$FX/repo/src/c.ts" --arg c "$FX/repo" \
      '{tool_name:"Edit",session_id:"s5",cwd:$c,tool_input:{file_path:$f}}' \
    | CC_CONVENTIONS=off bash "$H" 2>/dev/null)
[ -z "$o" ] && echo "PASS: CC_CONVENTIONS=off silences it" || { echo "FAIL: off switch ignored"; rc=1; }

o=$(jq -nc --arg f "$FX/repo/src/d.ts" --arg c "$FX/repo" \
      '{tool_name:"Edit",session_id:"s6",cwd:$c,tool_input:{file_path:$f}}' \
    | CC_REMIND=off bash "$H" 2>/dev/null)
[ -z "$o" ] && echo "PASS: CC_REMIND=off silences it" || { echo "FAIL: marketplace-wide off switch ignored"; rc=1; }

if printf 'not json' | bash "$H" >/dev/null 2>&1; then
  echo "PASS: garbage input exits 0 (fail-open)"
else echo "FAIL: garbage input did not exit 0"; rc=1; fi

# ---- the payload the host actually sends -------------------------------------------
# Every case above sends session_id and no transcript_path, so they graded the FALLBACK
# branch of `.transcript_path // .session_id`. conventions.sh hashes that value through
# cksum before it becomes a filename, which is what makes it safe — but that is exactly
# the property nothing here exercised. Three sibling hooks shipped broken behind a green
# suite for want of these two cases. Gated by pc_harness_payload.
TP='/Users/x/.claude/projects/-Users-x-proj/abcdef01-2345-6789.jsonl'
tpfire() { # file cwd -> additionalContext
  jq -nc --arg f "$1" --arg c "$2" --arg t "$TP" \
    '{tool_name:"Edit",session_id:"11111111-2222-3333-4444-555555555555",transcript_path:$t,cwd:$c,tool_input:{file_path:$f}}' \
    | bash "$H" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
first=$(tpfire "$FX/repo/src/tp1.ts" "$FX/repo")
if [ -n "$first" ]; then echo "PASS: transcript_path present — the hook still speaks"
else echo "FAIL: transcript_path present — the hook went silent"; rc=1; fi

second=$(tpfire "$FX/repo/src/tp2.ts" "$FX/repo")
if [ -z "$second" ]; then echo "PASS: transcript_path present — the one-shot still bounds the context"
else echo "FAIL: transcript_path present — fired twice in one context: $second"; rc=1; fi

[ "$rc" -eq 0 ] && echo "All conventions-hook fixtures passed."
exit "$rc"
