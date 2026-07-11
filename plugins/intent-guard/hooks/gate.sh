#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# Stop: hold turn completion while ledgered actions are unattested or drift is unresolved.
# An action's seq is its 1-based ordinal among action rows (assigned here at read time). The block
# is decided from per-seq attestation entries (each needing a verdict AND a criterion), NOT a
# high-water integer — so writing {"through_seq":N,"attestations":[]} does not clear the gate.
# Fail-open: any error or a missing jq exits 0. Uses stop_hook_active as the native loop-guard.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
  [ "$active" = "true" ] && exit 0   # already continuing from a prior gate block this turn

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  dir="$cwd/.claude/intent-guard"
  intent="$dir/intent.json"
  ledger="$dir/ledger.jsonl"
  attest="$dir/attest.json"

  [ -f "$intent" ] || exit 0   # guard not engaged this session (benign, silent)

  # Disabled-visible: engaged but state corrupt — say so, never silently pass.
  if ! jq empty "$intent" 2>/dev/null; then
    printf 'intent-guard: DISABLED (intent.json unreadable) — turn-end gate is OFF.\n'
    exit 0
  fi
  x=$(jq -r '.intent // "the declared task"' "$intent" 2>/dev/null)

  maxseq=$(grep -c '"kind":"action"' "$ledger" 2>/dev/null || echo 0)
  [ "$maxseq" -gt 0 ] 2>/dev/null || exit 0   # nothing recorded, nothing to gate

  # Attested seqs = attestation entries with BOTH a non-empty verdict and criterion.
  attested=""; open_drift=0
  if [ -f "$attest" ] && jq empty "$attest" 2>/dev/null; then
    attested=$(jq -r '[.attestations[]? | select((.verdict//"")!="" and (.criterion//"")!="") | .seq] | @csv' "$attest" 2>/dev/null)
    open_drift=$(jq -r '[.attestations[]? | select(.verdict=="drift" and (.accepted!=true))] | length' "$attest" 2>/dev/null)
  fi

  # Unattested = action ordinals (1..N by file order) absent from the attested set.
  unatt=0; missing=""; i=0
  while read -r kind; do
    [ "$kind" = "action" ] || continue
    i=$(( i + 1 ))
    case ",$attested," in
      *",$i,"*) : ;;
      *) unatt=$(( unatt + 1 )); missing="$missing $i" ;;
    esac
  done <<EOF
$(jq -r '.kind // empty' "$ledger" 2>/dev/null)
EOF
  missing=$(printf '%s' "$missing" | sed 's/^ *//')

  if [ "$unatt" -gt 0 ] 2>/dev/null || [ "$open_drift" -gt 0 ] 2>/dev/null; then
    reason="intent-guard: ${unatt} action(s) unattested (seqs: ${missing:-none}) and ${open_drift} unresolved drift vs intent «${x}». Attest each seq in .claude/intent-guard/attest.json (verdict+criterion, via the Write tool); revert or user-accept drift; then finish."
    jq -cn --arg r "$reason" '{decision:"block",reason:$r}' 2>/dev/null
    exit 0
  fi
} 2>/dev/null
exit 0
