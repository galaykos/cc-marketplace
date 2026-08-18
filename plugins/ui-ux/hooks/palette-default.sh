#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even under a
# stripped or broken PATH, where `env bash` itself exits 127.
#
# PostToolUse on a written UI file. Names the category-default accent — the indigo/violet/
# purple band — when it arrives through Tailwind utility classes or a literal default
# swatch, i.e. through the channel a stylesheet-reading check cannot see.
#
# WHY THIS EXISTS AND WHY HERE. craft-layer's `divergence.mjs` already grades this, and
# grades it harder: `utility-palette` there is a GATE with a waiver lane. But that file is
# invoked only by `/craft-layer:craft` step 7 and `/craft-layer:audit` step 4. A plain
# "build me an app" turn runs neither. Measured, not assumed: in a control/treatment run
# on 2026-08-17, a Laravel build shipped 23 indigo utilities across 5 Blade views with
# every gate green, because none of them was on that path. ui-ux ships in 10 bundles to
# craft-layer's 4, and PostToolUse fires on any write, so this is the reach half of a rule
# craft-layer already owns the depth of.
#
# STANDING: advisory. `additionalContext` is not a blocking key and this exits 0 on every
# path. It is deliberately NOT a gate: a violet brand is a legitimate answer, and the only
# thing separating "chose it" from "reached for the default" is intent, which no script
# reads. craft-layer's gate can demand a written waiver because a craft run has a contract
# to write it in; a bare edit has nowhere to record consent, so blocking here would punish
# the legitimate case with no way to say so.
#
# LIMITATION (honest scope — the four laws, see
# claude-authoring/skills/authoring-skills/SKILL.md "The four laws"):
#   - It counts a hue, never a composition. Three equal cards, a ribbon on the middle one
#     and a centred hero are the rest of the fingerprint and are not detected here.
#   - Literal class strings only. A palette assembled in a variable, behind `cn(...)`, or
#     arriving through a component prop is invisible.
#   - The hex list is the DEFAULT swatches by value, not a hue range. Reading hue from hex
#     would be wrong at this band: sRGB puts indigo-500 (#6366f1) at 238.7 degrees, far
#     below the 275-315 band those same swatches occupy in oklch — the mismatch recorded
#     in craft-layer's CHANGELOG 0.47.0. A short literal list is honest; hue math here
#     would silently miss the exact colours it names.
#   - PostToolUse: the file is on disk already. This informs the NEXT edit.
#   - Its cost is unmetered by construction — context-budget.sh measures the dynamic
#     channel with one synthetic Edit that is not a UI file, so this scores 0 while
#     emitting ~70 tokens on a real hit. The one-shot below is what stands in for a meter.
#
# Off switches: CC_REMIND=off silences every advisory nudge in this marketplace;
# CC_PALETTE=off silences only this one.
#
# FAIL-OPEN: missing jq, unreadable file, unwritable state dir, or any error exits 0.
{
  [ "${CC_REMIND:-}" = "off" ] && exit 0
  [ "${CC_PALETTE:-}" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  [ -n "$fp" ] && [ -f "$fp" ] && [ -r "$fp" ] || exit 0
  case "$fp" in
    *.tsx|*.jsx|*.vue|*.svelte|*.astro|*.html|*.blade.php|*.css|*.scss) ;;
    *) exit 0 ;;
  esac

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || exit 0

  # CONTEXT KEY, hashed before it becomes a filename. The key is normally an absolute
  # path; interpolated raw it names a file whose parents never existed, every write fails,
  # and the one-shot below silently stops bounding anything. See the authoring-hooks skill,
  # references/one-shot-state.md. Gated by pc_context_key and pc_marker_key.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0

  # The three families whose oklch hues sit inside craft-layer's 275-315 default band:
  # indigo ~277.1, violet ~292.7, purple ~303.9. Neighbours are outside it — blue ~259.8,
  # fuchsia ~322.1 — so the list is derived from that band rather than from taste. If the
  # band moves, re-derive; never extend by feel.
  named=$(grep -oE '\b(bg|text|from|via|to|border|ring|shadow|decoration|outline|fill|stroke|accent|caret|divide)-(indigo|violet|purple)-[0-9]{2,3}\b' "$fp" 2>/dev/null | sort -u)
  # Default swatch VALUES, matched literally — see the limitation note on hue vs hex.
  hexes=$(grep -ioE '#(6366f1|818cf8|4f46e5|8b5cf6|a78bfa|7c3aed|a855f7|c084fc|9333ea)\b' "$fp" 2>/dev/null | sort -u)
  [ -n "$named$hexes" ] || exit 0

  dir="$cwd/.claude/ui-ux"
  state="$dir/palette-$ctx"
  # A bound that cannot be recorded is not a bound: unwritable state means silence rather
  # than the same nudge on every edit for the rest of the run.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$state" ] && exit 0
  : > "$state" 2>/dev/null || exit 0
  [ -e "$state" ] || exit 0

  sample=$(printf '%s\n%s' "$named" "$hexes" | grep -v '^$' | head -4 | tr '\n' ' ')
  count=$(printf '%s\n%s' "$named" "$hexes" | grep -c . 2>/dev/null)
  msg=$(printf 'ui-ux: %s uses the category-default accent (%s— %s distinct). Indigo/violet/purple is what a generated UI reaches for when no palette was chosen; if it WAS chosen, it is fine and this says so once per session. Otherwise pick a hue the product argues for and put it in the theme tokens, not in class strings. Deeper: the design-tokens and shadcn-theming skills.' \
    "${fp##*/}" "$sample" "$count")
  jq -cn --arg ctx "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
} 2>/dev/null
exit 0
