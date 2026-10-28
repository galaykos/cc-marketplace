#!/usr/bin/env bash
# level.sh [--sources] — prints "<level> <source>" (env|file|option|off): the first non-empty of CC_TERSE, the level file's first word, the cc_terse option (CLAUDE_PLUGIN_OPTION_CC_TERSE, else managed-settings.json, then user settings.json), else off. --sources prints each layer, asking `claude plugin configure` first (~0.45 s). Exits 0.
# Misses: --settings files, managed-settings.d drop-ins, MDM or server-managed policy, a symlinked settings file; without jq, every settings file. CANDOR_MANAGED_SETTINGS (test-only) replaces the managed-settings path.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/scripts/level.sh
{
  cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  state="$cfg/terse-mode"
  case "$(uname -s)" in
    Darwin) managed="/Library/Application Support/ClaudeCode/managed-settings.json" ;;
    MINGW* | MSYS* | CYGWIN*) managed="C:/Program Files/ClaudeCode/managed-settings.json" ;;
    *) managed="/etc/claude-code/managed-settings.json" ;;
  esac
  managed="${CANDOR_MANAGED_SETTINGS:-$managed}"

  saved() { # saved <settings-file>
    [ -f "$1" ] && [ -r "$1" ] || return 0
    jq -r 'first(.pluginConfigs? | objects | to_entries[] | select(.key | startswith("candor@"))
      | .value | objects | .options | objects | .cc_terse | strings | select(. != "")) // empty' "$1"
  }

  env_v="${CC_TERSE:-}"
  file_v=""
  # The 1 KiB cap keeps the badge's per-keystroke read bounded; the hooks read the whole line.
  [ -f "$state" ] && [ -r "$state" ] && read -r file_v _ <<< "$(head -c 1024 "$state")"
  opt_v="${CLAUDE_PLUGIN_OPTION_CC_TERSE:-}"; opt_at=CLAUDE_PLUGIN_OPTION_CC_TERSE
  case "$opt_v" in true) opt_v=on ;; false) opt_v=off ;; esac
  if [ -z "$opt_v" ]; then
    opt_at="none saved in managed or user settings"
    host_v=""
    if [ "${1:-}" = --sources ] && command -v claude >/dev/null && command -v jq >/dev/null; then
      # configure wants the full id; an install sits at plugins/cache/<marketplace>/candor/<version>, a --plugin-dir or checkout does not.
      plug=$(cd "$(dirname "$0")/../.." && pwd -P)
      if [ "$(basename "$plug")" = candor ] && [ "$(basename "$(dirname "$(dirname "$plug")")")" = cache ]; then
        host_id="candor@$(basename "$(dirname "$plug")")"
        tmo=""; command -v timeout >/dev/null && tmo="timeout 10"
        host_v=$($tmo claude plugin configure "$host_id" --json </dev/null | jq -er '.inputs | objects | (.cc_terse // "") | strings') \
          && host_v="ok:$host_v" || host_v=""
      fi
    fi
    if [ -n "$host_v" ]; then
      opt_v=${host_v#ok:}
      opt_at="claude plugin configure $host_id: user, managed and drop-ins; not this session's --settings"
    elif [ -n "$env_v$file_v" ] && [ "${1:-}" != --sources ]; then
      : # a higher layer decided; the badge skips jq on every keystroke
    elif command -v jq >/dev/null; then
      for f in "$managed" "$cfg/settings.json"; do
        [ -L "$f" ] && { opt_at="$f not read (symlink)"; continue; }
        opt_v=$(saved "$f")
        [ -n "$opt_v" ] && { opt_at=$f; break; }
      done
    else
      opt_at="settings not read: jq missing"
    fi
  fi

  if [ -n "$env_v" ]; then level=$env_v src=env
  elif [ -n "$file_v" ]; then level=$file_v src=file
  elif [ -n "$opt_v" ]; then level=$opt_v src=option
  else level=off src=off
  fi
  case "$level" in lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra) ;; *) level=off ;; esac

  if [ "${1:-}" = --sources ]; then
    printf 'CC_TERSE: %s\n' "${env_v:-unset}"
    printf 'level file (%s): %s\n' "$state" "${file_v:-none}"
    printf 'cc_terse option (%s): %s\n' "$opt_at" "${opt_v:-unset}"
    printf 'active: '
  fi
  printf '%s %s\n' "$level" "$src"
} 2>/dev/null
exit 0
