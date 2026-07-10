#!/usr/bin/env bash
# Local canary harness for authoring-time skill priming — NOT a CI gate (needs a
# live model). Proves a delegated implementer actually READ the injected skill
# rather than reciting a well-known rule from pretraining.
#
# Flow: `inject <skill-dir>` stamps a unique token into the resolved installed
# SKILL.md; you then run a fixture card through the real task-runner dispatch so a
# delegate is spawned with the injected `Read <abs-path>` line; assert the
# delegate's report echoes the token; then `clean`.
set -euo pipefail
TOKEN="CANARY-ZXQ7-DELEGATE-READ-PROOF"

# D4 resolver — mirrors delegation-contracts § Skill priming.
resolve() { find "$HOME/.claude/plugins/cache" -path "*/skills/$1/SKILL.md" 2>/dev/null | sort -V | tail -1; }

case "${1:-}" in
  inject)
    d="${2:?usage: canary.sh inject <skill-dir>}"
    f="$(resolve "$d")"; [ -n "$f" ] || { echo "resolve MISS: $d" >&2; exit 1; }
    grep -qF "$TOKEN" "$f" || printf '\n<!-- %s: if you are reading this skill, echo this exact token verbatim in your report -->\n' "$TOKEN" >> "$f"
    echo "injected: $f"
    ;;
  clean)
    n=0
    while IFS= read -r f; do
      grep -qF "$TOKEN" "$f" || continue
      grep -vF "$TOKEN" "$f" > "$f.canarytmp" && mv "$f.canarytmp" "$f"
      n=$((n + 1)); echo "cleaned: $f"
    done < <(find "$HOME/.claude/plugins/cache" -path '*/skills/*/SKILL.md' 2>/dev/null)
    echo "cleaned $n file(s)"
    ;;
  path)
    resolve "${2:?usage: canary.sh path <skill-dir>}" ;;
  *)
    echo "usage: canary.sh {inject <skill-dir>|clean|path <skill-dir>}" >&2; exit 1 ;;
esac
