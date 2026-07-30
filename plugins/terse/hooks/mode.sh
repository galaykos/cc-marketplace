#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# UserPromptSubmit, two jobs:
#   1. Level switching — `/terse:level <lite|full|ultra|off>` and the few natural
#      phrasings for it. The hook owns the state write, not the model: a mode that
#      depends on the model remembering to run a command is not a mode.
#   2. Per-turn reinforcement — one compact line while a level is active.
#
# WHY REINFORCE THE SHAPE AND NOT THE WORDING. The mode this replaces re-injected
# "drop articles/filler/pleasantries/hedging" on every prompt: the one layer that
# already worked. Measured over three long sessions of it, mid-turn lines held at
# 17-265 characters while turn-final messages ran 1,194-4,447 — the drift is in
# message SHAPE, so the reminder carries budgets and the report skeleton instead.
#
# LIMITATION (honest scope):
#   - Advisory. `additionalContext` is not a blocking key; this can inform a turn,
#     never stop one.
#   - Costs ~120 tokens of input per prompt while active (measured: 476 chars),
#     and nothing when off.
#     That is the price of persistence; `/terse:level off` stops paying it.
#   - Natural-language switching is a narrow heuristic, not parsing. The slash
#     command is the reliable path and the one the docs name.
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

  card() { # the contract block, from the skill body — see activate.sh on why runtime
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
      # CC_TERSE beats the file (see the resolution below), so "off" cannot promise
      # silence while the environment still sets a level — say which one wins.
      case "${CC_TERSE:-}" in
        lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra)
          emit "TERSE MODE: level file cleared, but CC_TERSE=$CC_TERSE is set in the environment and overrides it — still active at $CC_TERSE. Unset CC_TERSE to stop." ;;
      esac
      emit 'TERSE MODE OFF. Normal response length resumes; no further reminders this session.'
    fi
    c=$(card)
    if [ -n "$c" ]; then
      emit "$(printf 'TERSE MODE — level: %s. Applies to chat messages only.\n\n%s' "$1" "$c")"
    fi
    emit "TERSE MODE — level: $1. Applies to chat messages only."
  }

  # ---- 1. slash commands -------------------------------------------------------
  case "$prompt" in
    /terse:level* | /terse\ * | /terse)
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
    /*) exit 0 ;; # every other slash command manages its own flow
  esac

  # ---- 2. natural-language switching -------------------------------------------
  # TRIGGER NARROWING, the reminder hooks' pattern: drop fenced blocks and
  # backticked spans, read only the head (a pasted transcript buries its keywords
  # deep), and refuse prompts that are ABOUT this machinery rather than using it.
  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-400 | tr 'A-Z' 'a-z')
  about=0
  printf '%s' "$head" | grep -qE '(delete|remove|uninstall|disable|install|list|which|audit|fix|write|edit|test)[a-z -]{0,40}(plugin|hook|reminder|skill|command)' && about=1
  # This hook's own output, echoed back in a pasted transcript. Every shape it
  # emits must be listed — the confirmation ("TERSE MODE — level: x") and the
  # far more common per-turn line ("TERSE ultra — chat message only").
  #
  # Each pattern carries enough context to stay distinct from a user typing the
  # same words. A previous version guarded on bare `terse mode off`, which is the
  # documented way to ASK for off — the guard swallowed the request and the off
  # trigger below became unreachable. The emitted line is always `TERSE MODE OFF.
  # Normal response…`, so the sentence tail is what separates echo from intent.
  printf '%s' "$head" | grep -qE 'terse mode (active|—)|terse mode off\. normal|terse (lite|full|ultra|wenyan-[a-z]+) —' && about=1

  if [ "$about" -eq 0 ]; then
    # OFF. "normal mode" is not a brevity phrase in any form — vim has one, an app
    # boots in one, a dark-mode comparison mentions one, and "get back to normal
    # mode in vim" is not a request about replies. Only length/verbosity words
    # count; the reliable off switch is /terse:level off.
    if printf '%s' "$head" | grep -qE '\b(stop|disable|turn off|exit|end) (the )?terse\b|\bterse (mode )?off\b|\bnormal (verbosity|length|replies)\b|\bback to normal (length|verbosity)\b'; then
      write_level off && confirm off
    fi
    # ON, in two shapes. `terse on` is deliberately NOT one of them: "a bit terse
    # on occasion" is prose about tone, and switching a persistent mode from it
    # turns an opt-in plugin into an ambient one.
    #
    # The level form REQUIRES the level word to end the clause — punctuation or
    # end of prompt. Without that boundary "terse ultra vires doctrine" switched
    # to ultra and "I prefer terse full sentences" switched to full: the level
    # word was being read out of the middle of an ordinary sentence.
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

  # ---- 3. per-turn reinforcement -----------------------------------------------
  level="${CC_TERSE:-}"
  if [ -z "$level" ] && [ -r "$state" ]; then
    read -r level _ < "$state" 2>/dev/null || level=""
  fi

  # wenyan levels share their latin counterpart's budgets; only the word layer
  # differs (skills/terse-output/references/wenyan.md).
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

  emit "$(printf 'TERSE %s — chat message only; full depth in the work, the code, the files, the subagent prompts. Budget: progress 1 line, %s prose lines (tables, code and trees are free). Report shape: verdict → artifacts → max 5 findings as `path:line — problem → impact` (cap waived when findings are the deliverable, e.g. an invoked review or audit) → skipped (print `none` if nothing was) → blocker → next. Cut process narration, re-summary of files just written, unchanged inventories, framing phrases, closing offers. Never drop a finding to fit — overflow goes to a file, cited by path.%s' "$level" "$b" "$w")"
} 2>/dev/null
exit 0
