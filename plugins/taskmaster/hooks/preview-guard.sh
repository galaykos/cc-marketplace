#!/bin/bash
# PreToolUse guard on the Artifact tool.
#
# The failure this exists for: a visual decision gets published as a remote
# artifact instead of served from the local preview server. The skills that
# route to that server (visual-decisions, ui-ux:theme) load by JUDGMENT, so a
# run where they never load never sees their rule — that is exactly how it goes
# wrong. This fires on the tool call instead.
#
# TIERED, because the strong signal is absent in precisely the population that
# needs guarding. An earlier version keyed solely on taskmaster-docs/mockups/
# existing; that directory is only ever created by the flows whose non-loading
# IS the root cause, so the guard was silent exactly when it mattered and noisy
# afterwards (one server start arms it for the life of the checkout).
#
#   STRONG — a per-purpose preview basename, or a path under a mockups docroot,
#            or a mockups docroot present in this project: ask EVERY time, with
#            the mockup rule.
#   WEAK   — any other .html artifact: ask ONCE PER SESSION to confirm the remote
#            publish is intended — a note proved ignorable, and a for-you page
#            must not slip out.
#   NONE   — not .html (a markdown report is not a mockup): silent.
#
# WHY WEAK IS BOUNDED AND STRONG IS NOT. Every Artifact .html is a remote
# publish, so the weak signal never clears: the tier asked on every HTML
# artifact for the life of the session, which is a standing veto in the name of
# a CONVENTION (render it on the local preview server) rather than a blast
# radius. One deliberate answer is what a convention is worth; the rest is noise
# the user learns to click through, which costs the STRONG asks their weight
# too. Bound pattern: comment-discipline/hooks/scan.sh and
# taskmaster/hooks/clarify-gate.sh, once-per-session for the same reason.
# STRONG stays unbounded — unreleased design work leaving the machine is blast
# radius, not convention.
#
# HONEST LIMITATION. After the session's first plain-.html publish, the next one
# goes unasked: a different for-you page, or a retry of the one just denied. The
# tier buys one deliberate answer per session and is not a standing veto; the
# population the guard exists for (STRONG) is unaffected. With no session_id in
# the hook input the bound cannot be recorded, so the tier falls back to asking
# every time — an ask can never wedge a session, so failing toward the question
# is safe here, the mirror of a deny gate, which must fail toward allowing.
#
# Fails open on any error: a broken guard degrades to a no-op, never to a
# blocked tool call.
#
# TWIN: plugins/ui-ux/hooks/preview-guard.sh is an identical copy save this line. ui-ux
# ships the theme flow but declares no taskmaster dependency, and a user may
# install ui-ux without taskmaster — without its own copy that path would have
# no mechanical guard at all. ${CLAUDE_PLUGIN_ROOT} is per-plugin so the file
# cannot be shared; change one, change both. With BOTH plugins installed the
# guard fires twice on the same call — an extra line in one prompt, which is
# the cheap side of the trade against leaving ui-ux unguarded. On the WEAK tier
# not even that: both copies hash the same session_id to the same marker, so the
# mkdir race leaves exactly one asker.
# OFF-SWITCH. Until 2026-09-15 this guard had none: the only way out was
# uninstalling the plugin. With BOTH twins installed it asks twice on a strong
# signal (see TWIN above), which makes "turn it off here" a real need.
# CC_PREVIEW_GUARD unset: the /config option cc_preview_guard decides.

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

[ "$(cc_option CC_PREVIEW_GUARD on)" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)

  path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  case "$path" in
    *.html | *.htm | *.HTML | *.HTM) ;;
    *) exit 0 ;;
  esac

  # .cwd is the session root; $PWD is only this script's cwd, so prefer it.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || cwd="$PWD"

  # Walk UP looking for the docroot. A git worktree or a session started in a
  # subdirectory would otherwise miss it — taskmaster-docs is untracked wherever the
  # project ignores it (as this marketplace does), so a worktree may not carry one
  # even while the shared server is live. The walk does not depend on that either way.
  docroot=""
  d="$cwd"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ -d "$d/taskmaster-docs/mockups" ]; then docroot="$d/taskmaster-docs/mockups"; break; fi
    d=$(dirname "$d")
  done

  # The artifact itself is the more reliable signal than project state.
  base=${path##*/}
  strong=""
  case "$base" in
    current.html | theme.html | walkthrough.html | diagram.html | api.html | modules.html | compose.html) strong=basename ;;
  esac
  case "$path" in
    */taskmaster-docs/mockups/*) strong=path ;;
  esac
  [ -n "$strong" ] || { [ -n "$docroot" ] && strong=docroot; }

  # WEAK only: one ask per session (see header). Keyed by session and NOT by
  # path — the convention is answered once, not once per page. Recording it is
  # what makes this the session's one weak ask, so the mkdir comes first; a
  # marker that cannot be recorded at all leaves the old unbounded behaviour.
  if [ -z "$strong" ]; then
    sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
    if [ -n "$sid" ]; then
      marker="${TMPDIR:-/tmp}/cc-preview-weak-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
      if mkdir "$marker" 2>/dev/null; then
        find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-preview-weak-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null
      elif [ -d "$marker" ]; then
        exit 0
      fi
    fi
  fi

  # Never interpolate an unvalidated env value into text shown at a permission
  # decision: jq keeps the JSON well-formed, but a crafted PREVIEW_PORT would
  # still read as prose in the guard's own authoritative voice.
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
