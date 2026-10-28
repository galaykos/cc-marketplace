#!/bin/bash
# preview-guard.sh — PreToolUse on Artifact: asks before an .html/.htm artifact is published remotely, every time for a mockup (a preview basename, a path under taskmaster-docs/mockups, or such a docroot at or above cwd), once per session for any other. Off: CC_PREVIEW_GUARD=off (unset: /config option cc_preview_guard). Fails open: no jq, no ask; always exits 0.
# Misses: a session's later plain-.html publishes after its first ask, a denied one's retry included. Asks anyway: every plain .html with no session_id; a mockup twice with ui-ux and taskmaster both installed (a plain page once: one shared marker).
# Why, limits, history: rationale/derivations/plugin-ui-ux.md § plugins/ui-ux/hooks/preview-guard.sh

# TWIN: plugins/ui-ux/hooks/preview-guard.sh is an identical copy save this line.

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
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

MARKER_TTL_MIN=1440

[ "$(cc_option CC_PREVIEW_GUARD on)" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)

  path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  case "$path" in
    *.html | *.htm | *.HTML | *.HTM) ;;
    *) exit 0 ;;
  esac

  # Prefer the payload .cwd (the session's working directory, which follows cd); $PWD, this script's own, is only the fallback.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || cwd="$PWD"

  docroot=""
  d="$cwd"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ -d "$d/taskmaster-docs/mockups" ]; then docroot="$d/taskmaster-docs/mockups"; break; fi
    d=$(dirname "$d")
  done

  base=${path##*/}
  strong=""
  case "$base" in
    current.html | theme.html | walkthrough.html | diagram.html | api.html | modules.html | compose.html) strong=basename ;;
  esac
  case "$path" in
    */taskmaster-docs/mockups/*) strong=path ;;
  esac
  [ -n "$strong" ] || { [ -n "$docroot" ] && strong=docroot; }

  if [ -z "$strong" ]; then
    sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
    if [ -n "$sid" ]; then
      marker="${TMPDIR:-/tmp}/cc-preview-weak-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
      if mkdir "$marker" 2>/dev/null; then
        find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-preview-weak-*' -type d -mmin +"$MARKER_TTL_MIN" -exec rmdir {} + 2>/dev/null
      elif [ -d "$marker" ]; then
        exit 0
      fi
    fi
  fi

  # Digits only: jq keeps the JSON valid, but a crafted PREVIEW_PORT would still read as prose in the guard's own voice.
  port="${PREVIEW_PORT:-8123}"
  case "$port" in '' | *[!0-9]*) port=8123 ;; esac

  if [ -n "$strong" ]; then
    jq -cn --arg p "$port" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason:
          ("This looks like a mockup or theme preview. Those belong on the local "
           + "preview server at http://localhost:" + $p + "/ — it carries the viewport "
           + "presets, the version picker, and push-reload that a published page does "
           + "not, and it keeps unreleased design work off a remote host. Publish only "
           + "if the point is sharing with someone who cannot reach this machine. "
           + "CC_PREVIEW_GUARD=off disables this guard for the session.")
      }
    }'
  else
    jq -cn --arg p "$port" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason:
          ("Keep this on localhost, not a remote host. Render it on the preview server "
           + "at http://localhost:" + $p + "/ (or open a local file) — that is the "
           + "convention here: the server carries the viewport presets, the version "
           + "picker, and push-reload a published page loses, and keeps the work off an "
           + "external host. Publish remotely ONLY if someone who cannot reach this "
           + "machine must open it. " + "CC_PREVIEW_GUARD=off disables this guard for the session.")
      }
    }'
  fi
} 2>/dev/null
exit 0
