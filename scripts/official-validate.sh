#!/usr/bin/env bash
# official-validate.sh — the host's `claude plugin validate --strict`, one --json run per plugin plus marketplace.json (CI's twin): schema errors, unquoted ${CLAUDE_PLUGIN_ROOT} in hooks.json, .mcp.json, install-name and component-path faults validate.sh never models; FAILs a gating mod hook without .catch (pc_gating_catch).
# Misses: SKILL.md frontmatter (the host accepts invented keys — validate.sh's job), unquoted roots in commands and skills (pc_plugin_root_quoting), a .catch that still fails open. A CLI other than PIN FAILs unless OFFICIAL_VALIDATE_ANY_VERSION=1.
# Why, limits, history: rationale/derivations/scripts.md § scripts/official-validate.sh
set -u
cd "$(dirname "$0")/.." || exit 2
PIN="2.1.300"

command -v claude >/dev/null 2>&1 || { echo "FAIL: claude CLI not on PATH (CI installs @anthropic-ai/claude-code@$PIN)"; exit 1; }
export HOME; HOME="$(mktemp -d)" || exit 2
export DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
trap 'rm -rf "$HOME"' EXIT

have="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
echo "claude --version: ${have:-unknown} (pinned: $PIN)"
if [ "$have" != "$PIN" ] && [ "${OFFICIAL_VALIDATE_ANY_VERSION:-0}" != 1 ]; then
  echo "FAIL: claude $have is not the pinned $PIN — --strict semantics are version-bound; set OFFICIAL_VALIDATE_ANY_VERSION=1 to run anyway"
  exit 1
fi

. scripts/lib/plugin-checks.sh || { echo "FAIL: cannot source scripts/lib/plugin-checks.sh"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not on PATH — cannot read gatingHooks from the --json report"; exit 1; }

rc=0
out="$HOME/validate.out"   # inside the throwaway HOME, so the EXIT trap removes it
errf="$HOME/validate.err"
# One --json run per plugin carries verdict, findings and gatingHooks; a human-mode run would repeat the whole validation.
for p in plugins/*/; do
  [ -f "$p/.claude-plugin/plugin.json" ] || continue
  claude plugin validate --strict --json "$p" </dev/null >"$out" 2>"$errf" && vrc=0 || vrc=$?
  if [ "$vrc" -ne 0 ] || [ "$(jq -r '.success' "$out" 2>/dev/null)" != true ]; then
    echo "FAIL: $p (exit $vrc; --strict treats warnings as errors)"
    findings=$(jq -r '([.manifest] + (.contents // []))[] | select(((.errors // []) + (.warnings // [])) | length > 0)
      | "  \(.file)", ((.errors // [])[] | "    error: \(.path): \(.message)"), ((.warnings // [])[] | "    warning: \(.path): \(.message)")' "$out" 2>/dev/null)
    if [ -n "$findings" ]; then printf '%s\n' "$findings"; else cat "$out" "$errf"; fi
    rc=1; continue
  fi
  nocatch=$(pc_gating_catch "$out") \
    || { echo "FAIL: $p gating hook without .catch, or an unreadable --json report — a hook that throws is skipped and the action runs; chain .catch(...) answering in its place:"; printf '  %s\n' "$nocatch"; rc=1; }
done
claude plugin validate --strict .claude-plugin/marketplace.json </dev/null >"$out" 2>&1 \
  || { echo "FAIL: .claude-plugin/marketplace.json"; cat "$out"; rc=1; }
[ "$rc" -eq 0 ] && echo "OK: official validator (--strict) passed every plugin and the marketplace manifest"
exit $rc
