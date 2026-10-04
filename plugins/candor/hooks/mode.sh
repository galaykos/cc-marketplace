#!/bin/bash
# mode.sh (UserPromptSubmit; payload on stdin) — switches the terse level on `/candor:level <level>` or a narrow natural-language request,
#   writing the level file; while a level is active, adds one budget line to each other prompt. Advisory; fails open; always exits 0.
# The level: CC_TERSE, then the level file, then the /config option cc_terse.
# Misses: a switch phrased outside its few patterns (the slash command is the reliable path); the budget line after a prompt its
#   negation or question guard stops.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/mode.sh

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

{
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  [ -n "$prompt" ] || exit 0

  cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  state="$cfg/terse-mode"
  root="${CLAUDE_PLUGIN_ROOT:-}"
  skill="$root/skills/terse-output/SKILL.md"

  emit() { # emit <text> — as UserPromptSubmit context, or not at all
    jq -cn --arg m "$1" \
      '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$m}}' 2>/dev/null
    exit 0
  }

  card() { # the skill body's marked contract block, read at runtime so the injected card cannot drift from it
    [ -n "$root" ] && [ -r "$skill" ] || return 0
    awk '/<!-- terse-contract:start -->/{f=1; next} /<!-- terse-contract:end -->/{f=0} f' "$skill" 2>/dev/null
  }

  write_level() { # write_level <lite|full|ultra|off>
    [ -L "$state" ] && return 1 # never follow a symlink into someone else's file
    if [ "$1" = "off" ]; then
      rm -f "$state" 2>/dev/null
      return 0
    fi
    mkdir -p "$cfg" 2>/dev/null || return 1
    printf '%s\n' "$1" > "$state.$$" 2>/dev/null || return 1
    mv -f "$state.$$" "$state" 2>/dev/null || { rm -f "$state.$$" 2>/dev/null; return 1; }
  }

  confirm() { # confirm <level> — level just changed, so re-state the whole contract
    if [ "$1" = "off" ]; then
      # CC_TERSE and the cc_terse option outlive the removed file, so "off" names whichever still sets a level.
      lvl=$(cc_option CC_TERSE off)
      case "$lvl" in
        lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra)
          [ -n "$CC_TERSE" ] && emit "TERSE MODE: level file cleared, but CC_TERSE=$CC_TERSE is set in the environment and overrides it — still active at $CC_TERSE. Unset CC_TERSE to stop."
          emit "TERSE MODE: level file cleared, but the candor /config option cc_terse keeps it active at $lvl. Set cc_terse to off in /config to stop." ;;
      esac
      emit 'TERSE MODE OFF. Normal response length resumes; no further reminders this session.'
    fi
    c=$(card)
    if [ -n "$c" ]; then
      emit "$(printf 'TERSE MODE — level: %s. Applies to chat messages only.\n\n%s' "$1" "$c")"
    fi
    emit "TERSE MODE — level: $1. Applies to chat messages only."
  }

  slash=0
  case "$prompt" in
    /candor:level* | /candor\ * | /candor)
      arg=$(printf '%s' "$prompt" | tr 'A-Z' 'a-z' | awk '{print $2}')
      case "$arg" in
        wenyan) write_level wenyan-full && confirm wenyan-full ;; # documented alias
        lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra)
          write_level "$arg" && confirm "$arg" ;;
        off | stop | disable) write_level off && confirm off ;;
        *) exit 0 ;; # bare or unknown arg: the command file reports current state
      esac
      exit 0
      ;;
    /*) slash=1 ;; # another command's arguments describe a task: they never switch the level, but the budget line still prints
  esac

  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-400 | tr 'A-Z' 'a-z')
  about=$slash
  printf '%s' "$head" | grep -qE '(delete|remove|uninstall|disable|install|list|which|audit|fix|write|edit|test)[a-z -]{0,40}(plugin|hook|reminder|skill|command)' && about=1
  # This hook's own lines, echoed back in a pasted transcript, are not a request.
  printf '%s' "$head" | grep -qE 'terse mode (active|—)|terse mode off\. normal|terse (lite|full|ultra|wenyan-[a-z]+) —' && about=1

  if [ "$about" -eq 0 ]; then
    if printf '%s' "$head" | grep -qE '\b(stop|disable|turn off|exit|end) (the )?terse\b|\bterse (mode )?off\b|\b(back to|resume|return to|go back to) normal (length|verbosity|replies)\b|\bbe more verbose\b|\bstop being terse\b'; then
      write_level off && confirm off
    fi
    printf '%s' "$head" | grep -qE "(do ?n.?t|don't|never|no need to|without|avoid|stop|rather not|hate|dislike)[a-z ,'’-]{0,30}(terse|enable|activate|turn on)" && exit 0
    # "is that terse full?" is a question about the mode, not a request for it.
    case "$head" in \?*|*\?) printf '%s' "$head" | grep -qE '^(is|are|was|does|did|what|why|how)\b' && exit 0 ;; esac
    on_verb='\bterse mode on\b|\b(enable|activate|turn on) terse( mode)?\b'
    on_level='\bterse( mode| level| to)* (lite|full|ultra|wenyan(-(lite|full|ultra))?)[[:space:]]*([.,!?;]|$)'
    if printf '%s' "$head" | grep -qE "$on_level"; then
      lvl=$(printf '%s' "$head" | grep -oE "$on_level" | head -1 |
            tr -d '.,!?;' | awk '{print $NF}')
      [ "$lvl" = "wenyan" ] && lvl=wenyan-full
      write_level "$lvl" && confirm "$lvl"
    elif printf '%s' "$head" | grep -qE "$on_verb"; then
      write_level full && confirm full
    fi
  fi

  level=$(cc_option CC_TERSE off "$state")

  # wenyan levels share their latin counterpart's budgets (skills/terse-output/references/wenyan.md).
  case "$level" in
    lite | wenyan-lite)   b='answer 10, report 18' ;;
    full | wenyan-full)   b='answer 6, report 12' ;;
    ultra | wenyan-ultra) b='answer 3, report 6' ;;
    *) exit 0 ;;
  esac
  case "$level" in
    wenyan-*) w=' Write in 文言 per references/wenyan.md; identifiers, paths and error strings stay verbatim.' ;;
    *) w='' ;;
  esac

  emit "$(printf 'TERSE %s — chat message only; full depth in the work, the code, the files, the subagent prompts. Budget: progress 1 line, %s prose lines (tables, code and trees are free). Report shape: verdict → blocker or decision (only if the user must act) → artifacts → max 5 findings as `path:line — problem → impact` (cap waived when findings are the deliverable, e.g. an invoked review or audit) → skipped (print `none` if nothing was) → next. Cut process narration, re-summary of files just written, unchanged inventories, framing phrases, closing offers. Never drop a finding to fit — overflow goes to a file, cited by path.%s' "$level" "$b" "$w")"
} 2>/dev/null
exit 0
