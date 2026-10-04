#!/bin/bash
# generated from templates/boost-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Inject the boost directive when the prompt asks.
# One token: ultra-assess (also ultraassess / ultra-assessment). Output is findings, never task cards.
# No suffix grammar — bare tokens only, fixed tier model=auto effort=xhigh
# (auto = session model or opus, whichever is higher on haiku<sonnet<opus<fable).
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/boost-hook.sh.tmpl
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
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands own their flag path
  # CC_BOOST=off silences every boost hook and the variable plugin_switch names silences this one; either
  # /config option silences only this plugin's hook, and a non-empty environment variable wins over it.
  plugin_switch=ORCHESTRATION_BOOST
  case "$(cc_option CC_BOOST on)$(cc_option "$plugin_switch" on)" in *off*) exit 0 ;; esac

  # A real invocation is typed at the top, unquoted and not negated; a pasted log buries or quotes the token.
  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-200)
  printf '%s' "$head" | grep -qiE "(do not|don't|never|without|avoid|not) +[a-z ]{0,12}ultra" && exit 0
  # A pasted banner is a transcript; tokens are listed because ultra-?[a-z]+ matched ultrathink, so a new boost token joins this list.
  printf '%s' "$head" | grep -qiE "ultra-?(task|goal|assess(ment)?|craft) +active" && exit 0
  # Quoted heredoc: no expansion, so the manifest text is the wire text.
  if printf '%s' "$head" | grep -qiE '\bultra-?assess(ment)?\b'; then
    cat <<'CC_BOOST_DIRECTIVE'
ULTRA-ASSESS ACTIVE (model=auto, effort=xhigh) — Extreme Boost for this assessment run. Apply the task-runner ultra-assess contract (skills/verification-panels/references/ultra-assess.md): TIER subagents by role, not per-run: analytical/judgment lenses + the red-team + the completeness-critic get model:auto (model=auto resolves at dispatch to the session model or opus, whichever is higher on haiku<sonnet<opus<fable — escalate, never downgrade; on the Workflow agent() path also effort:xhigh; inline Agent dispatch escalates model only), while enumerate/locate readers and opinion-lens stay NATIVE (no override), run the fan-out → synthesize → red-team → completeness-critic recipe from the verification-panels + delegation-contracts skills with fan-out counts as CEILINGS sized to blast radius (2-voter panel small / N=3 default), print the ⚡ banner first. Output findings/backlog, NOT task cards, and write no execution marker. Fan out on EITHER dispatch path (Workflow agent() or the Agent tool); only with neither is the pass inline, labeled 'inline heuristic pass — single model, uncorroborated' (never reported as a panel).
CC_BOOST_DIRECTIVE
  fi
} 2>/dev/null
exit 0
