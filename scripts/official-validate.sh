#!/usr/bin/env bash
# official-validate.sh — run the host's own plugin validator, strict, over every
# plugin and the marketplace manifest. The local twin of the CI step
# "Official plugin validator (--strict)" in .github/workflows/validate.yml, so a
# contributor green on the four repo gates is not red only in CI.
#
# WHAT IT CATCHES that validate.sh does not — each probed with a crafted plugin on
# CLI 2.1.300, 2026-10-15; the release that added it in brackets:
#   - plugin.json / marketplace.json SCHEMA errors — unrecognized fields, wrong
#     types — because validate.sh models named fields only;
#   - a shell-form hooks.json command leaving `${CLAUDE_PLUGIN_ROOT}` unquoted [2.1.281];
#   - an .mcp.json entry the loader would silently drop, a `${user_config.*}`
#     reference plugin.json does not declare, an http:// URL to a non-loopback host [2.1.281];
#   - a marketplace.json plugin name Claude Code cannot install [2.1.283];
#   - an outputStyles / themes / monitors / lspServers path that is missing or
#     leaves the plugin directory [2.1.283];
#   - a hooks module the host refuses (an `on()` event name that is not a literal).
# `--strict` promotes the CLI's warnings to errors.
# GATING HOOKS. The CLI LISTS every mod hook at a gating site with whether its
# registration carries a `.catch` (`gatingHooks` under --json) [2.1.290], as a note:
# --strict passes a missing `.catch`. A gating hook that throws is skipped and the
# action runs — the guard fails open — so this script fails `hasCatch: false` itself
# (pc_gating_catch). It reads PRESENCE, not policy: a `.catch` that answers `next(e)`
# fails open too, and passes here. Below 2.1.290 (reachable only with
# OFFICIAL_VALIDATE_ANY_VERSION=1) the key is absent and that half passes vacuously.
# WHAT IT DOES NOT: SKILL.md frontmatter typos (measured 2026-08-20 accepting an
# invented `bogusfield:` key — rationale/distillation-strategy-2026-08-20.md:37;
# still accepted on 2.1.300); that remains validate.sh's job. Nor an unquoted
# `${CLAUDE_PLUGIN_ROOT}` in a command or skill — the host reads hooks.json only
# (validate.sh's pc_plugin_root_quoting, FAIL).
#
# PIN. The CLI version is asserted, not assumed: `--strict` semantics drift with
# releases, so a run on any other version is reported and fails unless
# OFFICIAL_VALIDATE_ANY_VERSION=1. CI installs the pinned npm package; locally you
# run whatever `claude` is on PATH and this script tells you if it differs.
#
# EGRESS. HOME is a throwaway dir, the auto-updater and non-essential traffic are
# disabled, stdin is closed — the verdict cannot depend on network or a prompt.
# Measured 2026-09-03 (darwin arm64 native binary): unauthenticated, no prompt,
# 44/44 + manifest in ~25 s. The linux-x64 npm channel is measured by CI itself.
#
# Standing: gate (a named, fail-capable CI step) — and a local pre-push check.
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
for p in plugins/*/; do
  [ -f "$p/.claude-plugin/plugin.json" ] || continue
  claude plugin validate --strict "$p" </dev/null >"$out" 2>&1 \
    || { echo "FAIL: $p"; cat "$out"; rc=1; continue; }
  claude plugin validate --strict --json "$p" </dev/null >"$out" 2>/dev/null
  nocatch=$(pc_gating_catch "$out") \
    || { echo "FAIL: $p gating hook without .catch, or an unreadable --json report — a hook that throws is skipped and the action runs; chain .catch(...) answering in its place:"; printf '  %s\n' "$nocatch"; rc=1; }
done
claude plugin validate --strict .claude-plugin/marketplace.json </dev/null >"$out" 2>&1 \
  || { echo "FAIL: .claude-plugin/marketplace.json"; cat "$out"; rc=1; }
[ "$rc" -eq 0 ] && echo "OK: official validator (--strict) passed every plugin and the marketplace manifest"
exit $rc
