#!/bin/bash
# route-prompt.sh — UserPromptSubmit, fails open: on any prompt, prints once each the low-confidence signals route.sh queued for this context;
#   then, on the session's first work-shaped prompt, the rules for judging the host's own command listing. It picks no command.
# Off: CC_REMIND=off (every advisory nudge in this marketplace) or CC_ROUTE=off (this hook); unset, the /config options cc_remind / cc_route decide.
# Misses: a symptom phrased without a state verb (`payment failures spiking`, `memory leak in the worker`); fires anyway on a chat sentence
#   carrying one (`the build is slow to watch`). Repeats a signal on the next prompt when its state file cannot be rewritten.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/hooks/route-prompt.sh
MARKER_TTL_MIN=1440

# Shared block templates/blocks/state-root.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/state-root.md
# cc_state_root <cwd> prints the root that holds hook state: the git toplevel above <cwd>, else
# CLAUDE_PROJECT_DIR when <cwd> is under it, else <cwd>. A <cwd> that no longer exists: no output, status 1.
# --show-cdup, not --show-toplevel: git resolves a symlinked /tmp there, breaking the caller's path-prefix compares.
cc_state_root() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  local up pd="${CLAUDE_PROJECT_DIR:-}"; pd="${pd%/}"
  if up=$(git -C "$1" rev-parse --show-cdup 2>/dev/null); then
    [ -n "$up" ] || { printf '%s\n' "$1"; return 0; }
    (CDPATH= cd -- "$1/$up" 2>/dev/null && pwd) && return 0
  fi
  if [ -n "$pd" ] && [ -d "$pd" ]; then
    case "$1/" in "$pd"/*) printf '%s\n' "$pd"; return 0 ;; esac
  fi
  printf '%s\n' "$1"
}

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
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "") exit 0 ;; esac

  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  case "$(cc_option CC_ROUTE on)" in off) exit 0 ;; esac

  # Key and root as route.sh spells them (`.transcript_path // .session_id`, hashed; cc_state_root): any other spelling misses its file.
  sid_f=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  cwd_f=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  ctx_f=$(printf '%s' "$sid_f" | cksum 2>/dev/null | cut -d' ' -f1)
  root_f=""
  [ -n "$cwd_f" ] && root_f=$(cc_state_root "$cwd_f")
  state_f=""
  [ -n "$root_f" ] && [ -n "$ctx_f" ] && state_f="$(cc_plugin_state "$root_f" skill-router)/fired-$ctx_f.json"
  if [ -n "$sid_f" ] && [ -n "$state_f" ] && [ -r "$state_f" ]; then
    digest=$(jq -r '
      [ (.pending_low // [])[] | select(.flushed != true) ]
      | group_by(.skill)
      | map(.[0].skill + " (" + ([.[].file | split("/") | last] | unique | join(", ")) + ")")
      | join("; ")
    ' "$state_f" 2>/dev/null)
    if [ -n "$digest" ]; then
      printf '[skill-router] Signals from recent edits — judge each in one line before continuing, load the skill only if it applies: %s.\n' "$digest"
      upd=$(jq '(.pending_low // []) |= map(.flushed = true)' "$state_f" 2>/dev/null) \
        && [ -n "$upd" ] && printf '%s\n' "$upd" > "$state_f" 2>/dev/null
    fi
  fi

  # Slash commands manage their own flow — but only AFTER the flush above ran.
  case "$prompt" in "/"*) exit 0 ;; esac

  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-400)
  printf '%s' "$head" | grep -qiE 'hook (success|feedback|output)|task-notification|SYSTEM NOTIFICATION|UserPromptSubmit' && exit 0
  printf '%s' "$head" | grep -qiE '(delete|remove|uninstall|disable|install|list|which|audit|fix|update|change|write|rewrite|edit)[a-z -]{0,40}(plugin|hook|reminder|router|route|trigger|catalog)' && exit 0
  printf '%s' "$head" | grep -qF '[skill-router]' && exit 0

  # One grep, three tiers: validate.sh allows four prompt greps here, so a new tier is an alternation in it, never a fifth line.
  # A weak symptom (down, slow, broken…) counts only after a state verb: bare, it matches `scroll down` and `the meeting ran slow`.
  printf '%s' "$head" | grep -qiE '\b(build|create|make|add|implement|develop|write|rewrite|refactor|migrate|port|fix|debug|review|audit|design|redesign|restyle|theme|style|test|deploy|ship|optimi[sz]e|speed up|scaffold|set ?up|plan|spec|integrate|automate|error|errors|crash|crashing|500s?|regress(ed|ion)?|not working|why is|investigate)\b|\b(is|are|was|were|been|went|going|get(s|ting)?|got|keeps?|kept|still|now|seems?|looks?|am)\b[[:space:]]+([a-z]+[[:space:]]+)?\b(down|slow(er)?|broken|failing|fails|leak(s|ing)?|stuck)\b' || exit 0

  # Raw session_id, not route.sh's context key: UserPromptSubmit never fires in a subagent, so no second context shares this marker.
  sid=$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)
  seen="${TMPDIR:-/tmp}/cc-route-catalog-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
  # mkdir failed: anything at the path (fired, or a squatting file) suppresses; a vacant path means TMPDIR is unwritable, so deliver.
  if ! mkdir "$seen" 2>/dev/null; then
    [ -e "$seen" ] && exit 0
  fi
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-route-catalog-*' -type d -mmin +"$MARKER_TTL_MIN" -exec rmdir {} + 2>/dev/null

  cat <<CATALOG
[skill-router] Tool-fit check (once this session). Judge against the slash commands already listed in this session — do not rebuild or ask for that list.

Apply this to work requests for the rest of the session:

1. Judge which listed command best fits the ASK — its substance, not its wording. Most
   requests fit none of them. Silence is the default and the common case.
2. If the user NAMED a tool (a command, a plugin, a pipeline) and a listed command
   clearly fits the ask better, do NOT silently switch and do NOT silently comply.
   Ask via AskUserQuestion, exactly two options:
     "Proceed with <better-command> (Recommended)" / "Proceed with <what-they-named> as asked"
   Give one line of why the other fits — the deliverable's shape, not a preference.
3. If no tool was named and one clearly fits, name it in one line and carry on. No picker.
   Exception: when a scope-first reminder fired on the same prompt, satisfy it before
   carrying on — scoping the work outranks tool-fit. Which reminder that is varies by
   phase and rank, not by plugin: it may be the clarifying-round directive, a
   build-vs-buy check, a docs check, or a stuck-loop nudge. Obey whichever one spoke.
4. Close call, or the named tool IS the best fit: say nothing at all. A tool being
   listed is not a reason to route to it; over-suggesting is the failure mode here.
5. At most one picker per named tool per session. Declining is durable — a user who
   kept their choice is not asked about that tool again.
6. Under a hands-off boost (an ultra-goal run, or a Goal: marker in the card index),
   auto-take the Recommended route instead of asking, and record it in the goal ledger
   with the rationale and both options, per the taskmaster ultra skill's Goal rules.
CATALOG
} 2>/dev/null
exit 0
