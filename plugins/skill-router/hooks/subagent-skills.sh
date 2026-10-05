#!/bin/bash
# subagent-skills.sh — SubagentStart for a plugin-scoped agent, fails open: hands it the absolute SKILL.md Read paths of the skills its
#   bestpractices-skill: frontmatter declares and prime.sh's rows find at the project root, owner installed, minus its skills: preloads.
# Off: CC_SUBAGENT_SKILLS=off (this hook) or CC_REMIND=off (every advisory nudge); unset, the /config options cc_subagent_skills / cc_remind decide.
# Misses: a declared skill with no prime.sh row (motion-best-practices, security-review, performance-tuning, observability-design) and
#   prime.sh's own misses; a path past the CAP-character output. Advisory: it cannot make the agent Read. Another marketplace's plugin of
#   the same name resolves against this one's definition.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/hooks/subagent-skills.sh

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
  CAP=700
  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  case "$(cc_option CC_SUBAGENT_SKILLS on)" in off) exit 0 ;; esac
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  agent=$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  case "$agent" in *:*) ;; *) exit 0 ;; esac
  plugin="${agent%%:*}"; name="${agent#*:}"
  # Both halves become path segments below; anything but a plain name is not ours.
  case "$plugin" in ''|*[!a-z0-9._-]*|.*) exit 0 ;; esac
  case "$name" in ''|*[!a-zA-Z0-9._-]*|.*) exit 0 ;; esac
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0

  here=$(dirname "$0")
  PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"
  . "$here/plugins-dir.sh" 2>/dev/null || exit 0
  pr_resolve_plugins_dir
  # No plugins root, no path to name: silence here, unlike route.sh's fire-if-uncertain.
  [ -n "$PLUGINS_DIR" ] || exit 0
  pr_plugin_installed "$plugin" || exit 0
  proot=$(pr_plugin_root "$plugin")
  [ -n "$proot" ] || exit 0

  # The host reports the frontmatter `name`, not the filename; the scan finds an agent file named otherwise.
  def="$proot/agents/$name.md"
  if [ ! -f "$def" ]; then
    def=""
    for f in "$proot"/agents/*.md; do
      [ -f "$f" ] || continue
      awk -v n="$name" '/^---[[:space:]]*$/{c++; if (c == 2) exit 1; next}
        c == 1 && /^name:/ {v = $0; sub(/^name:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v); exit (v == n ? 0 : 1)}
        END {exit 1}' "$f" && { def="$f"; break; }
    done
    [ -n "$def" ] || exit 0
  fi

  # Frontmatter only: `skills:` inline (`[a, b]`, `a, b`) or as a block list, its plugin prefix dropped.
  declared=$(awk '/^---[[:space:]]*$/{c++; if (c == 2) exit; next}
    c == 1 && /^bestpractices-skill:/ {sub(/^bestpractices-skill:[[:space:]]*/, ""); gsub(/[[:space:]]/, ""); print; exit}' "$def" \
    | tr ',' '\n' | grep -v '^$')
  [ -n "$declared" ] || exit 0
  preloaded=$(awk '/^---[[:space:]]*$/{c++; if (c == 2) exit; next}
    c != 1 {next}
    /^skills:/ {v = $0; sub(/^skills:[[:space:]]*/, "", v); gsub(/[][[:space:]"\047]/, "", v)
      if (v != "") {print v; blk = 0} else blk = 1; next}
    blk && /^[[:space:]]*-/ {v = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", v); gsub(/[[:space:]"\047]/, "", v); print v; next}
    {blk = 0}' "$def" | tr ',' '\n' | sed 's/.*://' | grep -v '^$')

  . "$here/prime.sh" 2>/dev/null || exit 0
  command -v sr_repo_skills >/dev/null 2>&1 && command -v cc_state_root >/dev/null 2>&1 || exit 0
  root=$(cc_state_root "$cwd") || exit 0
  evidence=""
  add() { evidence="${evidence}$1"$'\t'"$2"$'\n'; } # $1 skill, $2 owning_plugin
  sr_repo_skills "$root"
  [ -n "$evidence" ] || exit 0

  msg="[skill-router] Stack skills for this repo from your bestpractices-skill list. Read these before working; a path the dispatcher already gave you needs no second Read:"
  kept=0
  while IFS= read -r sk; do
    printf '%s\n' "$preloaded" | grep -qxF -- "$sk" && continue
    owner=$(printf '%s' "$evidence" | awk -F'\t' -v s="$sk" '$1 == s {print $2; exit}')
    [ -n "$owner" ] || continue
    pr_plugin_installed "$owner" || continue
    oroot=$(pr_plugin_root "$owner")
    [ -n "$oroot" ] && [ -f "$oroot/skills/$sk/SKILL.md" ] || continue
    line=$'\n'"$oroot/skills/$sk/SKILL.md"
    case "$msg" in *"$line"*) continue ;; esac
    [ $(( ${#msg} + ${#line} )) -le "$CAP" ] || break
    msg="$msg$line"; kept=$((kept + 1))
  done <<EOF
$declared
EOF
  [ "$kept" -gt 0 ] || exit 0
  jq -cn --arg m "$msg" '{hookSpecificOutput:{hookEventName:"SubagentStart",additionalContext:$m}}'
} 2>/dev/null
exit 0
