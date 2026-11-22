#!/bin/bash
# package-command-guard.sh — PreToolUse on Bash. Denies `npx|bunx|npm exec astryx` when no package.json up the tree declares @astryxdesign/cli, and `pnpm dlx|yarn dlx astryx` or `astryx@<ver>` always (registry fetches). Asks before an npm/pnpm/yarn/bun install naming primereact bare, @latest or @11, @primereact/ui, or @primeuix/themes bare, @latest or @3, while the nearest lockfile resolves primereact 10.x.
# Misses: hand edits to package.json, npm update, ncu, Renovate, bun.lockb, `npx -p`, a cd it cannot follow, and a CLI declared but not yet installed. Fails open: no jq, no verdict; always exits 0.
# Why, limits, history: rationale/derivations/plugin-ui-libraries.md § plugins/ui-libraries/hooks/package-command-guard.sh

command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
  case "$cmd" in *astryx*|*primereact*|*primeuix*) ;; *) exit 0 ;; esac
  base=$(printf '%s' "$input" | jq -r '.cwd // empty')
  [ -n "$base" ] || base="$PWD"

  cli_declared() { # dir -> 0 when a package.json at or above it declares @astryxdesign/cli
    local d="$1" n=0
    while [ -n "$d" ] && [ "$n" -lt 40 ]; do
      [ -f "$d/package.json" ] && jq -e '((.dependencies // {}) + (.devDependencies // {})) | has("@astryxdesign/cli")' "$d/package.json" >/dev/null && return 0
      [ "$d" = / ] && break
      d=$(dirname "$d"); n=$((n+1))
    done
    return 1
  }
  locks_v10() { # dir -> 0 when the nearest lockfile dir resolves primereact 10.x
    local d="$1" n=0 v
    while [ -n "$d" ] && [ "$n" -lt 40 ]; do
      if [ -f "$d/package-lock.json" ] || [ -f "$d/npm-shrinkwrap.json" ] || [ -f "$d/pnpm-lock.yaml" ] || [ -f "$d/yarn.lock" ] || [ -f "$d/bun.lock" ]; then
        for f in "$d/package-lock.json" "$d/npm-shrinkwrap.json"; do
          [ -f "$f" ] || continue
          v=$(jq -r '(.packages["node_modules/primereact"].version // .dependencies.primereact.version // empty)' "$f")
          case "$v" in 10.*) return 0 ;; esac
        done
        [ -f "$d/pnpm-lock.yaml" ] && grep -qE "(^|[[:space:]'/])primereact[@/]10\." "$d/pnpm-lock.yaml" && return 0
        [ -f "$d/bun.lock" ] && grep -qE '"primereact@10\.' "$d/bun.lock" && return 0
        [ -f "$d/yarn.lock" ] && awk '/^[^[:space:]]/ { inb = ($0 ~ /^"?primereact@/) } inb && /^[[:space:]]+version:?[[:space:]]+"?10\./ { f = 1 } END { exit !f }' "$d/yarn.lock" && return 0
        return 1
      fi
      [ "$d" = / ] && break
      d=$(dirname "$d"); n=$((n+1))
    done
    return 1
  }

  nl=$'\n'; segs=${cmd//&&/$nl}; segs=${segs//||/$nl}; segs=${segs//;/$nl}; segs=${segs//|/$nl}
  dir="$base"; deny=""; ask=""
  while IFS= read -r seg; do
    read -r -a w <<<"$seg"
    i=0
    while [ "$i" -lt "${#w[@]}" ]; do case "${w[$i]}" in *=*|sudo|env|command|time) i=$((i+1)) ;; *) break ;; esac; done
    [ "$i" -lt "${#w[@]}" ] || continue
    tool="${w[$i]}"; sub="${w[$((i+1))]:-}"
    if [ "$tool" = cd ]; then
      t=${sub//[\"\']/}
      case "$t" in '') ;; /*) dir="$t" ;; *) dir="$dir/$t" ;; esac
      continue
    fi
    # Astryx: which runner, and does it fall back to the registry?
    j=""; always=""
    case "$tool $sub" in
      "npx "*|"bunx "*) j=$((i+1)) ;;
      "npm exec") j=$((i+2)) ;;
      "pnpm dlx"|"yarn dlx") j=$((i+2)); always=1 ;;
    esac
    if [ -n "$j" ]; then
      while [ "$j" -lt "${#w[@]}" ]; do case "${w[$j]}" in -*) j=$((j+1)) ;; *) break ;; esac; done
      p="${w[$j]:-}"; p=${p//[\"\']/}
      case "$p" in astryx@*) always=1 ;; esac
      case "$p" in
        astryx|astryx@*)
          if [ -n "$always" ] || ! cli_declared "$dir"; then
            deny="\`$tool ${p}\` runs the unrelated npm package named astryx, not Astryx's CLI. Run it as npx @astryxdesign/cli ${w[*]:$((j+1))}"
            deny="${deny% }"
            break
          fi ;;
      esac
      continue
    fi
    # PrimeReact: an install that moves a v10 project onto v11.
    case "$tool $sub" in
      "npm install"|"npm i"|"npm in"|"npm add"|"pnpm add"|"pnpm install"|"pnpm i"|"yarn add"|"bun add"|"bun install"|"bun i") ;;
      *) continue ;;
    esac
    hit=""
    for a in "${w[@]:$((i+2))}"; do
      a=${a//[\"\']/}
      case "$a" in
        primereact|primereact@latest|primereact@11*|primereact@^11*|primereact@~11*) hit="$a" ;;
        @primereact/ui|@primereact/ui@*) hit="$a" ;;
        @primeuix/themes|@primeuix/themes@latest|@primeuix/themes@3*|@primeuix/themes@^3*|@primeuix/themes@~3*) hit="$a" ;;
      esac
      [ -n "$hit" ] && break
    done
    [ -n "$hit" ] && locks_v10 "$dir" && ask="$hit"
  done <<EOF
$segs
EOF

  if [ -n "$deny" ]; then
    jq -cn --arg r "$deny" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: ($r + " (ui-libraries astryx-best-practices).")}}'
  elif [ -n "$ask" ]; then
    jq -cn --arg p "$ask" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask",
      permissionDecisionReason: ("The lockfile resolves primereact 10.x, and " + $p + " installs the v11 line: a rewrite under the keyed PrimeUI licence. Pin primereact@^10 (or primereact@v10-stable) unless the user asked to migrate (ui-libraries primereact-best-practices, section 9).")}}'
  fi
} 2>/dev/null
exit 0
