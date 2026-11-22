#!/bin/bash
# expo-prebuild-guard.sh — PreToolUse on Bash: asks before `expo prebuild` without --no-clean (SDK 57+ wipes ios/ and android/) when those dirs hold uncommitted or untracked-unignored files, or are committed and not gitignored (bare); outside git, whenever either dir exists. Silent below SDK 57 unless --clean is typed.
# Misses: prebuild behind a wrapper (`npm run prebuild`, a Makefile, `eas build --local`), a cd it cannot follow, an expo version it cannot read (treated as 57+). Fails open: no jq, no ask; always exits 0.
# Why, limits, history: rationale/derivations/plugin-web-dev.md § plugins/web-dev/hooks/expo-prebuild-guard.sh

command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
  case "$cmd" in *prebuild*) ;; *) exit 0 ;; esac
  base=$(printf '%s' "$input" | jq -r '.cwd // empty')
  [ -n "$base" ] || base="$PWD"

  expo_major() { # dir -> installed expo major, else the package.json range's first number, else empty
    local d="$1" v=""
    [ -f "$d/node_modules/expo/package.json" ] && v=$(jq -r '.version // empty' "$d/node_modules/expo/package.json")
    [ -n "$v" ] || { [ -f "$d/package.json" ] && v=$(jq -r '(.dependencies.expo // .devDependencies.expo // empty)' "$d/package.json"); }
    v=$(printf '%s' "$v" | sed -n 's/^[^0-9]*\([0-9][0-9]*\).*/\1/p')
    printf '%s' "$v"
  }

  nl=$'\n'; segs=${cmd//&&/$nl}; segs=${segs//||/$nl}; segs=${segs//;/$nl}; segs=${segs//|/$nl}
  dir="$base"; reason=""
  while IFS= read -r seg; do
    read -r -a w <<<"$seg"
    i=0
    while [ "$i" -lt "${#w[@]}" ]; do case "${w[$i]}" in *=*|sudo|env|command|time) i=$((i+1)) ;; *) break ;; esac; done
    [ "$i" -lt "${#w[@]}" ] || continue
    if [ "${w[$i]}" = cd ]; then
      t="${w[$((i+1))]:-}"; t=${t//[\"\']/}
      case "$t" in '') ;; /*) dir="$t" ;; *) dir="$dir/$t" ;; esac
      continue
    fi
    # Runner words before `expo`: npx / bunx / pnpm / yarn / npm exec / dlx, and their flags.
    while [ "$i" -lt "${#w[@]}" ]; do
      case "${w[$i]}" in npx|bunx|pnpm|yarn|npm|exec|dlx|-*) i=$((i+1)) ;; *) break ;; esac
    done
    case "${w[$i]:-}" in expo|expo@*|*/expo) ;; *) continue ;; esac
    [ "${w[$((i+1))]:-}" = prebuild ] || continue
    rest=" ${w[*]:$((i+2))} "
    case "$rest" in *" --no-clean "*) continue ;; esac
    dirs="ios android"
    case "$rest" in *" --platform ios "*|*" -p ios "*) dirs=ios ;; *" --platform android "*|*" -p android "*) dirs=android ;; esac
    present=""
    for n in $dirs; do [ -d "$dir/$n" ] && present="$present $n"; done
    [ -n "$present" ] || continue
    label=$(for n in $present; do printf '%s/ ' "$n"; done); label=${label% }
    major=$(expo_major "$dir")
    case "$rest" in *" --clean "*) ;; *) [ -n "$major" ] && [ "$major" -lt 57 ] && continue ;; esac
    # shellcheck disable=SC2086
    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if [ -n "$(git -C "$dir" status --porcelain --untracked-files=all -- $present | head -n 1)" ]; then
        reason="uncommitted or untracked files under $label would be lost"
      else
        nt=$(git -C "$dir" ls-files -- $present | wc -l)
        ni=$(git -C "$dir" ls-files -ci --exclude-standard -- $present | wc -l)
        [ "$nt" -gt "$ni" ] && reason="$label: committed and not gitignored, so a bare workflow where native files are source"
      fi
    else
      reason="$label: present outside any git checkout, so nothing can restore them"
    fi
    [ -n "$reason" ] && break
  done <<EOF
$segs
EOF

  [ -n "$reason" ] || exit 0
  jq -cn --arg r "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask",
    permissionDecisionReason: ("expo prebuild without --no-clean deletes and regenerates ios/ and android/ (the SDK 57+ default): " + $r
      + ". Use npx expo prebuild --no-clean, or move the native change into a config plugin first (web-dev react-native-best-practices, references/expo.md).")}}'
} 2>/dev/null
exit 0
