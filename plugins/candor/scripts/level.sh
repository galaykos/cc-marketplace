#!/usr/bin/env bash
# Prints the terse level in force and the layer that set it, "<level> <source>" with source one
# of env|file|option|off, by the hooks' rule (cc_option CC_TERSE off <level-file>, hooks/mode.sh):
# the first non-empty of CC_TERSE, the level file's first word, the cc_terse option, else off.
# A value outside the vocabulary is off; it never falls through to the next layer.
#
# The option is CLAUDE_PLUGIN_OPTION_CC_TERSE where the host exports it — to hooks, not to the
# Bash tool (measured on 2.1.286) — else a saved pluginConfigs["candor@*"].options.cc_terse in
# managed-settings.json, then in the user settings.json; managed wins, as on the host.
# NOT READ: --settings files, managed-settings.d drop-ins, MDM or server-managed policy, and a
# symlinked settings file; without jq, no settings file at all.
# CANDOR_MANAGED_SETTINGS replaces the managed-settings path; test-only, for the harness.
#
# --sources prints each layer's raw value before the winner. Exits 0, silent on stderr.
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
    if [ -n "$env_v$file_v" ] && [ "${1:-}" != --sources ]; then
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
