#!/bin/bash
# generated from templates/boost-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Inject the boost directive when the prompt asks.
# One token: ultra-craft (also ultracraft). Slash prompts exit early: /craft-layer:craft parses the token out of its own args, so the hook would double-fire the directive.
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
  plugin_switch=CRAFT_BOOST
  case "$(cc_option CC_BOOST on)$(cc_option "$plugin_switch" on)" in *off*) exit 0 ;; esac

  # A real invocation is typed at the top, unquoted and not negated; a pasted log buries or quotes the token.
  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-200)
  printf '%s' "$head" | grep -qiE "(do not|don't|never|without|avoid|not) +[a-z ]{0,12}ultra" && exit 0
  # A pasted banner is a transcript; tokens are listed because ultra-?[a-z]+ matched ultrathink, so a new boost token joins this list.
  printf '%s' "$head" | grep -qiE "ultra-?(task|goal|assess(ment)?|craft) +active" && exit 0
  # Quoted heredoc: no expansion, so the manifest text is the wire text.
  if printf '%s' "$head" | grep -qiE '\bultra-?craft\b'; then
    cat <<'CC_BOOST_DIRECTIVE'
ULTRA-CRAFT ACTIVE (model=auto, effort=xhigh) — Extreme Boost for this craft run. Apply the craft-layer 'ultra-craft' skill (skills/ultra-craft/SKILL.md): pin the offer contract's Ambition row to `maximal` and its Mode row to `guided`, stamp `Boost: ultra-craft` into the persisted contract, and honor the six bindings. Research is LIVE — fetch every source, six minimum across three lanes, each with URL, fetch date and a why-line per skills/ultra-craft/references/research-mandate.md; recall is a lead labeled unverified, never a backing. Search all three NAMED galleries with a category-scoped query and record each query: land-book.com (shipped page structure), awwwards.com (reach and signature candidates), dribbble.com (visual direction ONLY — a shot is a concept, never evidence a pattern ships). The search floor and the source floor are separate counts; a blocked fetch is recorded as searched-and-blocked, never covered with recall. Persist and ECHO craft/reference-board.md before any token is generated, and let the user confirm or redirect there. Reasoning subagents (creative-director, craft-reviewer) dispatch model:auto — session model or opus, whichever is higher, escalate never downgrade; effort xhigh on the Workflow path, inline dispatch escalates model only; builders and token generation stay NATIVE. After the audit, red-team the shipped tree against the contract and divergence record, N=3 as a ceiling sized to blast radius; no dispatch mechanism (neither the Workflow tool nor the Agent tool) means ONE inline pass labeled 'inline heuristic pass — single model, uncorroborated'. The panel owes three rules from skills/ultra-craft/references/red-team-contract.md: SWEEP an interactive signature's reachable state space rather than reasoning about representative values and report states-swept/states-violating with a reproducing input; attack the post-audit FIX LIST as its own claim set, because a fix report is a confident self-assessment by the author of the defects; and RENDER the surface and open the image before calling it verified, retrying with an absolute path in an allowed root before concluding capture is unavailable. Every ceiling holds unchanged — reduced-motion, per-tier and cumulative motion budgets, accent contrast, licence and provenance, accessibility. Print the ⚡ banner first with the cost line; where the brief also asks for fast or cheap, ASK which order wins.
CC_BOOST_DIRECTIVE
  fi
} 2>/dev/null
exit 0
