#!/bin/bash
# subagent-skills.sh — SubagentStart for a plugin-scoped agent, fails open: hands it the absolute SKILL.md Read paths of the skills its
#   bestpractices-skill: frontmatter declares and prime.sh's rows find at the project root, owner installed, minus its skills: preloads.
#   A general-purpose or claude agent gets every skill prime.sh's rows find, when its dispatch named a repo file. PreToolUse on the Agent
#   call records what the dispatch named, since nothing on disk holds the prompt at SubagentStart; a surface skill (Vite, SQL, manifests,
#   Docker, CI) rides only a dispatch naming its file kind, unless the agent declares nothing else.
# Off: CC_SUBAGENT_SKILLS=off (this hook) or CC_REMIND=off (every advisory nudge); unset, the /config options cc_subagent_skills / cc_remind decide.
# Misses: a declared skill with no prime.sh row (motion-best-practices, security-review, performance-tuning, observability-design) and
#   prime.sh's own misses; a path past the CAP-character output. Advisory: it cannot make the agent Read. Another marketplace's plugin of
#   the same name resolves against this one's definition. Dispatches of one agent type within DISPATCH_TTL seconds share one record, so
#   a parallel fan-out is judged as a whole; a dispatch whose Agent call waits longer than that for approval reads as naming nothing;
#   a file named without a path-shaped word (a migration described, not named) does not count.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/hooks/subagent-skills.sh

# Shared block templates/blocks/plugin-state.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/plugin-state.md
# cc_plugin_state <root> <name> prints the plugin's own state dir for <root>, a cc_state_root result:
# CLAUDE_PLUGIN_DATA/<basename>-<cksum>/<name> if non-empty, else <root>/.claude/<name>. Status 0; creates nothing.
# The host keeps one data dir per plugin id, not per project (2.1.282); LC_ALL=C: a UTF-8 tr stops at an invalid byte.
# Misses: state another plugin, a skill or the user reads must not use it; an event lacking the variable uses the repo.
cc_plugin_state() {
  local key sum
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    key=$(printf '%s' "$(basename -- "$1")" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-')
    sum=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
    printf '%s/%s-%s/%s\n' "${CLAUDE_PLUGIN_DATA%/}" "$key" "$sum" "$2"
  else
    printf '%s/.claude/%s\n' "$1" "$2"
  fi
  return 0
}

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
  DISPATCH_TTL=120
  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  case "$(cc_option CC_SUBAGENT_SKILLS on)" in off) exit 0 ;; esac
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  # One read decides a PreToolUse dispatch of an unhandled type (Explore, Plan) before any git or prime.sh work.
  row=$(printf '%s' "$input" | jq -r '[.hook_event_name // "", .tool_input.subagent_type? // "general-purpose"] | @tsv' 2>/dev/null) || exit 0
  event="${row%%$'\t'*}"; atype="${row#*$'\t'}"
  if [ "$event" = PreToolUse ]; then
    case "$atype" in general-purpose|claude|*:*) ;; *) exit 0 ;; esac
  fi
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  # The parent's transcript in both events (measured, CLI 2.1.299), hashed as route.sh hashes its context key.
  ctx=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -z "$ctx" ] || ctx=$(printf '%s' "$ctx" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  here=$(dirname "$0")
  . "$here/prime.sh" 2>/dev/null || exit 0
  command -v sr_repo_skills >/dev/null 2>&1 && command -v cc_state_root >/dev/null 2>&1 || exit 0
  root=$(cc_state_root "$cwd") || exit 0
  dfile="$(cc_plugin_state "$root" skill-router)/dispatch-$ctx.tsv"

  if [ "$event" = PreToolUse ]; then
    [ -n "$ctx" ] || exit 0
    # Path-shaped words: a source file, a manifest, a Dockerfile or compose file.
    words=$(printf '%s' "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null \
      | grep -oE '[A-Za-z0-9_./@+-]*(Dockerfile[A-Za-z0-9._-]*|[A-Za-z0-9_-]\.(php|[cm]?[jt]sx?|vue|svelte|astro|sql|py|go|rb|rs|java|kt|cs|sh|css|scss|json|ya?ml))([^A-Za-z0-9_-]|$)' \
      | sed 's/[^A-Za-z0-9_-]$//' | head -n 200)
    flags=""
    while IFS= read -r w; do
      [ -n "$w" ] || continue
      case "$w" in /*) case "$w" in "$root"/*) w="${w#"$root"/}" ;; *) continue ;; esac ;; esac
      case "/$w" in */taskmaster-docs/*|*/.claude/*) continue ;; esac
      case "$w" in */*) ;; [A-Z]*.js) continue ;; esac # Node.js, Vue.js: a product, not a file
      flags="$flags src"
      case "${w##*/}" in
        vite.config.*) flags="$flags vite" ;;
        *.sql) flags="$flags sql" ;;
        composer.json|package.json) flags="$flags manifest" ;;
        Dockerfile*|*compose*.yml|*compose*.yaml) flags="$flags docker" ;;
      esac
      case "/$w" in */migrations/*) flags="$flags sql" ;; */.github/workflows/*) flags="$flags ci" ;; esac
    done <<EOF
$words
EOF
    [ -n "$flags" ] || exit 0
    mkdir -p "${dfile%/*}" 2>/dev/null || exit 0
    [ -e "${dfile%/*}/.gitignore" ] || printf '*\n' > "${dfile%/*}/.gitignore" 2>/dev/null
    printf '%s\t%s\t%s\n' "$(date +%s)" "$atype" "$(printf '%s\n' $flags | sort -u | tr '\n' ' ')" >> "$dfile" 2>/dev/null
    exit 0
  fi

  agent=$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null) || exit 0
  flags=""
  [ -n "$ctx" ] && [ -r "$dfile" ] \
    && flags=$(awk -F'\t' -v now="$(date +%s)" -v ttl="$DISPATCH_TTL" -v a="$agent" '$1 >= now - ttl && $2 == a {print $3}' "$dfile" 2>/dev/null | tr '\n' ' ')
  has_flag() { case " $flags " in *" $1 "*) return 0 ;; esac; return 1; }
  surface_of() { # $1 skill — the flag a dispatch must carry for it; empty for a skill with no single file kind
    case "$1" in
      vite-best-practices) echo vite ;;
      sql-best-practices|mariadb-best-practices) echo sql ;;
      package-hygiene) echo manifest ;;
      docker-best-practices) echo docker ;;
      devops-practices) echo ci ;;
    esac
  }
  case "$agent" in
    general-purpose|claude) has_flag src || exit 0 ;;
    *:*)
      plugin="${agent%%:*}"; name="${agent#*:}"
      # Both halves become path segments below; anything but a plain name is not ours.
      case "$plugin" in ''|*[!a-z0-9._-]*|.*) exit 0 ;; esac
      case "$name" in ''|*[!a-zA-Z0-9._-]*|.*) exit 0 ;; esac ;;
    *) exit 0 ;;
  esac

  PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"
  . "$here/plugins-dir.sh" 2>/dev/null || exit 0
  pr_resolve_plugins_dir
  # No plugins root, no path to name: silence here, unlike route.sh's fire-if-uncertain.
  [ -n "$PLUGINS_DIR" ] || exit 0

  preloaded=""; gate=1
  if [ -n "${plugin:-}" ]; then
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
    # An agent declaring nothing but surface skills (database-engineer: SQL) has that surface as its job: no gate.
    gate=0
    while IFS= read -r sk; do [ -n "$(surface_of "$sk")" ] || gate=1; done <<EOF
$declared
EOF
    msg="[skill-router] Stack skills for this repo from your bestpractices-skill list. Read these before working; a path the dispatcher already gave you needs no second Read:"
  fi

  evidence=""
  add() { evidence="${evidence}$1"$'\t'"$2"$'\n'; } # $1 skill, $2 owning_plugin
  sr_repo_skills "$root"
  [ -n "$evidence" ] || exit 0
  if [ -z "${plugin:-}" ]; then
    declared=$(printf '%s' "$evidence" | cut -f1 | awk '!seen[$0]++')
    msg="[skill-router] Stack skills this repo's evidence primes, for the files your task names. Read these before working; a path the dispatcher already gave you needs no second Read:"
  fi

  kept=0
  while IFS= read -r sk; do
    [ -n "$sk" ] || continue
    printf '%s\n' "$preloaded" | grep -qxF -- "$sk" && continue
    if [ "$gate" = 1 ]; then s=$(surface_of "$sk"); [ -z "$s" ] || has_flag "$s" || continue; fi
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
