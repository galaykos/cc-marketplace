#!/usr/bin/env bash
# Codex parity + freshness gate. Sibling of validate.sh: proves the committed Codex tree
# (.agents/, codex/, AGENTS.md) is a fresh, correct, drift-free derivation of plugins/**.
# `--regen` just regenerates the tree (author convenience); no args = read-only gate.
set -u
cd "$(dirname "$0")/.."
GEN=scripts/gen-codex
fail=0
err() { echo "FAIL: $1" >&2; fail=1; }

command -v node >/dev/null 2>&1 || { echo "FAIL: node is required" >&2; exit 1; }

if [ "${1:-}" = "--regen" ]; then
  node "$GEN/gen.mjs"
  exit $?
fi

# 1. Freshness — regenerate to a temp dir and diff against the working tree. Git-independent:
#    proves the committed/working tree equals a fresh regeneration (no hand-edit, no stale output).
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
GEN_CODEX_OUT="$tmp" node "$GEN/gen.mjs" >/dev/null || { echo "FAIL: generator errored" >&2; exit 1; }
for root in .agents codex; do
  if ! diff -r "$tmp/$root" "./$root" >/dev/null 2>&1; then
    err "generated $root/ is stale or hand-edited (differs from a fresh regen) — run: node $GEN/gen.mjs"
  fi
done
if ! diff "$tmp/AGENTS.md" ./AGENTS.md >/dev/null 2>&1; then
  err "AGENTS.md is stale or hand-edited — run: node $GEN/gen.mjs"
fi

# 2. The generator must never touch plugins/ (guarded in gen.mjs; assert nothing changed there).
[ -z "$(git status --porcelain -- plugins/ 2>/dev/null)" ] || err "plugins/ changed during generation (must never)"

# 3. Grep double-checks over the committed tree (defense in depth; validate.mjs also checks).
if grep -rIl 'CLAUDE_PLUGIN_ROOT' .agents codex >/dev/null 2>&1; then
  err "CLAUDE_PLUGIN_ROOT present in the generated tree (should be PLUGIN_ROOT)"
fi
if find codex -name hooks.json -exec grep -l '"SessionEnd"' {} + >/dev/null 2>&1; then
  err "SessionEnd present in a generated hooks.json (must be dropped)"
fi

# 4. Structural checks: correspondence, name==dir, skill-name uniqueness, agent TOML validity,
#    catalog/manifest pointer resolution.
node "$GEN/validate.mjs" || err "structural checks failed"

[ "$fail" -eq 0 ] && echo "OK: codex marketplace valid" || exit 1
