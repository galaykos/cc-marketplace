#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
# SessionEnd ledger + cleanup. The model-visible surfacing of low-confidence
# signals happens in route-prompt.sh's next-prompt flush — SessionEnd is an
# event after which no model turn exists, so the digest line printed here is
# transcript residue covering only entries the flush never surfaced. The real
# jobs are the surfaced.jsonl ledger append and removing the state file.
# Fail-open: any error exits silently.
# CC_SURFACED_LOG unset: the /config option cc_surfaced_log decides.
# State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/skill-router/ is only the fallback.
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
  # TWO VALUES, TWO JOBS — do not collapse them.
  #  ctx_src   addresses the state FILE and must match route.sh's CONTEXT KEY block
  #            exactly, field order included. route.sh reads `.transcript_path // .session_id` and
  #            hashes it; this hook used to read the raw `.session_id`, so it named a
  #            file the writer never creates — the ledger below never got a row and
  #            the `rm -f` never ran. The cksum is applied to the fallback branch too,
  #            so there is no payload shape where the two spellings coincide.
  #  session_id is a RECORDED FIELD in surfaced.jsonl, never a key. It stays the raw
  #            session id: a reader grepping the ledger wants the id the host reports,
  #            not a transcript path. Same distinction hindsight/hooks/skill-use.sh
  #            blesses with `context-key-ok`.
  # Change one side of ctx_src and you must change all three (route.sh, route-prompt.sh, here).
  # The DIRECTORY is the same three-hook contract: all three resolve it with cc_state_root,
  # so the file route.sh wrote from `app/Enums` is the one found here from the repo root.
  ctx_src=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null) || exit 0
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$ctx_src" ] || exit 0
  [ -n "$cwd" ] || exit 0
  # A cwd that no longer exists yields no root and this exits; a state file left under
  # the root by that session is gitignored and orphaned, not misread by the next one
  # (the key is per transcript).
  root=$(cc_state_root "$cwd") || exit 0

  ctx=$(printf '%s' "$ctx_src" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  state_file="$(cc_plugin_state "$root" skill-router)/fired-$ctx.json"
  [ -r "$state_file" ] || exit 0

  line=$(jq -r '
    [ (.pending_low // [])[] | select(.flushed != true) ]
    | group_by(.skill)
    | map(.[0].skill + " (" + (length | tostring) + " file" + (if length == 1 then "" else "s" end) + ")")
    | join(", ")
  ' "$state_file" 2>/dev/null) || { rm -f "$state_file" 2>/dev/null; exit 0; }

  [ -n "$line" ] && printf '[skill-router] Low-confidence signals seen this session — consider: %s.\n' "$line"

  # SURFACED LEDGER. Before the state file goes, append what this session's
  # router actually surfaced to a machine-local JSONL. This file is the only
  # record anywhere that a routing rule did anything: until it existed, every
  # argument this marketplace made about a plugin's worth was made from token
  # counts and trigger-phrase overlap, because there was no denominator. A rule
  # that surfaced nothing across N sessions is the cheapest possible retirement
  # argument, and that sentence was unwriteable while this line was `rm -f` alone.
  #
  # It records what the router OFFERED, not what the model loaded — hence
  # `surfaced`, never `usage`. Nothing reads it automatically; the one reader in
  # this repo is `scripts/turn-cost.sh --skills`, a maintainer path that ranks
  # skills and never proposes a deletion. (This comment used to name
  # /hindsight:harvest; grep of plugins/hindsight/ finds zero references to this
  # ledger — that command has never read it.)
  # Machine-local ($HOME, never the project tree), same slug rule as
  # hindsight/hooks/collect.sh, fail-silent, and skipped entirely when
  # CC_SURFACED_LOG=off. The slug is taken from the PROJECT ROOT, not the payload cwd:
  # a session that ended after `cd app/Models` filed its row under a slug of its own,
  # so one project could split into one ledger per directory the model ended in. The only
  # reader (turn-cost.sh --skills) globs every slug, so the rows it already has stay
  # counted; they just stop multiplying.
  case "$(cc_option CC_SURFACED_LOG on)" in
    off) : ;;
    *)
      slug=$(printf '%s' "$root" | tr -c '[:alnum:]' '-' 2>/dev/null) || slug=""
      if [ -n "$slug" ] && [ -n "${HOME:-}" ]; then
        dir="$HOME/.claude/skill-router/$slug"
        if mkdir -p "$dir" 2>/dev/null; then
          jq -c --arg sid "$session_id" '{
            v: 1,
            ts: (now | todate),
            session_id: $sid,
            fired: ((.fired // []) | unique),
            # SPLIT ON `flushed`, not one bucket. route-prompt.sh marks an entry
            # flushed only when it actually printed the digest to the model, so
            # collapsing both states into `pending_low` made "accumulated but
            # never shown" indistinguishable from "surfaced" — and that is the
            # exact number the turn-cost --skills queue ranks skills by. Measured before
            # this fix: four skills read 47 pending_low across 17 local sessions
            # with 0 fired, and nothing could say whether any reached the model.
            # `pending_low` is kept as the union so an older reader keeps working.
            pending_low: ((.pending_low // []) | map(.skill) | unique),
            pending_low_flushed: ((.pending_low // []) | map(select(.flushed == true) | .skill) | unique),
            pending_low_unflushed: ((.pending_low // []) | map(select(.flushed != true) | .skill) | unique)
          }' "$state_file" >> "$dir/surfaced.jsonl" 2>/dev/null
        fi
      fi ;;
  esac

  rm -f "$state_file" 2>/dev/null
} 2>/dev/null
exit 0
